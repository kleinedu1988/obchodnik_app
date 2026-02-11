import 'package:flutter/material.dart'; // Importujeme nástroje pro práci s UI (např. barvy, zprávy)

// Funkce, která se spustí při kliknutí na menu
// BuildContext 'context' je jako adresa - říká Flutteru, kde přesně v aplikaci se nacházíme
void zpracujKliknuti(BuildContext context, String nazevPolozky) {
  
  // Vypíše název do debug konzole ve VS Code (neviditelné pro uživatele)
  print("Logika: Uživatel klikl na $nazevPolozky");

  // ScaffoldMessenger najde nejbližší Scaffold (kostru okna) a zobrazí v něm zprávu
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      // Obsah zprávy - text s názvem položky
      content: Text("Aktivována sekce: $nazevPolozky"),
      
      // Jak dlouho má bublina strašit na obrazovce
      duration: const Duration(milliseconds: 800),
      
      // Udělá bublinu kulatou a "plovoucí" (vypadá to moderněji)
      behavior: SnackBarBehavior.floating, 
      
      // Zaoblení rohů samotné bubliny
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), 
    ),
  );
}