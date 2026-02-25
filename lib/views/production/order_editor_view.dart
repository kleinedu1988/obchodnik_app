import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../logic/notifications.dart';
import 'package:path/path.dart' as p;

class OrderEditorView extends StatefulWidget {
  const OrderEditorView({super.key});

  @override
  State<OrderEditorView> createState() => _OrderEditorViewState();
}

class _OrderEditorViewState extends State<OrderEditorView> with SingleTickerProviderStateMixin {
  static const Color _bgBase = Color(0xFF0F1115);
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;
  static const Color _orderColor = Color(0xFF10B981);
  static const Color _accentColor = Color(0xFF4077D1);

  final TextEditingController _orderIdCtrl = TextEditingController(text: "OBJ-2026-0452");
  final TextEditingController _refOfferCtrl = TextEditingController(text: "NAB-2026-0001");

  final ScrollController _collapsedScrollCtrl = ScrollController();
  final ScrollController _expandedScrollCtrl = ScrollController();

  bool _isDragOver = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Stav pro řazení sloupců
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  final List<String> _attachedFiles = [
    "sestava_final.pdf",
    "dil_01.step",
    "dil_02.step",
    "balici_predpis.txt",
    "certifikat_materialu.pdf",
    "vykres_01.dwg",
  ];

  final List<_OrderItem> _items = [
    _OrderItem(name: "Sestava rámu X-Y", material: "Ocel 11 373", qty: "2", deadline: "20.02.2026", pdfFile: "ram_sestava.pdf", stepFile: "ram_sestava.stp"),
    _OrderItem(name: "Čep kalený 20mm", material: "16MnCr5", qty: "50", deadline: "18.02.2026", pdfFile: "cep_v2.pdf", dxfFile: "cep_v2.dxf"),
    _OrderItem(name: "Kryt plechový", material: "DX51D+Z", qty: "10", deadline: "22.02.2026", dxfFile: "kryt_paly.dxf", imgFile: "skica_zakaznik.jpg"),
    _OrderItem(name: "Distanční kroužek", material: "S235JR", qty: "25", deadline: "19.02.2026", pdfFile: "krouzek.pdf"),
    _OrderItem(name: "Nosník příčný L-400", material: "S355J2", qty: "4", deadline: "21.02.2026"),
    _OrderItem(name: "Patka montážní", material: "DX51D+Z", qty: "8", deadline: "23.02.2026", stepFile: "patka_model.step"),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orderIdCtrl.dispose();
    _refOfferCtrl.dispose();
    _collapsedScrollCtrl.dispose();
    _expandedScrollCtrl.dispose();
    super.dispose();
  }

  // --- LOGIKA ŘAZENÍ (SORTING) ---
  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }

      _items.sort((a, b) {
        int cmp = 0;
        switch (columnIndex) {
          case 0: cmp = a.name.compareTo(b.name); break;
          case 1: cmp = a.material.compareTo(b.material); break;
          case 2: 
            int qA = int.tryParse(a.qty) ?? 0;
            int qB = int.tryParse(b.qty) ?? 0;
            cmp = qA.compareTo(qB); 
            break;
          case 3: 
            cmp = _compareDates(a.deadline, b.deadline);
            break;
        }
        return _sortAscending ? cmp : -cmp;
      });
    });
  }

  int _compareDates(String d1, String d2) {
    try {
      final p1 = d1.split('.');
      final p2 = d2.split('.');
      final dt1 = DateTime(int.parse(p1[2]), int.parse(p1[1]), int.parse(p1[0]));
      final dt2 = DateTime(int.parse(p2[2]), int.parse(p2[1]), int.parse(p2[0]));
      return dt1.compareTo(dt2);
    } catch (_) {
      return d1.compareTo(d2);
    }
  }

  // --- AKCE NAD ŘÁDKEM ---
  void _duplicateItem(_OrderItem item) {
    setState(() {
      _items.add(_OrderItem(
        name: "${item.name} (Kopie)", material: item.material, qty: item.qty, deadline: item.deadline,
        pdfFile: item.pdfFile, dxfFile: item.dxfFile, stepFile: item.stepFile, imgFile: item.imgFile,
      ));
    });
    Notifications.showSuccess(context, "Položka duplikována");
  }

  void _deleteItem(_OrderItem item) {
    setState(() { _items.remove(item); });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgBase,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _buildFormCard()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildSummaryCard()),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildControls(),
          const SizedBox(height: 16),
          _buildTableHeader(),
          
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    itemCount: _items.length,
                    padding: const EdgeInsets.only(bottom: 16),
                    separatorBuilder: (context, index) => const Divider(color: _borderColor, height: 1),
                    itemBuilder: (context, index) {
                      return _OrderTableRow(
                        item: _items[index],
                        onDuplicate: () => _duplicateItem(_items[index]),
                        onDelete: () => _deleteItem(_items[index]),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          _buildDocumentationDropzone(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_bgCard, _bgCard.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_customize_rounded, size: 14, color: _textDim),
              const SizedBox(width: 8),
              const Text("PRODUKČNÍ ÚDAJE", style: TextStyle(color: _textDim, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _orderColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: _orderColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text("ČEKÁ NA POTVRZENÍ", style: TextStyle(color: _orderColor.withOpacity(0.9), fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _inputField("ČÍSLO OBJEDNÁVKY", _orderIdCtrl, icon: Icons.tag_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _inputField("VAZBA NA NABÍDKU", _refOfferCtrl, icon: Icons.link_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _inputField("POTVRZENÝ TERMÍN", TextEditingController(text: "24.02.2026"), icon: Icons.event_available_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _inputField("PRIORITA", TextEditingController(text: "VYSOKÁ"), icon: Icons.priority_high_rounded, valueColor: Colors.orangeAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _orderColor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _orderColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: _orderColor.withOpacity(0.8), size: 14),
              const SizedBox(width: 8),
              Text("KONTROLA DAT", style: TextStyle(color: _orderColor.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
            ],
          ),
          const Spacer(),
          _summaryRow("Počet položek", "${_items.length}"),
          _summaryRow("Kapacitní shoda", "ANO"),
          _summaryRow("Materiál skladem", "80 %"),
        ],
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, {IconData? icon, Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          height: 36,
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: TextField(
            controller: ctrl,
            style: TextStyle(color: valueColor ?? Colors.white, fontSize: 13, fontWeight: valueColor != null ? FontWeight.bold : FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: icon != null ? Padding(padding: const EdgeInsets.only(left: 10, right: 8), child: Icon(icon, size: 14, color: Colors.white24)) : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white30, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(6), border: Border.all(color: _borderColor)),
            child: const TextField(
              style: TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: "Hledat položku (název, materiál)...",
                hintStyle: TextStyle(color: _textDim, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: _textDim),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: _orderColor.withOpacity(0.1), foregroundColor: _orderColor, elevation: 0,
            side: BorderSide(color: _orderColor.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text("PŘIDAT POLOŽKU", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor, width: 2))),
      child: Row(
        children: [
          _headerText("POLOŽKA", flex: 3, index: 0),
          _headerText("MATERIÁL", flex: 2, index: 1),
          _headerText("MNOŽSTVÍ", flex: 1, index: 2),
          _headerText("TERMÍN", flex: 1, index: 3),
          const SizedBox(width: 152),
        ],
      ),
    );
  }

  Widget _headerText(String text, {required int flex, required int index}) {
    final bool isSorted = _sortColumnIndex == index;
    return Expanded(
      flex: flex, 
      child: InkWell(
        onTap: () => _onSort(index),
        child: Row(
          children: [
            Text(text, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(width: 6),
            Icon(
              isSorted ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded,
              size: 14,
              color: isSorted ? _accentColor : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  //  DROPZONE
  // =========================================================================
  Widget _buildDocumentationDropzone() {
    return DropTarget(
      onDragEntered: (_) { if (!_isDragOver) { setState(() => _isDragOver = true); _pulseController.repeat(reverse: true); } },
      onDragExited: (_) { setState(() => _isDragOver = false); _pulseController.stop(); _pulseController.reset(); },
      onDragDone: (details) {
        setState(() { _isDragOver = false; for (var file in details.files) { _attachedFiles.add(file.name); }});
        _pulseController.stop(); _pulseController.reset();
        Notifications.showSuccess(context, "${details.files.length} SOUBOR(Ů) PŘIDÁNO DO DOKUMENTACE");
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic, width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: _isDragOver ? 32 : 14),
        decoration: BoxDecoration(
          color: _isDragOver ? _accentColor.withOpacity(0.06) : _bgCard, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _isDragOver ? _accentColor.withOpacity(0.5) : _borderColor, width: _isDragOver ? 2 : 1),
        ),
        child: _isDragOver ? _buildDropzoneExpanded() : _buildDropzoneCollapsed(),
      ),
    );
  }

  Widget _buildDropzoneCollapsed() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.folder_open_rounded, size: 20, color: Colors.white24), SizedBox(height: 4),
            Text("PŘÍLOHY", style: TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          ]),
        ),
        const SizedBox(width: 16), Container(width: 1, height: 36, color: _borderColor), const SizedBox(width: 16),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 70),
            child: Scrollbar(
              controller: _collapsedScrollCtrl, thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _collapsedScrollCtrl,
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _attachedFiles.asMap().entries.map((e) => _FileChip(file: e.value, accentColor: _accentColor, icon: _getIconForExt(e.value), onDelete: () => setState(() => _attachedFiles.removeAt(e.key)))).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16), Container(width: 1, height: 36, color: _borderColor), const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.touch_app_rounded, size: 16, color: _accentColor.withOpacity(0.6)), const SizedBox(width: 8),
              Text("Přetáhnout sem", style: TextStyle(color: _accentColor.withOpacity(0.6), fontSize: 11, fontStyle: FontStyle.italic)), const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: Text("${_attachedFiles.length}", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropzoneExpanded() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_rounded, size: 28, color: _accentColor.withOpacity(_pulseAnimation.value)), const SizedBox(width: 12),
                Text("PŘETÁHNĚTE SOUBORY SEM", style: TextStyle(color: _accentColor.withOpacity(_pulseAnimation.value), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ],
            ),
            const SizedBox(height: 6),
            Text("PDF, STEP, DXF, DWG a další výrobní dokumentace", style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
            if (_attachedFiles.isNotEmpty) ...[
              const SizedBox(height: 16), Divider(color: _accentColor.withOpacity(0.1), height: 1), const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: Scrollbar(
                  controller: _expandedScrollCtrl, thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _expandedScrollCtrl,
                    child: Wrap(
                      spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                      children: _attachedFiles.asMap().entries.map((e) => _FileChip(file: e.value, accentColor: _accentColor, icon: _getIconForExt(e.value), onDelete: () => setState(() => _attachedFiles.removeAt(e.key)))).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  IconData _getIconForExt(String file) {
    final ext = p.extension(file).toLowerCase();
    if (ext == '.pdf') return Icons.picture_as_pdf_rounded;
    if (ext == '.step' || ext == '.stp') return Icons.view_in_ar_rounded;
    if (ext == '.dxf' || ext == '.dwg') return Icons.architecture_rounded;
    return Icons.insert_drive_file_outlined;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.white.withOpacity(0.05)), const SizedBox(height: 16),
          Text("Žádné položky k výrobě", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
        ],
      ),
    );
  }
}

// ===========================================================================
//  ČISTÝ INTERAKTIVNÍ ŘÁDEK TABULKY S KONTEXTOVÝM MENU A INLINE EDITACÍ
// ===========================================================================

class _OrderTableRow extends StatefulWidget {
  final _OrderItem item;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  
  const _OrderTableRow({required this.item, required this.onDuplicate, required this.onDelete});
  @override
  State<_OrderTableRow> createState() => _OrderTableRowState();
}

class _OrderTableRowState extends State<_OrderTableRow> {
  bool _isHovered = false;
  bool _isDeleteHovered = false;

  // Stavy pro inline editaci množství
  bool _isEditingQty = false;
  late TextEditingController _qtyCtrl;
  late FocusNode _qtyFocus;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.qty);
    _qtyFocus = FocusNode();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  void _saveQty() {
    setState(() {
      _isEditingQty = false;
      widget.item.qty = _qtyCtrl.text.trim().isEmpty ? "0" : _qtyCtrl.text.trim();
    });
  }

  void _showContextMenu(Offset position) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: const Color(0xFF16181D),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.white10)),
      items: [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16, color: Colors.white70), SizedBox(width: 8), Text('Upravit položku', style: TextStyle(color: Colors.white, fontSize: 12))])),
        const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_rounded, size: 16, color: Colors.white70), SizedBox(width: 8), Text('Duplikovat', style: TextStyle(color: Colors.white, fontSize: 12))])),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent), SizedBox(width: 8), Text('Smazat položku', style: TextStyle(color: Colors.redAccent, fontSize: 12))])),
      ],
    );

    if (result == 'duplicate') widget.onDuplicate();
    if (result == 'delete') widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showContextMenu(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isDeleteHovered
                ? Colors.redAccent.withValues(alpha: 0.06)
                : _isHovered ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 1. NÁZEV
              Expanded(
                flex: 3,
                child: Text(widget.item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),

              // 2. MATERIÁL
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(widget.item.material, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),

              // 3. MNOŽSTVÍ (INLINE EDITACE NA DVOJKLIK)
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onDoubleTap: () {
                    setState(() => _isEditingQty = true);
                    _qtyFocus.requestFocus();
                  },
                  child: _isEditingQty
                      ? Container(
                          height: 24,
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _qtyCtrl,
                            focusNode: _qtyFocus,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.only(bottom: 12),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _saveQty(),
                            onTapOutside: (_) => _saveQty(),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.item.qty, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            const SizedBox(width: 4),
                            const Text("ks", style: TextStyle(fontSize: 11, color: Colors.white30)),
                          ],
                        ),
                ),
              ),

              // 4. TERMÍN
              Expanded(
                flex: 1,
                child: Text(widget.item.deadline, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ),

              // 5. VÝKRESY + AKCE
              SizedBox(
                width: 152,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildFileIndicator(widget.item.pdfFile, Icons.picture_as_pdf_rounded, 'PDF'),
                    const SizedBox(width: 6),
                    _buildFileIndicator(widget.item.dxfFile, Icons.architecture_rounded, 'DXF'),
                    const SizedBox(width: 6),
                    _buildFileIndicator(widget.item.stepFile, Icons.view_in_ar_rounded, 'STP'),
                    const SizedBox(width: 6),
                    _buildFileIndicator(widget.item.imgFile, Icons.image_rounded, 'IMG'),
                    const SizedBox(width: 10),
                    Container(width: 1, height: 14, color: Colors.white.withValues(alpha: 0.08)),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      color: Colors.white24,
                      tooltip: "Upravit položku",
                      hoverColor: Colors.white10,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                    ),
                    MouseRegion(
                      onEnter: (_) => setState(() => _isDeleteHovered = true),
                      onExit: (_) => setState(() => _isDeleteHovered = false),
                      child: IconButton(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: _isDeleteHovered ? Colors.redAccent : Colors.redAccent.withValues(alpha: 0.5),
                        tooltip: "Smazat položku",
                        hoverColor: Colors.redAccent.withValues(alpha: 0.12),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileIndicator(String? filename, IconData icon, String label) {
    final bool exists = filename != null;
    final child = Tooltip(
      message: filename ?? label,
      preferBelow: false,
      child: Icon(
        icon,
        size: 14,
        color: exists ? Colors.white.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.07),
      ),
    );
    return child;
  }
}

// ===========================================================================
//  OSTATNÍ KOMPONENTY
// ===========================================================================

class _FileChip extends StatefulWidget {
  final String file;
  final Color accentColor;
  final VoidCallback onDelete;
  final IconData icon;

  const _FileChip({required this.file, required this.accentColor, required this.onDelete, required this.icon});

  @override
  State<_FileChip> createState() => _FileChipState();
}

class _FileChipState extends State<_FileChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _hovered ? widget.accentColor.withOpacity(0.12) : widget.accentColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _hovered ? widget.accentColor.withOpacity(0.35) : widget.accentColor.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 13, color: widget.accentColor.withOpacity(0.5)), const SizedBox(width: 8),
            Text(widget.file, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              child: _hovered
                  ? Padding(padding: const EdgeInsets.only(left: 6), child: GestureDetector(onTap: widget.onDelete, child: Icon(Icons.close_rounded, size: 13, color: Colors.redAccent.withOpacity(0.6))))
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItem {
  String name;
  String material;
  String qty;
  String deadline;
  String? pdfFile;
  String? dxfFile;
  String? stepFile;
  String? imgFile;

  _OrderItem({
    required this.name, required this.material, required this.qty, required this.deadline, 
    this.pdfFile, this.dxfFile, this.stepFile, this.imgFile
  });
}