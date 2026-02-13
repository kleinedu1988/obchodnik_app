import 'package:flutter/material.dart';
// Pokud chceš vidět starou tabulku, odkomentuj import a řádek dole
// import '../settings/tabs/customer_list_tab.dart'; 

class OrderEditorView extends StatelessWidget {
  const OrderEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    // return const CustomerListTab(); // <--- Pokud chceš zatím vidět stará data
    
    return Container(
      color: const Color(0xFF0F1115),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.white.withOpacity(0.05)),
            const SizedBox(height: 16),
            Text(
              "VÝROBNÍ OBJEDNÁVKY",
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}