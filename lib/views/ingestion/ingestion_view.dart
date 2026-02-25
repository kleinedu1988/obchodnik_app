import 'dart:async';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

// --- LOGIKA A SLUŽBY ---
import '../../../logic/ingestion_service.dart';
import '../../../logic/workflow_controller.dart';
import '../../../logic/notifications.dart';
import '../../../logic/excel_header_detector.dart';
import '../../../logic/customer_matcher.dart';
import '../../../logic/db_service.dart';

class IngestionView extends StatefulWidget {
  const IngestionView({super.key});

  @override
  State<IngestionView> createState() => _IngestionViewState();
}

class _IngestionViewState extends State<IngestionView> with SingleTickerProviderStateMixin {
  // --- KONFIGURACE ---
  late AnimationController _animationController;
  final IngestionService _ingestionService = IngestionService();
  final WorkflowController _workflow = WorkflowController();
  
  // Scroll controller pro horizontální posun tabulky
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Základní šířka jednoho sloupce
  static const double _colWidth = 140.0;

  bool _isDragging = false;

  // --- STAV CUSTOMER WIZARDU ---
  List<Map<String, dynamic>> _customerList = [];
  Map<String, dynamic>? _selectedCustomer;
  bool _isCustomerLoading = false;
  Timer? _customerSearchDebounce;
  final TextEditingController _customerSearchCtrl = TextEditingController();

  // --- DESIGN SYSTÉMU BRIDGE ---
  static const Color _bgDeep = Color(0xFF0F1115);
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _successColor = Color(0xFF22C55E); // Zelená pro potvrzení
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white24;

  // --- LOGICKÝ ZÁMEK ---
  bool get _isLocked => _workflow.isEditorUnlocked || _workflow.isProcessing;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _workflow.addListener(_onWorkflowChanged);
  }

  @override
  void dispose() {
    _workflow.removeListener(_onWorkflowChanged);
    _animationController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _customerSearchCtrl.dispose();
    _customerSearchDebounce?.cancel();
    super.dispose();
  }

  void _onWorkflowChanged() {
    if (!mounted) return;
    if (_workflow.isMatchingCustomer && _customerList.isEmpty && !_isCustomerLoading) {
      // Wizard se právě objevil — předvyber AI návrh a načti seznam
      setState(() {
        _selectedCustomer = _workflow.pendingCustomerResult?.customer;
        _customerSearchCtrl.clear();
      });
      _loadCustomers('');
    } else if (!_workflow.isMatchingCustomer && _customerList.isNotEmpty) {
      // Wizard zmizel — resetuj stav pro příští použití
      setState(() {
        _customerList = [];
        _selectedCustomer = null;
      });
    }
  }

  Future<void> _loadCustomers(String query) async {
    if (!mounted) return;
    setState(() => _isCustomerLoading = true);
    try {
      final raw = await DbService().getZakaznici(query: query, limit: 30);
      if (mounted) {
        setState(() {
          _customerList = raw.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } finally {
      if (mounted) setState(() => _isCustomerLoading = false);
    }
  }

  // ===========================================================================
  //  LOGIKA: Zpracování souborů
  // ===========================================================================

  Future<void> _handleFileAction(List<XFile> files) async {
    if (files.isEmpty || _isLocked) return;

    _workflow.setProcessing(true);

    try {
      final result = await _ingestionService.processFiles(files);
      
      if (!mounted) return;

      if (result.ignoredCount > 0) {
        Notifications.showWarning(context, "DOKONČENO S IGNOROVÁNÍM: ${result.summaryLine}");
      } else {
        Notifications.showSuccess(context, "SOUBORY ROZTŘÍDĚNY: ${result.summaryLine}");
      }

      await _workflow.handleIngestion(result);
      
    } catch (e) {
      Notifications.showError(context, "CHYBA INGESCE: $e");
    } finally {
      if (mounted) _workflow.setProcessing(false);
    }
  }

  // ===========================================================================
  //  UI STAVBA
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _workflow,
      builder: (context, _) {
        
        Widget activeChild;
        if (_workflow.isVerifyingHeader && _workflow.headerResult != null) {
          activeChild = _buildHeaderWizard();
        } else if (_workflow.isMatchingCustomer) {
          activeChild = _buildCustomerWizard();
        } else if (_workflow.lastIngestion != null) {
          activeChild = _buildDecisionOverlay();
        } else {
          activeChild = _buildDropZone();
        }

        return AbsorbPointer(
          absorbing: _isLocked,
          child: Scaffold(
            backgroundColor: _bgDeep,
            body: Stack(
              children: [
                Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _isLocked ? 0.35 : 1.0, 
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: activeChild,
                    ),
                  ),
                ),
                if (_workflow.isProcessing)
                  Positioned.fill(child: _buildLoadingOverlay()),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  //  1. VÝCHOZÍ STAV: DropZone
  // ===========================================================================
  
  Widget _buildDropZone() {
    return DropTarget(
      key: const ValueKey("drop_zone"),
      onDragEntered: (_) {
        if (!_isLocked) setState(() => _isDragging = true);
      },
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) => _handleFileAction(details.files),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnimatedDropCard(),
          const SizedBox(height: 48),
          _buildBrowseButton(),
          const SizedBox(height: 32),
          _buildFormatLegend(),
        ],
      ),
    );
  }

  // ===========================================================================
  //  2. HEADER WIZARD (Zjednodušený pohled)
  // ===========================================================================

  Widget _buildHeaderWizard() {
    final HeaderDetectionResult res = _workflow.headerResult!;
    final topCandidates = res.getTopCandidates();
    
    return Container(
      key: const ValueKey("header_wizard"),
      width: 1000, 
      height: 700,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accentColor.withValues(alpha: 0.5), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 60)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hlavička Wizardu
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _accentColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.table_chart_outlined, color: _accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("OVĚŘENÍ STRUKTURY", 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text("Klikněte na řádek, který obsahuje názvy sloupců (např. Part Number, Quantity).", 
                    style: TextStyle(color: _textDim, fontSize: 12)),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // --- RYCHLÝ VÝBĚR (TOP KANDIDÁTI) ---
          if (topCandidates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text("DOPORUČENÉ ŘÁDKY:", style: TextStyle(color: _textDim, fontSize: 10, fontWeight: FontWeight.bold)),
                  ...topCandidates.map((idx) {
                    final conf = res.getConfidence(idx);
                    final pct = (conf * 100).round();
                    final isSelected = res.headerRowIndex == idx;
                    return ActionChip(
                      label: Text("Řádek ${idx + 1} ($pct%)"),
                      backgroundColor: isSelected ? _accentColor : _bgDeep,
                      side: BorderSide(color: _getColorForConfidence(conf).withValues(alpha: 0.5)),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      onPressed: () {
                        _workflow.manualHeaderAdjust(idx);
                        _scrollToRow(idx);
                      },
                    );
                  }),
                ],
              ),
            ),

          // TABULKA S HORIZONTÁLNÍM SCROLLEM
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _bgDeep,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    // Vypočítáme šířku obsahu, aby grid fungoval správně
                    width: _calculateTableWidth(res),
                    child: ListView.separated(
                      controller: _verticalScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: res.previewRows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, rowIndex) {
                        final bool isSelected = res.headerRowIndex == rowIndex;
                        final bool isIgnored = rowIndex < res.headerRowIndex; // Ghosting pro řádky nad hlavičkou
                        final List<String> rowData = res.previewRows[rowIndex];
                        
                        // Výpočet barvy podle shody
                        final double confidence = res.getConfidence(rowIndex);
                        final Color rowColor = _getColorForConfidence(confidence);

                        return Opacity(
                          opacity: isIgnored ? 0.3 : 1.0,
                          child: InkWell(
                            onTap: () => _workflow.manualHeaderAdjust(rowIndex),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                // Pokud je vybráno -> Modrá
                                // Pokud není vybráno, ale má shodu -> Jemný nádech barvy shody
                                color: isSelected 
                                    ? _accentColor.withValues(alpha: 0.15) 
                                    : (confidence > 0.2 ? rowColor.withValues(alpha: 0.05) : Colors.transparent),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? _accentColor : rowColor.withValues(alpha: confidence > 0.4 ? 0.4 : 0.0),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Index řádku (fixní šířka)
                                  SizedBox(
                                    width: 40,
                                    child: Center(
                                      child: Text("#${rowIndex + 1}", 
                                        style: TextStyle(
                                          color: isSelected ? _accentColor : (confidence > 0.4 ? rowColor : _textDim), 
                                          fontSize: 10, 
                                          fontWeight: FontWeight.bold
                                        )),
                                    ),
                                  ),
                                  // Dynamicky generované buňky
                                  ..._buildRowCells(rowIndex, rowData, res.knownSpans, isSelected),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Akční tlačítka
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
               TextButton(
                 onPressed: _workflow.reset,
                 child: const Text("ZRUŠIT", style: TextStyle(color: _textDim)),
               ),
               const SizedBox(width: 16),
               SizedBox(
                 width: 200,
                 child: _choiceBtn(
                   "POTVRDIT STRUKTURU", 
                   () => _workflow.confirmHeader(), 
                   isPrimary: true,
                   customColor: _successColor
                 ),
               ),
            ],
          )
        ],
      ),
    );
  }

  // --- POMOCNÉ METODY PRO WIZARD ---

  Color _getColorForConfidence(double conf) {
    if (conf >= 0.8) return _successColor;
    if (conf >= 0.4) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  void _scrollToRow(int index) {
    if (_verticalScrollController.hasClients) {
      _verticalScrollController.animateTo(
        index * 45.0, // Odhadovaná výška řádku (padding + content)
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Vypočítá celkovou šířku tabulky podle nejdelšího řádku
  double _calculateTableWidth(HeaderDetectionResult res) {
    int maxCols = 0;
    for (var row in res.previewRows) {
      if (row.length > maxCols) maxCols = row.length;
    }
    // 40 je šířka pro index řádku + padding
    return (maxCols * _colWidth) + 60; 
  }

  /// Generuje widgety pro buňky.
  /// Sloučené buňky zobrazuje jako JEDNU buňku (normální šířky), 
  /// ale stále přeskakuje ty skryté pod ní, aby se neopakovaly.
  List<Widget> _buildRowCells(int rowIndex, List<String> rowData, List<ExcelSpan> spans, bool isHeader) {
    List<Widget> cells = [];

    for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
      // 1. Zjistíme, jestli je tato buňka součástí nějakého spanu
      ExcelSpan? activeSpan;
      for (var span in spans) {
        if (span.contains(rowIndex, colIndex)) {
          activeSpan = span;
          break;
        }
      }

      if (activeSpan != null) {
        // Jsme uvnitř spojené oblasti.
        // A. Je to "Master" buňka? (Začátek oblasti)
        if (activeSpan.rowStart == rowIndex && activeSpan.colStart == colIndex) {
          // Vykreslíme jako normální buňku (žádné extra roztahování)
          cells.add(Container(
            width: _colWidth, 
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildCellContent(rowData[colIndex], isHeader, isMerged: true),
          ));
        } 
        // B. Není to master? -> Přeskočíme (nevykreslujeme nic)
      } else {
        // Není ve spanu -> Normální buňka
        cells.add(Container(
          width: _colWidth,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildCellContent(rowData[colIndex], isHeader),
        ));
      }
    }
    return cells;
  }

  /// Vykreslení obsahu jedné buňky
  Widget _buildCellContent(String text, bool isHeader, {bool isMerged = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isHeader ? _bgCard : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        // Ikonka merge nám stačí jako indikátor, rámeček není nutný
        border: isMerged ? Border.all(color: _accentColor.withValues(alpha: 0.3)) : null,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.isEmpty ? "-" : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isHeader ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isMerged) 
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.merge_type, size: 12, color: _accentColor),
            )
        ],
      ),
    );
  }

  // ===========================================================================
  //  3. CUSTOMER WIZARD
  // ===========================================================================

  Widget _buildCustomerWizard() {
    final result = _workflow.pendingCustomerResult;
    final hasSuggestion = result != null && result.level != CustomerMatchConfidence.none;

    return Container(
      key: const ValueKey("customer_wizard"),
      width: 640,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 60)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hlavička
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _accentColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.business_outlined, color: _accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("PŘIŘAZENÍ ZÁKAZNÍKA",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text("Ověřte, ke které firmě objednávka patří.",
                      style: TextStyle(color: _textDim, fontSize: 12)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // AI návrh (pokud existuje)
          if (hasSuggestion) _buildSuggestionPanel(result),
          if (hasSuggestion) const SizedBox(height: 16),

          // Vyhledávání
          _buildCustomerSearchField(),
          const SizedBox(height: 8),

          // Seznam zákazníků
          SizedBox(height: 280, child: _buildCustomerList()),

          const SizedBox(height: 24),

          // Akční tlačítka
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isLocked ? null : () => _workflow.confirmCustomer(null),
                child: const Text("PŘESKOČIT", style: TextStyle(color: _textDim)),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 230,
                child: ElevatedButton(
                  onPressed: _isLocked ? null : () => _workflow.confirmCustomer(_selectedCustomer),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _successColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _selectedCustomer != null ? "POTVRDIT ZÁKAZNÍKA" : "POKRAČOVAT BEZ FIRMY",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionPanel(CustomerMatchResult? result) {
    if (result == null) return const SizedBox.shrink();
    final isHigh = result.level == CustomerMatchConfidence.high;
    final color = isHigh ? _successColor : const Color(0xFFF59E0B);
    final customer = result.customer!;
    final pct = (result.confidence * 100).round();
    final isSelected = _selectedCustomer?['id'] == customer['id'];

    return InkWell(
      onTap: () => setState(() => _selectedCustomer = customer),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(isHigh ? Icons.check_circle_outline : Icons.help_outline, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer['nazev'] ?? '',
                      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    "ID: ${customer['externi_id'] ?? '-'}  •  IČ: ${customer['ic'] ?? '-'}  •  nalezeno: ${result.matchedOn}",
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("$pct %",
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        controller: _customerSearchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: _accentColor,
        decoration: const InputDecoration(
          hintText: "Hledat zákazníka (název, IČ, ID)...",
          hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
          prefixIcon: Icon(Icons.search, color: Colors.white24, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (val) {
          _customerSearchDebounce?.cancel();
          _customerSearchDebounce = Timer(
            const Duration(milliseconds: 300),
            () => _loadCustomers(val),
          );
        },
      ),
    );
  }

  Widget _buildCustomerList() {
    if (_isCustomerLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor));
    }
    if (_customerList.isEmpty) {
      return const Center(
        child: Text("Žádní zákazníci nenalezeni", style: TextStyle(color: Colors.white24, fontSize: 12)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _customerList.length,
        separatorBuilder: (context, i) => const Divider(color: _borderColor, height: 1),
        itemBuilder: (context, i) {
          final c = _customerList[i];
          final isSelected = _selectedCustomer?['id'] == c['id'];
          return InkWell(
            onTap: () => setState(() => _selectedCustomer = c),
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _accentColor.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  // Radio indikátor
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _accentColor : Colors.white24,
                        width: 2,
                      ),
                      color: isSelected ? _accentColor : Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['nazev'] ?? '',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                        if ((c['ic'] ?? '').toString().isNotEmpty || (c['externi_id'] ?? '').toString().isNotEmpty)
                          Text(
                            "ID: ${c['externi_id'] ?? '-'}  •  IČ: ${c['ic'] ?? '-'}",
                            style: const TextStyle(color: Colors.white24, fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  //  4. ROZHODOVACÍ STAV
  // ===========================================================================
  
  Widget _buildDecisionOverlay() {
    final result = _workflow.lastIngestion!;
    
    return Container(
      key: const ValueKey("decision_card"),
      width: 560,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, color: _isLocked ? _textDim : _accentColor, size: 56),
          const SizedBox(height: 24),
          const Text("SOUBORY PŘIPRAVENY", 
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(result.summaryLine, style: const TextStyle(color: _textDim, fontSize: 11, fontWeight: FontWeight.bold)),
          
          const SizedBox(height: 48),
          const Text("Zvolte typ zpracování:", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(child: _choiceBtn("ZRUŠIT", _workflow.reset, isCancel: true)),
              const SizedBox(width: 12),
              Expanded(child: _choiceBtn("NABÍDKA", () => _workflow.unlockEditor(DocType.offer))),
              const SizedBox(width: 12),
              Expanded(child: _choiceBtn("VÝROBA", () => _workflow.unlockEditor(DocType.order), isPrimary: true)),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  //  KOMPONENTY
  // ===========================================================================

  Widget _buildAnimatedDropCard() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double glow = _isDragging ? 1.0 : _animationController.value;
        return Container(
          width: 500, height: 320,
          decoration: BoxDecoration(
            color: _isLocked ? Colors.transparent : _bgCard,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: _isDragging ? Colors.greenAccent : _accentColor.withValues(alpha: 0.1 + (0.4 * glow)),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isDragging ? Icons.file_download_outlined : Icons.cloud_upload_outlined,
                size: 80,
                color: _isDragging ? Colors.greenAccent : (_isLocked ? _textDim : _accentColor),
              ),
              const SizedBox(height: 32),
              const Text("PŘETÁHNĚTE DATA", 
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrowseButton() {
    return OutlinedButton.icon(
      onPressed: _isLocked ? null : () async {
        final result = await _ingestionService.pickFromDisk();
        if (result != null) _workflow.handleIngestion(result);
      },
      icon: const Icon(Icons.folder_open_rounded, size: 16),
      label: const Text("VYBRAT SOUBORY Z DISKU", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _accentColor,
        side: BorderSide(color: _accentColor.withValues(alpha: _isLocked ? 0.1 : 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _choiceBtn(String label, VoidCallback onTap, {bool isCancel = false, bool isPrimary = false, Color? customColor}) {
    final bgColor = customColor ?? (isPrimary ? _accentColor : (isCancel ? Colors.transparent : Colors.white10));
    
    return ElevatedButton(
      onPressed: _isLocked ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.02),
        disabledForegroundColor: Colors.white10,
        padding: const EdgeInsets.symmetric(vertical: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isCancel ? const BorderSide(color: Colors.white10) : BorderSide.none,
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 3, color: _accentColor),
            SizedBox(height: 32),
            Text("BRINGING DATA TO LIFE...", 
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 4)),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem("TABULKY", Colors.greenAccent),
        const SizedBox(width: 32),
        _legendItem("VÝKRESY", Colors.redAccent),
        const SizedBox(width: 32),
        _legendItem("CAD / 3D", Colors.blueAccent),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: _textDim, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}