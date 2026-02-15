import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

// --- LOGIKA A SLUŽBY ---
import '../../../logic/ingestion_service.dart';
import '../../../logic/workflow_controller.dart';
import '../../../logic/notifications.dart';

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

  bool _isDragging = false;

  // --- DESIGN SYSTÉMU BRIDGE ---
  static const Color _bgDeep = Color(0xFF0F1115);
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white24;

  // --- LOGICKÝ ZÁMEK (Policista drží klíč) ---
  bool get _isLocked => _workflow.isEditorUnlocked || _workflow.isProcessing;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ===========================================================================
  //  LOGIKA: Zpracování souborů
  // ===========================================================================

  Future<void> _handleFileAction(List<XFile> files) async {
    // Pokud je UI zamčené, ignorujeme veškeré pokusy (bezpečnostní pojistka)
    if (files.isEmpty || _isLocked) return;

    _workflow.setProcessing(true);

    try {
      // 1. Dělník (Service) připraví a roztřídí soubory v sandboxu
      final result = await _ingestionService.processFiles(files);
      
      if (!mounted) return;

      // 2. Notifikace podle výsledku třídění
      if (result.ignoredCount > 0) {
        Notifications.showWarning(context, "DOKONČENO S IGNOROVÁNÍM: ${result.summaryLine}");
      } else {
        Notifications.showSuccess(context, "SOUBORY ROZTŘÍDĚNY: ${result.summaryLine}");
      }

      // 3. Policista (Controller) převezme výsledek a rozhodne o stavu
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
        // AbsorbPointer fyzicky znemožní veškeré klikání a přetahování, pokud je zamčeno
        return AbsorbPointer(
          absorbing: _isLocked,
          child: Scaffold(
            backgroundColor: _bgDeep,
            body: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                // Vizuální znázornění nedostupnosti (ztlumení celého okna)
                opacity: _isLocked ? 0.35 : 1.0, 
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _workflow.lastIngestion == null 
                      ? _buildDropZone() 
                      : _buildDecisionOverlay(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 1. VÝCHOZÍ STAV: DropZone
  Widget _buildDropZone() {
    return DropTarget(
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

  /// 2. ROZHODOVACÍ STAV: Karta po nahrání dat
  Widget _buildDecisionOverlay() {
    final result = _workflow.lastIngestion!;
    
    return Container(
      key: const ValueKey("summary_card"),
      width: 560,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, color: _isLocked ? _textDim : _accentColor, size: 56),
          const SizedBox(height: 24),
          const Text("SOUBORY NAHRÁNY", 
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
              // Po kliknutí na tyto volby se UI díky AbsorbPointeru zamkne a tlačítka zešednou
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
  //  KOMPONENTY (WIDGETY)
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
              color: _isDragging ? Colors.greenAccent : _accentColor.withOpacity(0.1 + (0.4 * glow)),
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
        side: BorderSide(color: _accentColor.withOpacity(_isLocked ? 0.1 : 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _choiceBtn(String label, VoidCallback onTap, {bool isCancel = false, bool isPrimary = false}) {
    return ElevatedButton(
      // KLÍČ: Pokud je onPressed null, Flutter tlačítko automaticky deaktivuje a zešedne
      onPressed: _isLocked ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? _accentColor : (isCancel ? Colors.transparent : Colors.white10),
        foregroundColor: Colors.white,
        elevation: 0,
        // Barva pro zešednutí (Disabled state)
        disabledBackgroundColor: Colors.white.withOpacity(0.02),
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
      color: Colors.black87,
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