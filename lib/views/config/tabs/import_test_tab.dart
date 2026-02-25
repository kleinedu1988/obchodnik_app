import 'package:flutter/material.dart';

class ImportTestTab extends StatelessWidget {
  const ImportTestTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.05),
          ),
          const SizedBox(height: 24),
          Text(
            "TEST IMPORTU",
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Přetáhněte testovací Excel soubor pro ověření\nrozpoznávání sloupců s aktivním profilem.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.15),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}