import 'package:flutter/material.dart'; // Základní UI knihovna Flutteru
// Poznámka: Importy níže jsou v tomto ukázkovém kódu zakomentovány, 
// aby byl kód spustitelný i bez externích souborů.
import 'package:mrb_obchodnik/logic/actions.dart';
import 'views/settings_view.dart';

void main() {
  runApp(const MyApp()); // Spuštění celé aplikace
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Základní obal aplikace (kořenový widget)

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Schováme červený "debug" proužek v rohu
      theme: ThemeData.dark().copyWith( // Nastavení tmavého režimu
        scaffoldBackgroundColor: const Color(0xFF0F0F0F), // Velmi tmavé pozadí hlavní plochy
      ),
      home: const MainScreen(), // Nastavení výchozí obrazovky
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key}); // Hlavní obrazovka se stavem

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Proměnná držící číslo aktuálně otevřené stránky

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // --- LEVÝ PANEL (SIDEBAR) ---
          Container(
            width: 250, // Pevně daná šířka sidebaru
            color: const Color(0xFF161616), // Tmavší barva pozadí pro panel
            child: Column(
              children: [
                const SizedBox(height: 50), // Mezera nahoře
                _buildMenuItem(0, Icons.dashboard_rounded, "Nástěnka"),
                _buildMenuItem(1, Icons.file_download_rounded, "Import dat"),
                _buildMenuItem(2, Icons.analytics_rounded, "Analýza"),
                const Spacer(), // Vyplní prostor a odtlačí nastavení dolů
                _buildMenuItem(3, Icons.settings_rounded, "Nastavení"),
                const SizedBox(height: 20), // Spodní odsazení
              ],
            ),
          ),
          
          // --- PRAVÝ KONTEJNER (DYNAMICKÝ OBSAH) ---
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(40),
              child: _getPageView(_selectedIndex),
            ),
          ),
        ],
      ),
    );
  }

  // IMPLEMENTOVANÁ FUNKCE: Vytváří tlačítko v menu se správným zvýrazněním (Hover)
  Widget _buildMenuItem(int index, IconData icon, String title) {
    bool isSelected = _selectedIndex == index; // Je toto tlačítko vybrané?

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), // Mezery kolem tlačítka
      child: Material( // Material widget je NUTNÝ pro správné zobrazení Hover barvy
        color: Colors.transparent, // Pozadí Materialu musí být průhledné
        child: InkWell( // InkWell zajišťuje interaktivitu a vizuální odezvu
          onTap: () {
            setState(() => _selectedIndex = index); // Změna stavu okna
            zpracujKliknuti(context, title); // Volání logiky
          },
          borderRadius: BorderRadius.circular(10), // Zakulacení rohů při najetí myší
          hoverColor: Colors.white.withOpacity(0.05), // Jemné prosvětlení při najetí myši
          splashColor: Colors.blueAccent.withOpacity(0.1), // Efekt při kliknutí
          
          child: Container( // Vnitřní vzhled tlačítka
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              // Pokud je vybráno, dostane modrý nádech, jinak zůstane průhledné
              color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Ikona mění barvu podle výběru
                Icon(
                  icon, 
                  color: isSelected ? Colors.blueAccent : Colors.grey, 
                  size: 22
                ),
                const SizedBox(width: 15), // Mezera mezi ikonou a textem
                // Text mění barvu a tučnost
                Text(
                  title, 
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Funkce, která vrací správný soubor (View) podle zvoleného menu
  Widget _getPageView(int index) {
    switch (index) {
      case 0:
        return const Center(child: Text("Zde bude soubor: home_view.dart", style: TextStyle(color: Colors.grey)));
      case 1:
        return const Center(child: Text("Zde bude soubor: import_view.dart", style: TextStyle(color: Colors.grey)));
      case 2:
        return const Center(child: Text("Sekce Analýza", style: TextStyle(color: Colors.grey)));
      case 3:
        return const SettingsView(); // Volání nastavení
      default:
        return const Center(child: Text("Stránka nenalezena"));
    }
  }
}