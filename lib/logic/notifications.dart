import 'dart:ui';
import 'package:flutter/material.dart';

class Notifications {
  // Globální reference pro ovládání
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _activeController;

  // --- PALETA BAREV ---
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _successColor = Color(0xFF10B981); // Emerald
  static const Color _errorColor = Color(0xFFEF4444);   // Red
  static const Color _warningColor = Color(0xFFF59E0B); // Amber
  
  static final Color _glassBase = const Color(0xFF1A1A1A).withOpacity(0.85);
  
  // ===========================================================================
  // 1. UNIVERZÁLNÍ TOAST (Jednorázová zpráva)
  // ===========================================================================
  static void showToast(BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_outline_rounded,
    Color color = _accentColor,
    int durationMillis = 2500,
  }) {
    // Zavřeme předchozí, aby se nehromadily
    ScaffoldMessenger.of(context).clearSnackBars();

    final snackBar = SnackBar(
      duration: Duration(milliseconds: durationMillis),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 420, // Konzistentní šířka pro desktop
      padding: EdgeInsets.zero,
      content: _FlatGlassWrapper(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 12),
            Text(message.toUpperCase(), style: _textStyle(0.9)),
          ],
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Předpřipravené varianty pro rychlé použití
  static void showSuccess(BuildContext context, String msg) => 
      showToast(context, message: msg, icon: Icons.check_rounded, color: _successColor);
      
  static void showError(BuildContext context, String msg) => 
      showToast(context, message: msg, icon: Icons.error_outline_rounded, color: _errorColor, durationMillis: 4000);

  static void showWarning(BuildContext context, String msg) => 
      showToast(context, message: msg, icon: Icons.warning_amber_rounded, color: _warningColor);


  // ===========================================================================
  // 2. UNIVERZÁLNÍ PROGRESS BAR (Dlouhotrvající akce)
  // ===========================================================================
  static void showProgress(BuildContext context, {
    required ValueNotifier<double> progressNotifier,
    required String taskName, // Např. "ANALÝZA DAT"
    String doneText = "HOTOVO",
  }) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    
    _activeController = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(days: 1), // "Nekonečné" trvání
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        width: 420,
        padding: EdgeInsets.zero,
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, child) {
            final int percent = (progress * 100).clamp(0, 100).round();
            final bool isDone = progress >= 1.0;
            
            // Barva se mění z Modré (běží) na Zelenou (hotovo)
            final Color currentColor = isDone ? _successColor : _accentColor;

            return _FlatGlassWrapper(
              progressBarValue: progress,
              progressBarColor: currentColor,
              child: Row(
                children: [
                  // Ikonka nebo Spinner
                  if (!isDone)
                    SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_accentColor)),
                    )
                  else
                    Icon(Icons.check_rounded, color: _successColor, size: 16),
                  
                  const SizedBox(width: 15),
                  
                  // Text: "ANALÝZA DAT..." nebo "HOTOVO"
                  Text(
                    isDone ? "$doneText " : "$taskName... ", 
                    style: _textStyle(0.7)
                  ),
                  
                  const Spacer(),
                  
                  // Procenta
                  Text(
                    "$percent%", 
                    style: _textStyle(1.0).copyWith(fontWeight: FontWeight.w900, fontFamily: 'monospace')
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Ukončovací sekvence (zavře progress -> ukáže toast)
  static void finishProgress(BuildContext context, {required String finalMessage}) {
    // Malá pauza, aby uživatel stihl zaregistrovat 100% stav
    Future.delayed(const Duration(milliseconds: 600), () {
      _activeController?.close();
      showSuccess(context, finalMessage);
    });
  }

  // --- PRIVÁTNÍ STYLY ---
  static TextStyle _textStyle(double opacity) {
    return TextStyle(
      color: Colors.white.withOpacity(opacity), 
      fontSize: 11, 
      fontWeight: FontWeight.w600, 
      letterSpacing: 1.1
    );
  }
}

// --- PRIVÁTNÍ DESIGN WRAPPER (GLASSMORPHISM) ---
class _FlatGlassWrapper extends StatelessWidget {
  final Widget child;
  final double? progressBarValue;
  final Color? progressBarColor;

  const _FlatGlassWrapper({required this.child, this.progressBarValue, this.progressBarColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Notifications._glassBase,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
            ],
          ),
          child: Stack(
            children: [
              // Obsah zarovnaný na střed
              Align(alignment: Alignment.center, child: child),
              
              // Progress bar na dně
              if (progressBarValue != null)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: LinearProgressIndicator(
                    value: progressBarValue,
                    backgroundColor: Colors.transparent,
                    color: progressBarColor,
                    minHeight: 2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}