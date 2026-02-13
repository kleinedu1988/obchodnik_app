import 'package:flutter/material.dart';

class AttachmentMatchingView extends StatelessWidget {
  const AttachmentMatchingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F1115),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_rounded, size: 64, color: Colors.white.withOpacity(0.05)),
            const SizedBox(height: 16),
            Text(
              "PÁROVÁNÍ PŘÍLOH",
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}