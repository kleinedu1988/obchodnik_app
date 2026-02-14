import 'package:flutter/material.dart';
import 'dart:async';

import '../../../logic/db_service.dart';
import 'package:mrb_obchodnik/logic/notifications.dart';

class MaterialsListTab extends StatefulWidget {
  const MaterialsListTab({super.key});

  @override
  State<MaterialsListTab> createState() => _MaterialsListTabState();
}

class _MaterialsListTabState extends State<MaterialsListTab> {
  final List<Map<String, dynamic>> _seznamMaterialu = [];
  
  Timer? _debounce;
  String _query = '';
  bool _isLoading = false;

  // Design: ORANŽOVÁ pro Materiály
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _matColor = Color(0xFFFF9F1C); // Oranžová
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _query = val;
        _loadData();
      });
    });
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final rawData = await DbService().getMaterialy(query: _query);
      
      // Mutable copy
      final List<Map<String, dynamic>> mutableData = rawData
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (mounted) {
        setState(() {
          _seznamMaterialu.clear();
          _seznamMaterialu.addAll(mutableData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Notifications.showError(context, "CHYBA: $e");
      }
    }
  }

  Future<void> _smazatMaterial(int id) async {
    await DbService().deleteMaterial(id);
    Notifications.showSuccess(context, "MATERIÁL ODSTRANĚN");
    _loadData();
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildControls(),
        const SizedBox(height: 24),
        _buildTableHeader(),
        
        Expanded(
          child: _seznamMaterialu.isEmpty && !_isLoading
              ? _buildEmptyState()
              : _buildList(),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      itemCount: _seznamMaterialu.length,
      padding: const EdgeInsets.only(bottom: 80),
      separatorBuilder: (context, index) => const Divider(color: _borderColor, height: 1),
      itemBuilder: (context, index) {
        return _buildMaterialRow(_seznamMaterialu[index]);
      },
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _borderColor),
            ),
            child: TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              cursorColor: _matColor,
              decoration: InputDecoration(
                hintText: "Hledat materiál (S235, 1.4301)...",
                hintStyle: const TextStyle(color: _textDim, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _textDim),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // TLAČÍTKO + NOVÝ MATERIÁL (Otevírá zjednodušený dialog)
        ElevatedButton.icon(
          onPressed: () => _showCreateDialog(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _matColor.withOpacity(0.1),
            foregroundColor: _matColor,
            elevation: 0,
            side: BorderSide(color: _matColor.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text("NOVÝ MATERIÁL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor, width: 2)),
      ),
      child: Row(
        children: [
          _headerText("OZNAČENÍ", flex: 2),
          _headerText("ALTERNATIVNÍ NÁZVY", flex: 3),
          _headerText("DEFINOVANÉ TLOUŠŤKY (mm)", flex: 5),
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildMaterialRow(Map<String, dynamic> item) {
    // Rozparsujeme tloušťky
    String rawTloustky = item['tloustky'] ?? '';
    List<String> chips = rawTloustky.split(',')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    
    // Setřídíme čísla (UX vylepšení), aby byly např. 1, 2, 10 a ne 10, 2, 1
    chips.sort((a, b) {
       double da = double.tryParse(a) ?? 0;
       double db = double.tryParse(b) ?? 0;
       return da.compareTo(db);
    });

    return InkWell(
      // Kliknutí na řádek otevírá editaci názvu (CreateDialog v edit módu)
      onTap: () => _showCreateDialog(item: item),
      hoverColor: Colors.white.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 1. OZNAČENÍ
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _matColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _matColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      item['nazev'],
                      style: const TextStyle(
                        color: _matColor, 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        fontFamily: 'monospace'
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 2. ALIAS
            Expanded(
              flex: 3,
              child: Text(
                item['alias'] ?? '-', 
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // 3. TLOUŠŤKY (Smart Chips + Add Button)
            Expanded(
              flex: 5,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                   // Existující tloušťky
                   ...chips.take(8).map((t) => Container(
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     decoration: BoxDecoration(
                       color: Colors.white.withOpacity(0.05),
                       borderRadius: BorderRadius.circular(4),
                       border: Border.all(color: Colors.white10),
                     ),
                     child: Text(
                       t.trim(),
                       style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                     ),
                   )),
                   
                   // Indikátor skrytých (pokud je jich moc)
                   if (chips.length > 8)
                    Text(" +${chips.length - 8}", style: const TextStyle(fontSize: 10, color: Colors.white30)),

                   // TLAČÍTKO PRO PŘIDÁNÍ TLOUŠŤKY (Malé +)
                   InkWell(
                     onTap: () => _showThicknessManager(item),
                     borderRadius: BorderRadius.circular(4),
                     child: Container(
                       margin: const EdgeInsets.only(left: 4),
                       padding: const EdgeInsets.all(2),
                       decoration: BoxDecoration(
                         color: _matColor.withOpacity(0.2),
                         borderRadius: BorderRadius.circular(4),
                         border: Border.all(color: _matColor.withOpacity(0.4)),
                       ),
                       child: const Icon(Icons.add, size: 14, color: _matColor),
                     ),
                   )
                ],
              ),
            ),
            
            // 4. AKCE
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _showCreateDialog(item: item),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    color: Colors.white24,
                    tooltip: "Upravit název/alias",
                    hoverColor: Colors.white10,
                  ),
                  IconButton(
                    onPressed: () => _smazatMaterial(item['id']),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: Colors.redAccent.withOpacity(0.5),
                    tooltip: "Smazat materiál",
                    hoverColor: Colors.redAccent.withOpacity(0.1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  //  DIALOG 1: VYTVOŘENÍ / EDITACE HLAVIČKY (Jen Název a Alias)
  // ===========================================================================
  
  void _showCreateDialog({Map<String, dynamic>? item}) {
    final isNew = item == null;
    final nazevCtrl = TextEditingController(text: item?['nazev'] ?? '');
    final aliasCtrl = TextEditingController(text: item?['alias'] ?? '');
    // Tloušťky tady neřešíme, jen je přenášíme, aby se nesmazaly při editaci
    final currentTloustky = item?['tloustky'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _borderColor)),
        title: Text(
          isNew ? "Nový materiál" : "Upravit údaje materiálu", 
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogInput(nazevCtrl, "Označení (např. S235)", isCode: true, autoFocus: true),
            const SizedBox(height: 12),
            _buildDialogInput(aliasCtrl, "Alternativní označení (např. 11 373, Fe360)"),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 6),
              child: Text("Pozn: Tloušťky se přidávají až po vytvoření.", style: TextStyle(color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Zrušit", style: TextStyle(color: Colors.white30)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nazevCtrl.text.isEmpty) return;
              
              await DbService().saveMaterial(
                id: item?['id'],
                nazev: nazevCtrl.text,
                alias: aliasCtrl.text,
                tloustky: currentTloustky, // Zachováme existující, pokud editujeme
              );
              
              if (mounted) {
                Navigator.pop(ctx);
                _loadData();
                Notifications.showSuccess(context, isNew ? "MATERIÁL VYTVOŘEN" : "ÚDAJE ULOŽENY");
                
                // Pokud je nový, můžeme rovnou nabídnout otevření tlouštěk? 
                // Ne, necháme uživatele kliknout, je to čistší.
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _matColor,
              foregroundColor: Colors.black,
            ),
            child: const Text("Uložit"),
          )
        ],
      ),
    );
  }

  // ===========================================================================
  //  DIALOG 2: MANAŽER TLOUŠTĚK (Specializovaný)
  // ===========================================================================

  void _showThicknessManager(Map<String, dynamic> item) {
    // Příprava dat
    String raw = item['tloustky'] ?? '';
    List<String> currentList = raw.split(',').where((e) => e.trim().isNotEmpty).toList();
    
    // Controller pro přidávání
    final addCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        // Používáme StatefulBuilder, abychom mohli refreshovat dialog při přidání čipu
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            void addThickness() {
              final val = addCtrl.text.trim().replaceAll(',', '.'); // Fix české čárky
              if (val.isEmpty) return;
              
              // Kontrola duplicit
              if (!currentList.contains(val)) {
                setDialogState(() {
                  currentList.add(val);
                  // Sort
                  currentList.sort((a, b) => (double.tryParse(a)??0).compareTo(double.tryParse(b)??0));
                });
                addCtrl.clear();
              }
            }

            void removeThickness(String val) {
              setDialogState(() {
                currentList.remove(val);
              });
            }

            Future<void> saveAndClose() async {
              final newString = currentList.join(',');
              await DbService().saveMaterial(
                id: item['id'],
                nazev: item['nazev'],
                alias: item['alias'],
                tloustky: newString,
              );
              if (mounted) {
                Navigator.pop(ctx);
                _loadData(); // Refresh hlavního seznamu
                Notifications.showSuccess(context, "TLOUŠŤKY ULOŽENY");
              }
            }

            return AlertDialog(
              backgroundColor: _bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _borderColor)),
              title: Row(
                children: [
                  Text("Tloušťky pro ${item['nazev']}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _matColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text("${currentList.length} ks", style: const TextStyle(color: _matColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // INPUT FIELD
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6), border: Border.all(color: _borderColor)),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: TextField(
                              controller: addCtrl,
                              autofocus: true,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "Zadej tloušťku (např. 2.5)",
                                hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                              ),
                              onSubmitted: (_) => addThickness(), // Enter přidá
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: addThickness,
                          icon: const Icon(Icons.add_circle_rounded),
                          color: _matColor,
                          tooltip: "Přidat",
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text("AKTIVNÍ TLOUŠŤKY:", style: TextStyle(color: _textDim, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    
                    // SEZNAM ČIPŮ (S MOŽNOSTÍ MAZÁNÍ)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: currentList.isEmpty 
                        ? const Center(child: Text("Zatím žádné tloušťky", style: TextStyle(color: Colors.white12, fontSize: 12)))
                        : SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: currentList.map((t) => Chip(
                                label: Text(t, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                backgroundColor: _matColor.withOpacity(0.2),
                                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white54),
                                onDeleted: () => removeThickness(t),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide.none),
                                padding: const EdgeInsets.all(0),
                                visualDensity: VisualDensity.compact,
                              )).toList(),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx), // Zrušit bez uložení změn v tomto dialogu?
                  // Lepší je uložit jen při stisku Uložit.
                  child: const Text("Zrušit", style: TextStyle(color: Colors.white30)),
                ),
                ElevatedButton(
                  onPressed: saveAndClose,
                  style: ElevatedButton.styleFrom(backgroundColor: _matColor, foregroundColor: Colors.black),
                  child: const Text("Uložit změny"),
                )
              ],
            );
          },
        );
      },
    );
  }

  // --- POMOCNÉ WIDGETY ---

  Widget _buildDialogInput(TextEditingController ctrl, String hint, {bool isCode = false, bool isNumber = false, bool autoFocus = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6), border: Border.all(color: _borderColor)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: ctrl,
        autofocus: autoFocus,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(
          color: Colors.white, 
          fontFamily: isCode || isNumber ? 'monospace' : null,
          fontWeight: isCode ? FontWeight.bold : FontWeight.normal
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        ),
      ),
    );
  }

  Widget _headerText(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.layers_outlined, size: 48, color: Colors.white12),
          const SizedBox(height: 16),
          Text("Katalog materiálů je prázdný", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
          const SizedBox(height: 16),
          TextButton(
             onPressed: () => _showCreateDialog(),
             child: const Text("VYTVOŘIT PRVNÍ", style: TextStyle(color: _matColor, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}