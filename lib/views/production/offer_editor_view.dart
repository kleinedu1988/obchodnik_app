import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../logic/notifications.dart';
import 'package:path/path.dart' as p;

class OfferEditorView extends StatefulWidget {
  const OfferEditorView({super.key});

  @override
  State<OfferEditorView> createState() => _OfferEditorViewState();
}

class _OfferEditorViewState extends State<OfferEditorView> with SingleTickerProviderStateMixin {
  // --- DESIGN KONSTANTY ---
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;

  // --- STAV ---
  final TextEditingController _offerIdCtrl = TextEditingController(text: "NAB-2026-0001");
  final TextEditingController _customerCtrl = TextEditingController();

  // Posuvníky pro seznamy souborů
  final ScrollController _collapsedScrollCtrl = ScrollController();
  final ScrollController _expandedScrollCtrl = ScrollController();

  // Dropzone
  bool _isDragOver = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<String> _attachedDrawings = [
    "vykres_hridel_v1.pdf",
    "prizma_base.step",
    "schema_zapojeni.pdf",
    "technicka_zprava.pdf",
    "model_sestavy.stp",
  ];

  final List<_OfferItem> _items = [
    _OfferItem(name: "Hřídel motoru L-200", material: "S235JR", qty: "12", operations: "Soustružení"),
    _OfferItem(name: "Příruba ventilu", material: "Nerez A4", qty: "5", operations: "Frézování, Laser"),
    _OfferItem(name: "Konzola montážní", material: "S355J2", qty: "8", operations: "Laser, Svařování"),
    _OfferItem(name: "Čep vedení", material: "16MnCr5", qty: "20", operations: "Soustružení, Kalení"),
    _OfferItem(name: "Krytka ložiska", material: "DX51D+Z", qty: "15", operations: "Laser"),
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
    _offerIdCtrl.dispose();
    _customerCtrl.dispose();
    _collapsedScrollCtrl.dispose();
    _expandedScrollCtrl.dispose();
    super.dispose();
  }

  // =========================================================================
  //  BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // 1) HORNÍ PÁS: Obchodní údaje (2/3) + Stav nabídky (1/3)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: _buildFormCard()),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _buildStatusCard()),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2) CONTROLS
          _buildControls(),
          const SizedBox(height: 16),

          // 3) HLAVIČKA TABULKY
          _buildTableHeader(),

          // 4) SEZNAM POLOŽEK
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

          // 5) DOKUMENTACE – DROPZONE
          const SizedBox(height: 16),
          _buildDocumentationDropzone(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // =========================================================================
  //  HORNÍ PÁS: OBCHODNÍ ÚDAJE
  // =========================================================================

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
              const Text("OBCHODNÍ ÚDAJE", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const Spacer(),
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: _accentColor, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.4), blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 6),
              Text("ROZPRACOVÁNO", style: TextStyle(color: _accentColor.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _inputField("IDENTIFIKÁTOR NABÍDKY", _offerIdCtrl, icon: Icons.tag_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _inputField("ZÁKAZNÍK", _customerCtrl, icon: Icons.business_center_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _inputField("TERMÍN DODÁNÍ", TextEditingController(text: "14 dní"), icon: Icons.calendar_today_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _inputField("ZODPOVĚDNÁ OSOBA", TextEditingController(text: "Ing. Petr Novák"), icon: Icons.person_outline_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  //  HORNÍ PÁS: STAV NABÍDKY
  // =========================================================================

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accentColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _accentColor, size: 14),
              const SizedBox(width: 8),
              Text("STAV NABÍDKY", style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
            ],
          ),
          const Spacer(),
          _summaryRow("Počet položek", "${_items.length}"),
          _summaryRow("Rozpracovanost", "45 %"),
          _summaryRow("Validace příloh", "OK"),
        ],
      ),
    );
  }

  // =========================================================================
  //  CONTROLS
  // =========================================================================

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
                hintText: "Hledat položku (název, materiál, operace)...",
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
            backgroundColor: _accentColor.withOpacity(0.1),
            foregroundColor: _accentColor,
            elevation: 0,
            side: BorderSide(color: _accentColor.withOpacity(0.5)),
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
  //  TABLE HEADER
  // =========================================================================

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor, width: 2)),
      ),
      child: Row(
        children: [
          _headerText("NÁZEV / VÝKRES", flex: 4),
          _headerText("MATERIÁL", flex: 2),
          _headerText("MNOŽSTVÍ", flex: 1),
          _headerText("OPERACE", flex: 2),
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  // =========================================================================
  //  ŘÁDEK
  // =========================================================================

  Widget _buildItemRow(_OfferItem item) {
    return _OfferTableRow(
      item: item,
      onDelete: () => setState(() => _items.remove(item)),
    );
  }

  // =========================================================================
  //  DROPZONE: DOKUMENTACE (DESKTOP DROP)
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
            _attachedDrawings.add(file.name);
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
          vertical: _isDragOver ? 32 : 14,
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
                  children: _attachedDrawings.asMap().entries.map((entry) {
                    return _FileChip(
                      file: entry.value,
                      accentColor: _accentColor,
                      icon: _getIconForExt(entry.value),
                      onDelete: () => setState(() => _attachedDrawings.removeAt(entry.key)),
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
                child: Text("${_attachedDrawings.length}", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
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
            if (_attachedDrawings.isNotEmpty) ...[
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
                      children: _attachedDrawings.asMap().entries.map((entry) {
                        return _FileChip(
                          file: entry.value,
                          accentColor: _accentColor,
                          icon: _getIconForExt(entry.value),
                          onDelete: () => setState(() => _attachedDrawings.removeAt(entry.key)),
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

  // =========================================================================
  //  SDÍLENÉ HELPERS
  // =========================================================================

  Widget _inputField(String label, TextEditingController ctrl, {IconData? icon}) {
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
            style: const TextStyle(color: Colors.white, fontSize: 12),
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
          Text("Žádné položky nabídky", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
        ],
      ),
    );
  }
}

// ===========================================================================
//  ŘÁDEK NABÍDKY
// ===========================================================================

class _OfferTableRow extends StatefulWidget {
  final _OfferItem item;
  final VoidCallback onDelete;

  const _OfferTableRow({required this.item, required this.onDelete});

  @override
  State<_OfferTableRow> createState() => _OfferTableRowState();
}

class _OfferTableRowState extends State<_OfferTableRow> {
  bool _isHovered = false;
  bool _isDeleteHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
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
              flex: 4,
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
            // 3. MNOŽSTVÍ
            Expanded(
              flex: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.item.qty, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  const SizedBox(width: 4),
                  const Text("ks", style: TextStyle(fontSize: 11, color: Colors.white30)),
                ],
              ),
            ),
            // 4. OPERACE
            Expanded(
              flex: 2,
              child: Text(widget.item.operations, style: const TextStyle(color: Colors.white38, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            // 5. AKCE
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                      tooltip: "Odebrat položku",
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
    );
  }
}

// ===========================================================================
//  FILE CHIP – hover efekt s ×
// ===========================================================================

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

// ===========================================================================
//  DATOVÝ MODEL (Mock)
// ===========================================================================

class _OfferItem {
  final String name;
  final String material;
  final String qty;
  final String operations;

  const _OfferItem({
    required this.name,
    required this.material,
    required this.qty,
    required this.operations,
  });
}