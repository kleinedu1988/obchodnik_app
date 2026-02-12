import 'dart:ui';
import 'package:flutter/material.dart';

/// Globální reference pro ovládání aktivního importního proužku
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _aktivniImportController;

// --- KONSTANTY PRO JEDNOTNÝ DESIGN 2026 ---
const Color _accentColor = Color(0xFF4077D1);
const Color _emerald = Color(0xFF10B981);
final Color _glassBase = const Color(0xFF1A1A1A).withOpacity(0.65);
final Color _glassEnd = const Color(0xFF0D0D0D).withOpacity(0.80);

/// 1. STANDARDNÍ ÚSPĚCH: Ultra-nízký skleněný proužek pro potvrzení akcí.
void zpracujKliknuti(BuildContext context, String nazevPolozky) {
  ScaffoldMessenger.of(context).clearSnackBars();

  final snackBar = SnackBar(
    duration: const Duration(milliseconds: 1800),
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    content: _FlatGlassWrapper(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_rounded, color: _accentColor, size: 14),
          const SizedBox(width: 12),
          Text(
            "SEKCE ${nazevPolozky.toUpperCase()} AKTIVOVÁNA",
            style: _textStyle(0.7),
          ),
        ],
      ),
    ),
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

/// 2. IMPORT PROGRESS: Proužek, který zůstává viset a barví svou spodní hranu.
void zobrazImportProgress(BuildContext context, ValueNotifier<double> progressNotifier) {
  // Odstraníme jakýkoliv předchozí snackbar, aby se nepřekrývaly
  ScaffoldMessenger.of(context).removeCurrentSnackBar();

  _aktivniImportController = ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(days: 1), // "Nekonečné" trvání, dokud import neběží
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      content: ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, progress, child) {
          final int procenta = (progress * 100).round();
          final bool hotovo = progress >= 1.0;

          return _FlatGlassWrapper(
            // Progress bar jako spodní hrana
            progressBarValue: progress,
            progressBarColor: hotovo ? _emerald : _accentColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Minimalistický točící se indikátor
                if (!hotovo)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                    ),
                  )
                else
                  const Icon(Icons.check_rounded, color: _emerald, size: 14),
                const SizedBox(width: 15),
                Text(
                  hotovo ? "IMPORT DOKONČEN " : "IMPORTUJI DATA... ",
                  style: _textStyle(0.5),
                ),
                Text(
                  "$procenta %",
                  style: _textStyle(1.0).copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// 3. UKONČENÍ IMPORTU: Zavře progress a ukáže finální zelený úspěch.
void ukonciImport(BuildContext context, String text) {
  _aktivniImportController?.close();
  zpracujKliknuti(context, text);
}

// --- PRIVÁTNÍ DESIGN ELEMENTY ---

/// Společný "Flat-Glass" obal pro obě notifikace
class _FlatGlassWrapper extends StatelessWidget {
  final Widget child;
  final double? progressBarValue;
  final Color? progressBarColor;

  const _FlatGlassWrapper({
    required this.child,
    this.progressBarValue,
    this.progressBarColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [_glassBase, _glassEnd],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.5,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              // PROGRESS BAR JAKO SPODNÍ HRANA
              if (progressBarValue != null)
                Positioned(
                  bottom: -6, // Zarovnání na úplné dno containeru
                  left: -20,  // Kompenzace horizontálního paddingu
                  right: -20,
                  child: SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(
                      value: progressBarValue,
                      backgroundColor: Colors.transparent,
                      color: progressBarColor?.withOpacity(0.8),
                      minHeight: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _textStyle(double opacity) {
  return TextStyle(
    color: Colors.white.withOpacity(opacity),
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
  );
}