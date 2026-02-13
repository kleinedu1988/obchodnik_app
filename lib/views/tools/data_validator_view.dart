import 'package:flutter/material.dart';

class DataValidatorView extends StatelessWidget {
  const DataValidatorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F1115),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule_folder_outlined, size: 64, color: Colors.white.withOpacity(0.05)),
            const SizedBox(height: 16),
            Text(
              "VALIDATOR DAT",
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}