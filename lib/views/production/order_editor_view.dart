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
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;
  static const Color _orderColor = Color(0xFF10B981);
  static const Color _matColor = Color(0xFFFF9F1C);
  static const Color _accentColor = Color(0xFF4077D1);

  final TextEditingController _orderIdCtrl = TextEditingController(text: "OBJ-2026-0452");
  final TextEditingController _refOfferCtrl = TextEditingController(text: "NAB-2026-0001");

  // Posuvníky pro seznamy souborů
  final ScrollController _collapsedScrollCtrl = ScrollController();
  final ScrollController _expandedScrollCtrl = ScrollController();

  bool _isDragOver = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<String> _attachedFiles = [
    "sestava_final.pdf",
    "dil_01.step",
    "dil_02.step",
    "balici_predpis.txt",
    "certifikat_materialu.pdf",
    "vykres_01.dwg",
    "vykres_02.dxf",
  ];

  // --- NOVÁ MOCK DATA S PŘIPOJENÝMI VÝKRESY ---
  final List<_OrderItem> _items = [
    _OrderItem(name: "Sestava rámu X-Y", material: "Ocel 11 373", qty: "2", deadline: "20.02.", pdfFile: "ram_sestava.pdf", stepFile: "ram_sestava.stp"),
    _OrderItem(name: "Čep kalený 20mm", material: "16MnCr5", qty: "50", deadline: "18.02.", pdfFile: "cep_v2.pdf", dxfFile: "cep_v2.dxf"),
    _OrderItem(name: "Kryt plechový", material: "DX51D+Z", qty: "10", deadline: "22.02.", dxfFile: "kryt_paly.dxf", imgFile: "skica_zakaznik.jpg"),
    _OrderItem(name: "Distanční kroužek", material: "S235JR", qty: "25", deadline: "19.02.", pdfFile: "krouzek.pdf"),
    _OrderItem(name: "Nosník příčný L-400", material: "S355J2", qty: "4", deadline: "21.02."), // Bez výkresů
    _OrderItem(name: "Patka montážní", material: "DX51D+Z", qty: "8", deadline: "23.02.", stepFile: "patka_model.step"),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: _buildFormCard()),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _buildSummaryCard()),
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
                    itemBuilder: (context, index) => _buildItemRow(_items[index]),
                  ),
          ),
          _buildDocumentationDropzone(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("PRODUKČNÍ ÚDAJE", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const Spacer(),
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: _orderColor, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _orderColor.withOpacity(0.4), blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 6),
              Text("ČEKÁ NA POTVRZENÍ", style: TextStyle(color: _orderColor.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _inputField("ČÍSLO OBJEDNÁVKY", _orderIdCtrl, icon: Icons.tag_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _inputField("VAZBA NA NABÍDKU", _refOfferCtrl, icon: Icons.link_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _inputField("POTVRZENÝ TERMÍN", TextEditingController(text: "24.02.2026"), icon: Icons.event_available_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _inputField("PRIORITA", TextEditingController(text: "VYSOKÁ"), icon: Icons.priority_high_rounded, valueColor: Colors.orangeAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _orderColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _orderColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: _orderColor, size: 14),
              const SizedBox(width: 8),
              Text("KONTROLA DAT", style: TextStyle(color: _orderColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
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
            backgroundColor: _orderColor.withOpacity(0.1),
            foregroundColor: _orderColor,
            elevation: 0,
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

  // =========================================================================
  //  TABULKA POLOŽEK
  // =========================================================================

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor, width: 2)),
      ),
      child: Row(
        children: [
          _headerText("POLOŽKA", flex: 3),
          _headerText("MATERIÁL", flex: 2),
          _headerText("VÝKRESY", flex: 2), // NOVÝ SLOUPEC
          _headerText("MNOŽSTVÍ", flex: 1),
          _headerText("DEADLINE", flex: 1),
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildItemRow(_OrderItem item) {
    return InkWell(
      onTap: () {},
      hoverColor: Colors.white.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _matColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: _matColor.withOpacity(0.3))),
                  child: Text(item.material, style: const TextStyle(color: _matColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
            
            // --- BLOK VÝKRESŮ (PDF, DXF, STEP, IMG) ---
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  _buildFileIcon(item.pdfFile, Icons.picture_as_pdf_rounded, Colors.redAccent),
                  const SizedBox(width: 6),
                  _buildFileIcon(item.dxfFile, Icons.architecture_rounded, Colors.lightBlue),
                  const SizedBox(width: 6),
                  _buildFileIcon(item.stepFile, Icons.view_in_ar_rounded, Colors.green),
                  const SizedBox(width: 6),
                  _buildFileIcon(item.imgFile, Icons.image_rounded, Colors.amber),
                ],
              ),
            ),

            Expanded(flex: 1, child: Text("${item.qty} ks", style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w500))),
            Expanded(flex: 1, child: Text(item.deadline, style: const TextStyle(color: _orderColor, fontSize: 12, fontWeight: FontWeight.bold))),
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.edit_note_rounded, size: 18), color: Colors.white24),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline_rounded, size: 18), color: Colors.redAccent.withOpacity(0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- POMOCNÁ METODA PRO IKONKU SOUBORU ---
  Widget _buildFileIcon(String? filename, IconData icon, Color activeColor) {
    final bool exists = filename != null;
    return Tooltip(
      message: exists ? filename : "Chybí",
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: exists ? activeColor.withOpacity(0.15) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: exists ? activeColor.withOpacity(0.4) : Colors.white.withOpacity(0.05)),
        ),
        child: Icon(
          icon,
          size: 14,
          color: exists ? activeColor : Colors.white24,
        ),
      ),
    );
  }

  // =========================================================================
  //  DROPZONE S KOMPAKTNÍM NÁPISEM
  // =========================================================================

  Widget _buildDocumentationDropzone() {
    return DropTarget(
      onDragEntered: (details) {
        if (!_isDragOver) {
          setState(() => _isDragOver = true);
          _pulseController.repeat(reverse: true);
        }
      },
      onDragExited: (details) {
        setState(() => _isDragOver = false);
        _pulseController.stop();
        _pulseController.reset();
      },
      onDragDone: (details) {
        setState(() {
          _isDragOver = false;
          for (var file in details.files) {
            _attachedFiles.add(file.name);
          }
        });
        _pulseController.stop();
        _pulseController.reset();
        
        final count = details.files.length;
        Notifications.showSuccess(context, "$count SOUBOR(Ů) PŘIDÁNO DO DOKUMENTACE");
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: _isDragOver ? 48 : 28,
        ),
        decoration: BoxDecoration(
          color: _isDragOver ? _accentColor.withOpacity(0.06) : _bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isDragOver ? _accentColor.withOpacity(0.5) : _borderColor,
            width: _isDragOver ? 2 : 1,
          ),
        ),
        child: _isDragOver ? _buildDropzoneExpanded() : _buildDropzoneCollapsed(),
      ),
    );
  }

  Widget _buildDropzoneCollapsed() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. KOMPAKTNÍ LEVÝ BLOK
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_rounded, size: 20, color: Colors.white24),
              SizedBox(height: 4),
              Text("PŘÍLOHY", style: TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
            ],
          ),
        ),
        
        const SizedBox(width: 16),
        Container(width: 1, height: 36, color: _borderColor),
        const SizedBox(width: 16),

        // 2. SCROLLOVATELNÝ MULTI-LINE WRAP
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 70),
            child: Scrollbar(
              controller: _collapsedScrollCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _collapsedScrollCtrl,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _attachedFiles.asMap().entries.map((entry) {
                    return _FileChip(
                      file: entry.value,
                      accentColor: _accentColor,
                      icon: _getIconForExt(entry.value),
                      onDelete: () => setState(() => _attachedFiles.removeAt(entry.key)),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),
        Container(width: 1, height: 36, color: _borderColor),
        const SizedBox(width: 16),

        // 3. KOMPAKTNÍ PRAVÝ BLOK
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.touch_app_rounded, size: 16, color: _accentColor.withOpacity(0.6)),
              const SizedBox(width: 8),
              Text("Přetáhnout sem", style: TextStyle(color: _accentColor.withOpacity(0.6), fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(width: 12),
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
                Icon(Icons.cloud_upload_rounded, size: 28, color: _accentColor.withOpacity(_pulseAnimation.value)),
                const SizedBox(width: 12),
                Text(
                  "PŘETÁHNĚTE SOUBORY SEM",
                  style: TextStyle(
                    color: _accentColor.withOpacity(_pulseAnimation.value),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "PDF, STEP, DXF, DWG a další výrobní dokumentace",
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11),
            ),
            if (_attachedFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: _accentColor.withOpacity(0.1), height: 1),
              const SizedBox(height: 12),
              
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: Scrollbar(
                  controller: _expandedScrollCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _expandedScrollCtrl,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: _attachedFiles.asMap().entries.map((entry) {
                        return _FileChip(
                          file: entry.value,
                          accentColor: _accentColor,
                          icon: _getIconForExt(entry.value),
                          onDelete: () => setState(() => _attachedFiles.removeAt(entry.key)),
                        );
                      }).toList(),
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

  Widget _inputField(String label, TextEditingController ctrl, {IconData? icon, Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 5),
        Container(
          height: 38,
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6), border: Border.all(color: _borderColor)),
          child: TextField(
            controller: ctrl,
            style: TextStyle(color: valueColor ?? Colors.white, fontSize: 12, fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal),
            decoration: InputDecoration(
              prefixIcon: icon != null
                  ? Padding(padding: const EdgeInsets.only(left: 10, right: 6), child: Icon(icon, size: 14, color: Colors.white10))
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerText(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
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
          Icon(Icons.inbox_rounded, size: 48, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text("Žádné položky k výrobě", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
        ],
      ),
    );
  }
}

class _FileChip extends StatefulWidget {
  final String file;
  final Color accentColor;
  final VoidCallback onDelete;
  final IconData icon;

  const _FileChip({
    required this.file,
    required this.accentColor,
    required this.onDelete,
    required this.icon,
  });

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
          color: _hovered
              ? widget.accentColor.withOpacity(0.12)
              : widget.accentColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _hovered
                ? widget.accentColor.withOpacity(0.35)
                : widget.accentColor.withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 13, color: widget.accentColor.withOpacity(0.5)),
            const SizedBox(width: 8),
            Text(widget.file, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              child: _hovered
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: widget.onDelete,
                        child: Icon(Icons.close_rounded, size: 13, color: Colors.redAccent.withOpacity(0.6)),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DATOVÝ MODEL (NOVĚ ROZŠÍŘENÝ O TYPY VÝKRESŮ) ---
class _OrderItem {
  final String name;
  final String material;
  final String qty;
  final String deadline;
  final String? pdfFile;
  final String? dxfFile;
  final String? stepFile;
  final String? imgFile;

  const _OrderItem({
    required this.name,
    required this.material,
    required this.qty,
    required this.deadline,
    this.pdfFile,
    this.dxfFile,
    this.stepFile,
    this.imgFile,
  });
}