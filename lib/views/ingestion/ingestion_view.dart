import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:async'; 

// Importy tvé logiky a UI
import 'package:mrb_obchodnik/logic/ingestion_service.dart';
import 'package:mrb_obchodnik/logic/notifications.dart'; 

class IngestionView extends StatefulWidget {
  const IngestionView({super.key});

  @override
  State<IngestionView> createState() => _IngestionViewState();
}

class _IngestionViewState extends State<IngestionView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final IngestionService _service = IngestionService();
  
  // Stav pro Drag & Drop
  bool _isDragging = false;
  
  // Notifier pro Progress Bar (univerzální pro Drag i Browse)
  final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);

  // --- DESIGN KONSTANTY (Flat & Technical) ---
  static const Color _bgDeep = Color(0xFF0F1115);
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _dragActiveColor = Colors.greenAccent;
  static const Color _borderColor = Color(0xFF2A2D35);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 3)
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  // ===========================================================================
  //  LOGIKA ZPRACOVÁNÍ (UI FEEDBACK LOOP)
  // ===========================================================================

  /// Univerzální metoda, která spustí vizuální progress a zavolá službu
  Future<void> _processWithUiFeedback(List<XFile> files) async {
    // 1. Reset a zobrazení Progress Baru
    _progressNotifier.value = 0.0;
    
    Notifications.showProgress(
      context, 
      progressNotifier: _progressNotifier,
      taskName: "ANALÝZA STRUKTURY", // Parametrizovaný text
      doneText: "HOTOVO"
    );

    // 2. Simulace "Práce" (UX Feel - aby to nevypadalo moc rychle/lacine)
    const int totalSteps = 15;
    for (int i = 0; i < totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 25));
      _progressNotifier.value = (i + 1) / totalSteps * 0.7; // Dojede do 70%
    }

    // 3. Skutečná logika na pozadí (Service)
    final result = await _service.processFiles(files);

    // 4. Dokončení na 100%
    _progressNotifier.value = 1.0;

    if (!mounted) return;

    // 5. Vyhodnocení výsledku
    if (result.totalCount > 0) {
      Notifications.finishProgress(
        context, 
        finalMessage: "NAČTENO ${result.totalCount} SOUBORŮ"
      );
    } else {
      // Pokud nic nenašel (např. jen .txt soubory), dáme Warning
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Notifications.showWarning(context, "ŽÁDNÁ PODPOROVANÁ DATA NENALEZENA");
    }
  }

  // --- HANDLERY UDÁLOSTÍ ---

  void _handleDragDone(DropDoneDetails details) async {
    setState(() => _isDragging = false);
    await _processWithUiFeedback(details.files);
  }

  void _handleBrowsePress() async {
    // 1. Otevřeme nativní okno (to blokuje vlákno, dokud uživatel nevybere)
    final result = await _service.pickFilesFromDisk(); 
    
    // 2. Pokud něco vybral, spustíme "Replay" progressu pro vizuální konzistenci
    if (result.totalCount > 0) {
       _progressNotifier.value = 0.0;
       
       Notifications.showProgress(
         context, 
         progressNotifier: _progressNotifier,
         taskName: "ZPRACOVÁNÍ VÝBĚRU"
       );
       
       // Rychlá animace (už máme data, jen ukazujeme, že je řadíme)
       for (int i = 0; i <= 10; i++) {
          await Future.delayed(const Duration(milliseconds: 30));
          _progressNotifier.value = i / 10.0;
       }
       
       if(!mounted) return;
       
       Notifications.finishProgress(
         context, 
         finalMessage: "NAČTENO ${result.totalCount} SOUBORŮ"
       );
    }
  }

  // ===========================================================================
  //  UI (VIEW)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      onDragDone: _handleDragDone,
      child: Container(
        color: _bgDeep,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDropCard(),
              const SizedBox(height: 40),
              _buildSupportedFormats(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropCard() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final Color borderColor = _isDragging 
            ? _dragActiveColor 
            : Color.lerp(_borderColor, _accentColor.withOpacity(0.5), _controller.value)!;
        
        final double borderWidth = _isDragging ? 2.5 : 1.5;

        return Container(
          width: 600,
          height: 340,
          decoration: BoxDecoration(
            color: _isDragging ? _bgCard.withOpacity(0.8) : _bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: _isDragging ? 1.0 : 0.5 + (0.5 * _controller.value),
                child: Icon(
                  _isDragging ? Icons.download_rounded : Icons.cloud_upload_outlined,
                  size: 64, 
                  color: _isDragging ? _dragActiveColor : _accentColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isDragging ? "PUSTIT SOUBORY" : "DROP ZONE",
                style: TextStyle(
                  color: _isDragging ? _dragActiveColor : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.5, fontFamily: 'sans-serif'),
                  children: const [
                    TextSpan(text: "Přetáhněte jednotlivé soubory nebo celé "),
                    TextSpan(text: "ARCHIVY (.zip)\n", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    TextSpan(text: "Systém obsah automaticky rozbalí a vytřídí."),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildFlatButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlatButton() {
    return InkWell(
      onTap: _handleBrowsePress,
      borderRadius: BorderRadius.circular(8),
      hoverColor: Colors.white.withOpacity(0.05),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _accentColor),
        ),
        child: const Text(
          "VYBRAT Z DISKU",
          style: TextStyle(color: _accentColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildSupportedFormats() {
    return Column(
      children: [
        Text(
          "POŽADOVANÉ VSTUPY & SMART UNPACK",
          style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _formatChip("DATA", ".xlsx", Colors.green),
            const SizedBox(width: 12),
            _formatChip("VÝKRESY", ".pdf", Colors.red),
            const SizedBox(width: 12),
            _formatChip("CAD", ".dxf / .step", Colors.blue),
            const SizedBox(width: 12),
            _formatChip("ARCHIV", ".zip", Colors.purpleAccent),
          ],
        ),
      ],
    );
  }

  Widget _formatChip(String label, String ext, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, color: c.withOpacity(0.8)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(ext, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }
}