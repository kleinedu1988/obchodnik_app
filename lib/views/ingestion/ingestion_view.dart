import 'package:flutter/material.dart';

class IngestionView extends StatelessWidget {
  const IngestionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F1115), // Deep dark background
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.move_to_inbox_rounded, size: 64, color: Colors.white.withOpacity(0.05)),
            const SizedBox(height: 16),
            Text(
              "DROP ZONE",
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            Text(
              "Zde přetáhněte soubory k importu",
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}