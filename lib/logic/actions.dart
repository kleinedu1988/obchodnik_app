import 'dart:ui';
import 'package:flutter/material.dart';

void zpracujKliknuti(BuildContext context, String nazevPolozky) {
  print("Logika: Uživatel klikl na $nazevPolozky");

  final snackBar = SnackBar(
    duration: const Duration(milliseconds: 900),
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    margin: const EdgeInsets.only(
      bottom: 20,
      left: 20,
      right: 20,
    ),
    content: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF151515).withOpacity(0.82),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Colors.blueAccent.withOpacity(0.9),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Aktivována sekce: $nazevPolozky",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
