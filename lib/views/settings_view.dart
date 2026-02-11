import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../logic/db_service.dart';
import '../logic/import_logic.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  
  Future<void> _spustitImportProces(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      await ImportLogic.spustitImport(context, file);
      setState(() {}); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController( 
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text( 
            "Nastavení systému",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const TabBar( 
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
          const SizedBox(height: 30), // Větší mezera pod menu
          Expanded( 
            child: TabBarView(
              children: [
                _buildStavDatabaze(), 
                _buildZakaznici(),     
                _buildObecne(),        
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStavDatabaze() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        DbService().getLastEntry(),
        DbService().getRowCount(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final lastEntry = snapshot.data?[0] as Map<String, dynamic>?;
        final rowCount = snapshot.data?[1] as int? ?? 0;

        // LOGIKA BAREV A TEXTŮ (Tvá původní)
        Color stavBarva = Colors.red;
        String stavNadpis = "Databáze je prázdná";
        String stavPopis = "V systému nejsou žádná data. Proveďte první import.";
        IconData stavIkona = Icons.storage_rounded;

        if (rowCount > 0 && lastEntry != null) {
          String ts = lastEntry['timestamp'] ?? "";
          DateTime datumDb = DateTime.parse(ts);
          int rozdilDni = DateTime.now().difference(datumDb).inDays;

          if (rozdilDni > 7) {
            stavBarva = Colors.orange;
            stavNadpis = "Data jsou neaktuální";
            stavPopis = "Databáze obsahuje $rowCount záznamů (stáří $rozdilDni dní).";
            stavIkona = Icons.history_rounded;
          } else {
            stavBarva = Colors.green;
            stavNadpis = "Systém je v pořádku";
            stavPopis = "V databázi je připraveno $rowCount záznamů k práci.";
            stavIkona = Icons.check_circle_outline;
          }
        }

        // --- NOVÝ DESIGN STATUS KARTY ---
        return SingleChildScrollView( // Ochrana proti přetečení na malých oknech
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A), // Tmavší šedá pro kartu
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: stavBarva.withOpacity(0.3)), // Barevný okraj
                ),
                child: Column(
                  children: [
                    // HORNÍ ČÁST S TEXTEM
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Icon(stavIkona, color: stavBarva, size: 40),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stavNadpis, 
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: stavBarva)),
                                const SizedBox(height: 4),
                                Text(stavPopis, 
                                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // ODDĚLOVAČ
                    Divider(color: stavBarva.withOpacity(0.1), height: 1),

                    // SPODNÍ ČÁST S TLAČÍTKEM
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Zdroj: Excel (.xlsx)", style: TextStyle(color: Colors.white24, fontSize: 12)),
                          ElevatedButton.icon(
                            onPressed: () => _spustitImportProces(context),
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text("AKTUALIZOVAT DATA"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: stavBarva,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZakaznici() {
    return const Center(child: Text("Sekce zákazníků"));
  }

  Widget _buildObecne() {
    return const Center(child: Text("Obecná nastavení"));
  }
}