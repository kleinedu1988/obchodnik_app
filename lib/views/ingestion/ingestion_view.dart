import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:async';
import 'package:path/path.dart' as p;

// Logika a UI komponenty
import '../../../logic/ingestion_service.dart';
import '../../../logic/workflow_controller.dart';
import '../../../logic/notifications.dart';

class IngestionView extends StatefulWidget {
  final VoidCallback onSuccess; // Callback pro přepnutí tabu v Shellu

  const IngestionView({
    super.key,
    required this.onSuccess,
  });

  @override
  State<IngestionView> createState() => _IngestionViewState();
}

class _IngestionViewState extends State<IngestionView> with SingleTickerProviderStateMixin {
  // --- STAV A LOGIKA ---
  late AnimationController _controller;
  final IngestionService _service = IngestionService();
  final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);

  bool _isDragging = false;
  IngestionResult? _summary;

  // --- DESIGN KONSTANTY (v0.4.2 Standard) ---
  static const Color _bgDeep = Color(0xFF0F1115);
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _dragActiveColor = Colors.greenAccent;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  // ===========================================================================
  //  HLAVNÍ PROCES (Ingesce & Unpack)
  // ===========================================================================

  Future<void> _processFiles(List<XFile> files) async {
    if (files.isEmpty) return;

    _progressNotifier.value = 0.0;

    // Detekce archivů pro vizuální zpětnou vazbu
    final bool hasArchives = files.any(
      (f) => p.extension(f.path).toLowerCase() == '.zip' || p.extension(f.path).toLowerCase() == '.rar',
    );

    Notifications.showProgress(
      context,
      progressNotifier: _progressNotifier,
      taskName: hasArchives ? "SMART UNPACK & EXTRAKCE" : "ANALÝZA STRUKTURY",
      doneText: "HOTOVO",
    );

    // Volání IngestionService (tady probíhá reálné rozbalování a třídění)
    final result = await _service.processFiles(files);

    // UX dýchání - progress skok
    _progressNotifier.value = 0.8;
    await Future.delayed(const Duration(milliseconds: 400));
    _progressNotifier.value = 1.0;

    if (!mounted) return;

    if (result.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Notifications.showWarning(context, "NENALEZENA ŽÁDNÁ PODPOROVANÁ DATA");
      return;
    }

    setState(() => _summary = result);

    Notifications.finishProgress(
      context,
      finalMessage: hasArchives
          ? "ARCHIV ROZBALEN: ${result.files.length} POLOŽEK PŘIPRAVENO"
          : "PŘIJATO: ${result.files.length} SOUBORŮ",
    );
  }

  // ===========================================================================
  //  STAV 1: DROP ZONE VIEW
  // ===========================================================================

  Widget _buildDropZone() {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) => _processFiles(details.files),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAnimatedDropCard(),
            const SizedBox(height: 48),
            _buildFormatLegend(),
            const SizedBox(height: 32),
            _buildBrowseButton(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  //  STAV 2: SUMMARY REPORT VIEW (Po nahrání)
  // ===========================================================================

  Widget _buildSummaryReport() {
    final s = _summary!;
    return Center(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, color: _accentColor, size: 48),
            const SizedBox(height: 16),
            const Text(
              "SOUHRN PŘIJATÝCH DAT",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            Text(
              "Obsah archivů byl extrahován do dočasné relace.",
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11),
            ),
            const SizedBox(height: 32),

            // STATISTIKY (Zde už ZIPy nejsou, jen rozbalený obsah)
            _buildSummaryRow("Excel data (.xlsx/.xls)", s.dataCount, Colors.green),
            _buildSummaryRow("Technické výkresy (.pdf)", s.drawingCount, Colors.red),
            _buildSummaryRow("3D Modely & CAD (.step, .igs, .dxf)", s.cadCount, Colors.blue),
            _buildSummaryRow("Ostatní přílohy (img, html, txt)", s.assetCount, Colors.white38),

            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _summary = null),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white10),
                      foregroundColor: Colors.white30,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("ZRUŠIT"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // 1. Odemkneme Sidebar workflow přes Singleton
                      WorkflowController().unlockWorkflow(DocType.offer);
                      // 2. Voláme callback do AppShellu pro přepnutí tabu
                      widget.onSuccess();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("POKRAČOVAT K EDITORU"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  //  UI POMOCNÉ PRVKY
  // ===========================================================================

  Widget _buildSummaryRow(String label, int count, Color color) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text("$count ks", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildAnimatedDropCard() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double glow = _isDragging ? 1.0 : _controller.value;
        return Container(
          width: 500, height: 320,
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isDragging ? _dragActiveColor : _accentColor.withOpacity(0.2 + (0.4 * glow)),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (_isDragging ? _dragActiveColor : _accentColor).withOpacity(0.1 * glow),
                blurRadius: 20 * glow,
                spreadRadius: 2 * glow,
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isDragging ? Icons.file_download_rounded : Icons.cloud_upload_outlined,
                size: 72,
                color: _isDragging ? _dragActiveColor : _accentColor,
              ),
              const SizedBox(height: 24),
              const Text(
                "DROP ZONE",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              Text(
                _isDragging ? "PUSTIT PRO ANALÝZU" : "PŘETÁHNĚTE SOUBORY NEBO ARCHIVY",
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrowseButton() {
    return InkWell(
      onTap: () async {
        final result = await _service.pickFilesFromDisk();
        if (result.files.isNotEmpty) {
          setState(() => _summary = result);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _accentColor.withOpacity(0.5)),
        ),
        child: const Text(
          "PROCHÁZET DISK",
          style: TextStyle(color: _accentColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildFormatLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _formatChip("TABULKY", Colors.green),
        const SizedBox(width: 12),
        _formatChip("VÝKRESY", Colors.red),
        const SizedBox(width: 12),
        _formatChip("3D & CAD", Colors.blue),
        const SizedBox(width: 12),
        _formatChip("ZIP / RAR", Colors.purpleAccent),
      ],
    );
  }

  Widget _formatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDeep,
      child: _summary == null ? _buildDropZone() : _buildSummaryReport(),
    );
  }
}