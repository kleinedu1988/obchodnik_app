import 'package:flutter/material.dart';

class SettingsHelpers {
  // Barvy sjednocené s tvým 2026 "Charcoal & Glass" systémem
  static const Color surfaceColor = Color(0xFF161616); // Mírně světlejší než pozadí
  static const Color accentColor = Color(0xFF4077D1);
  static const Color glassBorder = Color(0x14FFFFFF); // Tvá 8% bílá

  /// Vytvoří skleněný panel s vysokou hustotou dat
  static Widget buildGlassPanel({
    required Widget child,
    bool radiusTop = true,
    bool radiusBottom = true,
    EdgeInsets? padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        // Hybrid Glass: Mírně průhledné pozadí pro hloubku
        color: surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(radiusTop ? 10 : 0),
          bottom: Radius.circular(radiusBottom ? 10 : 0),
        ),
        border: Border.all(color: glassBorder, width: 0.8),
      ),
      child: child,
    );
  }

  /// Nadpis sekce v "Engineering" stylu (kapitálky, proklad)
  static Widget headerText(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.2),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  /// Pomocný widget pro řádek s daty (Klíč -> Hodnota)
  /// Inspirováno tvou React tabulkou
  static Widget buildDataRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(
          bottom: BorderSide(color: glassBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'JetBrainsMono', // Nebo monospace pro tech look
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}