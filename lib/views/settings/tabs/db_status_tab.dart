import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart'; // Pro formátování datumu
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

  // Budeme si držet budoucí data v proměnné, aby FutureBuilder
  // nespouštěl dotaz do DB při každém pohybu myši nebo animaci.
  late Future<List<dynamic>> _dbData;

  @override
  void initState() {
    super.initState();
    _nactiData(); // Prvotní načtení při otevření tabu
  }

  /// Metoda pro (znovu)načtení dat z databáze
  void _nactiData() {
    setState(() {
      _dbData = Future.wait([
        DbService().getLastEntry(),
        DbService().getRowCount(),
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
        // Diagnostika do konzole - teď už by se měla objevit jen při změně stavu
        if (snapshot.hasData) {
          debugPrint("STAV TABU: Záznamů=${snapshot.data![1]}, Poslední=${snapshot.data![0]?['timestamp']}");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
          );
        }

        final lastEntry = snapshot.data?[0] as Map<String, dynamic>?;
        final rowCount = (snapshot.data?[1] as int?) ?? 0;

        // LOGIKA TŘÍ STAVŮ (Semafor)
        Color stavBarva = _red;
        String stavText = "KRITICKÝ STAV";
        String stavPodpis = "DATABÁZE JE PRÁZDNÁ, NUTNÝ IMPORT";
        IconData stavIkona = Icons.error_outline_rounded;

        if (rowCount > 0 && rowCount < 100) {
          stavBarva = _amber;
          stavText = "OMEZENÝ PROVOZ";
          stavPodpis = "NÍZKÝ POČET ZÁZNAMŮ V SYSTÉMU";
          stavIkona = Icons.warning_amber_rounded;
        } else if (rowCount >= 100) {
          stavBarva = _emerald;
          stavText = "SYSTÉM AKTIVNÍ";
          stavPodpis = "DATABÁZE JE PŘIPOJENA A SYNCHRONIZOVÁNA";
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
                      _formatDate(lastEntry?['timestamp']),
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