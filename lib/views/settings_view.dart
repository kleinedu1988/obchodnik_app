import 'package:flutter/material.dart'; // Základní UI prvky
import 'dart:io'; // Práce se soubory v systému
import 'package:file_picker/file_picker.dart'; // Dialog pro výběr souboru (OpenDialog)

// --- PROPOJENÍ S TVOU LOGIKOU ---
import '../logic/db_service.dart'; // Skutečná SQLite služba
import '../logic/import_logic.dart'; // Skutečná logika importu s Progress Barem

class SettingsView extends StatefulWidget {
  const SettingsView({super.key}); // Konstruktor okna

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  
  // Tato funkce spustí celý proces: Výběr souboru -> Progress Bar -> Zápis do DB
  Future<void> _spustitImportProces(BuildContext context) async {
    // 1. Vyvolání standardního Windows okna pro výběr souboru
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'], // Povolíme jen Excel formáty
    );

    // 2. Pokud uživatel soubor vybral (nezavřel okno křížkem)
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!); // Cesta k souboru na disku
      
      // 3. ZAVOLÁNÍ REÁLNÉHO IMPORTU S PROGRESS BAREM
      // Tato funkce (v souboru import_logic.dart) sama otevře dialog s lištou
      await ImportLogic.spustitImport(context, file);
      
      // 4. Obnovení stavu obrazovky (překreslení barevné diagnostiky)
      setState(() {
        // Zde se jen vyvolá nové sestavení widgetu (build)
      }); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController( // Automatická správa záložek
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text( // Hlavní nadpis sekce
            "Nastavení systému",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const TabBar( // Lišta s přepínači záložek
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.blueAccent,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: "Stav databáze"),
              Tab(text: "Databáze zákazníků"),
              Tab(text: "Obecná nastavení"),
            ],
          ),
          const SizedBox(height: 20),
          Expanded( // Obsah vybrané záložky
            child: TabBarView(
              children: [
                _buildStavDatabaze(), // Diagnostika DB
                _buildZakaznici(),     // Tabulka zákazníků
                _buildObecne(),        // Ostatní volby
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. ZÁLOŽKA: STAV DATABÁZE (Diagnostika) ---
  Widget _buildStavDatabaze() {
    return FutureBuilder<Map<String, dynamic>?>(
      // Dotaz do skutečné SQLite databáze přes DbService
      future: DbService().getLastEntry(),
      builder: (context, snapshot) {
        
        // Pokud program právě sahá na disk pro data
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // VÝCHOZÍ STAV (ČERVENÁ - Prázdno/Chyba)
        Color stavBarva = Colors.red;
        String stavText = "Databáze je prázdná nebo poškozená";
        String posledniUpdate = "Žádná data k dispozici";
        IconData stavIkona = Icons.error_outline;
        bool tlacitkoAktualizovat = false;

        // POKUD V DB NAJDEME DATA
        if (snapshot.hasData && snapshot.data != null) {
          tlacitkoAktualizovat = true;
          String ts = snapshot.data!['timestamp'] ?? ""; // Časová značka z DB
          
          try {
            DateTime datumDb = DateTime.parse(ts); // Převod textu na datum
            int rozdilDni = DateTime.now().difference(datumDb).inDays; // Stáří dat

            if (rozdilDni > 7) {
              // STAV: ORANŽOVÁ (Data jsou starší než týden)
              stavBarva = Colors.orange;
              stavText = "Databáze je neaktuální (stáří $rozdilDni dní)";
              stavIkona = Icons.warning_amber_rounded;
            } else {
              // STAV: ZELENÁ (Data jsou čerstvá)
              stavBarva = Colors.green;
              stavText = "Databáze je aktuální";
              stavIkona = Icons.check_circle_outline;
            }
            posledniUpdate = ts.split('T')[0]; // Oříznutí času, ponechání jen data
          } catch (e) {
            posledniUpdate = "Chybný formát časové značky";
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Diagnostika a synchronizace", 
              style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // GRAFICKÁ KARTA STAVU
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: stavBarva.withOpacity(0.05), // Velmi jemné pozadí v barvě stavu
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: stavBarva.withOpacity(0.2), width: 2), // Barevný okraj
              ),
              child: Row(
                children: [
                  Icon(stavIkona, color: stavBarva, size: 50), // Velká ikona stavu
                  const SizedBox(width: 25),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stavText, 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: stavBarva)),
                      const SizedBox(height: 5),
                      Text("Poslední úspěšný import: $posledniUpdate", 
                        style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // TLAČÍTKO PRO SPUŠTĚNÍ IMPORTU
            SizedBox(
              width: 320,
              height: 55,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.rocket_launch_rounded),
                label: Text(tlacitkoAktualizovat ? "Aktualizovat databázi zákazníků" : "Importovat výchozí data z Excelu"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: stavBarva == Colors.red ? Colors.blueAccent : Colors.white10,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                // ZDE SPOUŠTÍME NAŠI FUNKCI S PROGRESS BAREM
                onPressed: () => _spustitImportProces(context),
              ),
            ),
            const SizedBox(height: 15),
            const Text("Doporučený formát: Sloupce [A] ID, [B] Název, [C] IČ.",
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        );
      },
    );
  }

  // --- 2. ZÁLOŽKA: DATABÁZE ZÁKAZNÍKŮ ---
  Widget _buildZakaznici() {
    return const Center(child: Text("Zde bude tabulka s bleskovým vyhledáváním v 15 000 záznamech."));
  }

  // --- 3. ZÁLOŽKA: OBECNÁ NASTAVENÍ ---
  Widget _buildObecne() {
    return const Center(child: Text("Obecná nastavení aplikace (Cesty, vzhled)."));
  }
}