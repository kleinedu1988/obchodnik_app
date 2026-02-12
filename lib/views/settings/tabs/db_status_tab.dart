import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart'; // Pro formátování datumu
import 'package:shared_preferences/shared_preferences.dart'; // Přidáno pro načítání intervalu
import '../../../logic/db_service.dart';
import '../../../logic/import_logic.dart';
import '../settings_helpers.dart';

class DbStatusTab extends StatefulWidget {
  const DbStatusTab({super.key});

  @override
  State<DbStatusTab> createState() => _DbStatusTabState();
}

class _DbStatusTabState extends State<DbStatusTab> {
  // Definice barev 2026 systému
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Colors.orangeAccent;

  // Budeme si držet budoucí data v proměnné
  // Index 0: LastEntry (Map), Index 1: RowCount (int), Index 2: SharedPreferences
  late Future<List<dynamic>> _dbData;

  @override
  void initState() {
    super.initState();
    _nactiData(); // Prvotní načtení při otevření tabu
  }

  /// Metoda pro (znovu)načtení dat z databáze a preferencí
  void _nactiData() {
    setState(() {
      _dbData = Future.wait([
        DbService().getLastEntry(),
        DbService().getRowCount(),
        SharedPreferences.getInstance(),
      ]);
    });
  }

  /// Převede ISO string (2026-02-12T...) na lidské datum (12.02.2026 21:15)
  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return "Žádná data";
    try {
      DateTime dt = DateTime.parse(isoDate);
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (e) {
      return isoDate; // Fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _dbData,
      builder: (context, snapshot) {
        // Diagnostika do konzole
        if (snapshot.hasData) {
          debugPrint("STAV TABU: Záznamů=${snapshot.data![1]}, Poslední=${snapshot.data![0]?['timestamp']}");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
          );
        }

        // 1. Získání dat z Future
        final lastEntry = snapshot.data?[0] as Map<String, dynamic>?;
        final rowCount = (snapshot.data?[1] as int?) ?? 0;
        final prefs = snapshot.data?[2] as SharedPreferences;
        
        // 2. Načtení intervalu nastavení
        final interval = prefs.getString('sync_interval') ?? '1 měsíc';
        final lastImportIso = lastEntry?['timestamp'] as String?;

        // 3. Výpočet stáří dat (Logika z tvého zadání)
        bool isOutdated = false;
        if (lastImportIso != null) {
          DateTime lastImport = DateTime.parse(lastImportIso);
          DateTime now = DateTime.now();
          Duration diff = now.difference(lastImport);

          switch (interval) {
            case 'teď': isOutdated = diff.inSeconds > 10; break;
            case '1 týden': isOutdated = diff.inDays > 7; break;
            case '2 týdny': isOutdated = diff.inDays > 14; break;
            case '1 měsíc': isOutdated = diff.inDays > 30; break;
          }
        }

        // LOGIKA TŘÍ STAVŮ (Semafor) + ZASTARALÁ DATA
        Color stavBarva;
        String stavText;
        String stavPodpis;
        IconData stavIkona;

        if (rowCount == 0) {
          // 1. Priorita: Prázdná DB
          stavBarva = _red;
          stavText = "KRITICKÝ STAV";
          stavPodpis = "DATABÁZE JE PRÁZDNÁ, NUTNÝ IMPORT";
          stavIkona = Icons.error_outline_rounded;
        } else if (isOutdated) {
          // 2. Priorita: Zastaralá data (podle nastavení)
          stavBarva = _orange;
          stavText = "DATA JSOU ZASTARALÁ";
          stavPodpis = "INTERVAL $interval BYL PŘEKROČEN";
          stavIkona = Icons.access_time_filled_rounded;
        } else if (rowCount < 100) {
          // 3. Priorita: Málo dat
          stavBarva = _amber;
          stavText = "OMEZENÝ PROVOZ";
          stavPodpis = "NÍZKÝ POČET ZÁZNAMŮ V SYSTÉMU";
          stavIkona = Icons.warning_amber_rounded;
        } else {
          // 4. Vše OK
          stavBarva = _emerald;
          stavText = "SYSTÉM AKTIVNÍ";
          stavPodpis = "DATABÁZE JE AKTUÁLNÍ A SYNCHRONIZOVÁNA";
          stavIkona = Icons.check_circle_outline_rounded;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 24, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HLAVNÍ STATUS CARD
              _buildMainStatusCard(stavText, stavPodpis, stavIkona, stavBarva),

              const SizedBox(height: 32),

              // 2. TECHNICKÁ SPECIFIKACE
              SettingsHelpers.headerText("Technická specifikace"),
              SettingsHelpers.buildGlassPanel(
                child: Column(
                  children: [
                    SettingsHelpers.buildDataRow(
                      "Celkový počet klientů", 
                      rowCount.toString(),
                    ),
                    SettingsHelpers.buildDataRow(
                      "Poslední aktualizace", 
                      _formatDate(lastImportIso),
                    ),
                    SettingsHelpers.buildDataRow(
                      "Nastavený interval", 
                      interval, // Zobrazíme i nastavený interval
                    ),
                    SettingsHelpers.buildDataRow(
                      "Lokalita souboru", 
                      "mrb_obchodnik.db", 
                      isLast: true
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 3. SPRÁVA DAT (Import)
              SettingsHelpers.headerText("Akce"),
              _buildImportAction(context),
            ],
          ),
        );
      },
    );
  }

  // --- UI KOMPONENTY ---

  Widget _buildMainStatusCard(String text, String subtext, IconData icon, Color color) {
    return SettingsHelpers.buildGlassPanel(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtext,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportAction(BuildContext context) {
    return SettingsHelpers.buildGlassPanel(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03), 
              borderRadius: BorderRadius.circular(8)
            ),
            child: const Icon(Icons.refresh_rounded, color: Colors.white24, size: 20),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Synchronizace databáze", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text("Nahrajte Excel (.xlsx) pro aktualizaci klientské základny", style: TextStyle(fontSize: 11, color: Colors.white24)),
              ],
            ),
          ),
          Material(
            color: _accentColor,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: () => _handleImport(context),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  "IMPORT EXCEL",
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Spustí import a po jeho dokončení aktualizuje UI
  Future<void> _handleImport(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['xlsx', 'xls'], 
      type: FileType.custom
    );
    
    if (result != null) {
      // 1. Spustíme proces importu
      await ImportLogic.spustitImport(context, File(result.files.single.path!));
      
      // 2. Počkáme chvíli na zapsání do DB a refreshneme lokální Future proměnnou
      if (mounted) {
        _nactiData(); 
      }
    }
  }
}