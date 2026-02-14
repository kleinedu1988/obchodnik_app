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
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _borderColor = Color(0xFF2A2D35);

  late Future<List<dynamic>> _dbData;

  @override
  void initState() {
    super.initState();
    _nactiData(); 
  }

  void _nactiData() {
    setState(() {
      _dbData = Future.wait([
        DbService().getLastEntry(),
        DbService().getRowCount(),
        SharedPreferences.getInstance(),
      ]);
    });
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return "Nikdy";
    try {
      DateTime dt = DateTime.parse(isoDate);
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _dbData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor));
        }

        // 1. Získání dat
        final lastEntry = snapshot.data?[0] as Map<String, dynamic>?;
        final rowCount = (snapshot.data?[1] as int?) ?? 0;
        final prefs = snapshot.data?[2] as SharedPreferences;
        
        // 2. Interval
        final interval = prefs.getString('sync_interval') ?? '1 měsíc';
        final lastImportIso = lastEntry?['timestamp'] as String?;

        // 3. Logika stavu
        bool isOutdated = false;
        if (lastImportIso != null) {
          DateTime lastImport = DateTime.parse(lastImportIso);
          DateTime now = DateTime.now();
          Duration diff = now.difference(lastImport);

          switch (interval) {
            case 'teď': isOutdated = diff.inSeconds > 10; break; // Pro testování
            case '1 týden': isOutdated = diff.inDays > 7; break;
            case '2 týdny': isOutdated = diff.inDays > 14; break;
            case '1 měsíc': isOutdated = diff.inDays > 30; break;
          }
        }

        // 4. Určení barev a ikon
        Color stavBarva;
        String stavText;
        String stavPodpis;
        IconData stavIkona;

        if (rowCount == 0) {
          stavBarva = _red;
          stavText = "KRITICKÝ STAV";
          stavPodpis = "DATABÁZE JE PRÁZDNÁ";
          stavIkona = Icons.error_outline_rounded;
        } else if (isOutdated) {
          stavBarva = _orange;
          stavText = "DATA JSOU ZASTARALÁ";
          stavPodpis = "INTERVAL AKTUALIZACE PŘEKROČEN";
          stavIkona = Icons.access_time_filled_rounded;
        } else if (rowCount < 50) {
          stavBarva = _amber;
          stavText = "OMEZENÝ PROVOZ";
          stavPodpis = "MÁLO DAT PRO ANALÝZU";
          stavIkona = Icons.warning_amber_rounded;
        } else {
          stavBarva = _emerald;
          stavText = "SYSTÉM AKTIVNÍ";
          stavPodpis = "DATABÁZE JE AKTUÁLNÍ";
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
              _headerText("TECHNICKÁ SPECIFIKACE"),
              const SizedBox(height: 12),
              _buildInfoPanel([
                _buildDataRow("Celkový počet klientů", rowCount.toString()),
                _buildDataRow("Poslední aktualizace", _formatDate(lastImportIso)),
                _buildDataRow("Nastavený interval", interval),
                _buildDataRow("Databázový engine", "SQLite 3.40 (FFI)", isLast: true),
              ]),

              const SizedBox(height: 32),

              // 3. AKCE
              _headerText("SPRÁVA DAT"),
              const SizedBox(height: 12),
              _buildImportAction(context),
            ],
          ),
        );
      },
    );
  }

  // --- UI KOMPONENTY (Lokální, aby nechyběl SettingsHelpers) ---

  Widget _buildMainStatusCard(String text, String subtext, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 20, spreadRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
                const SizedBox(height: 4),
                Text(
                  subtext,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDataRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildImportAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.sync_rounded, color: Colors.white24, size: 20),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Synchronizace databáze", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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

  Widget _headerText(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
    );
  }

  // --- LOGIKA IMPORTU ---

  Future<void> _handleImport(BuildContext context) async {
    // 1. Otevřít výběr souboru
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['xlsx', 'xls'], 
      type: FileType.custom,
      lockParentWindow: true,
    );
    
    if (result != null && result.files.single.path != null) {
      // 2. Zavolat logiku (Notifikace řeší ImportLogic uvnitř)
      await ImportLogic.importCustomers(context, File(result.files.single.path!));
      
      // 3. Po dokončení obnovit statistiky v tomto okně
      if (mounted) {
        _nactiData(); 
      }
    }
  }
}