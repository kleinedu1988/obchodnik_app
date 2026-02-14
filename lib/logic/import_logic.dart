import 'dart:io';
import 'package:excel/excel.dart'; // Ujisti se, že máš v pubspec.yaml: excel: ^4.0.0 (nebo novější)
import 'package:flutter/foundation.dart'; // Pro compute
import 'package:flutter/material.dart';

import 'package:mrb_obchodnik/logic/db_service.dart'; // Cesta k tvé DB službě
import 'package:mrb_obchodnik/logic/notifications.dart'; // Cesta k tvým notifikacím

class ImportLogic {
  
  static Future<void> importCustomers(BuildContext context, File file) async {
    final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);

    // 1. Spustíme UI Notifikaci
    Notifications.showProgress(
      context, 
      progressNotifier: progressNotifier,  
      taskName: "IMPORT OBCHODNÍCH PARTNERŮ",
      doneText: "ZPRACOVÁNÍ DOKONČENO"
    );

    try {
      // FÁZE 1: Čtení souboru a Parsování (0% -> 30%)
      progressNotifier.value = 0.05;
      final bytes = await file.readAsBytes();

      debugPrint("ImportLogic: Spouštím Isolate pro parsování...");
      
      // Běží na pozadí
      final List<Map<String, dynamic>> dataToInsert = await compute(_parseExcelIsolate, bytes);

      if (dataToInsert.isEmpty) {
        throw "Soubor neobsahuje žádná platná data.";
      }
      
      // Jsme připraveni k zápisu, posuneme progress na 30%
      progressNotifier.value = 0.30;
      debugPrint("ImportLogic: Připraveno ${dataToInsert.length} záznamů. Volám DB.");

      // FÁZE 2: Batch Insert do DB (30% -> 100%)
      // Využíváme tvou metodu importZakazniku s callbackem
      await DbService().importZakazniku(dataToInsert, (dbProgress) {
        // Přepočet: dbProgress (0.0 až 1.0) mapujeme na (0.3 až 1.0) v UI
        final totalProgress = 0.30 + (dbProgress * 0.70);
        progressNotifier.value = totalProgress;
      });

      // FÁZE 3: Hotovo
      if (context.mounted) {
        Notifications.finishProgress(
          context, 
          finalMessage: "IMPORTOVÁNO ${dataToInsert.length} PARTNERŮ"
        );
      }
      
    } catch (e) {
      debugPrint("CHYBA IMPORTU: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        Notifications.showError(context, "IMPORT SELHAL: $e");
      }
    } finally {
      // Úklid
      await Future.delayed(const Duration(milliseconds: 500));
      progressNotifier.dispose();
    }
  }
}

// =============================================================================
//  ISOLATE FUNKCE (Mimo třídu)
// =============================================================================

List<Map<String, dynamic>> _parseExcelIsolate(List<int> bytes) {
  var excel = Excel.decodeBytes(bytes);
  final List<Map<String, dynamic>> outputList = [];
  
  // Datum importu pro sloupec 'timestamp' v DB
  final String nowIso = DateTime.now().toIso8601String();

  if (excel.tables.isEmpty) return [];

  final String firstSheetName = excel.tables.keys.first;
  final Sheet? sheet = excel.tables[firstSheetName];

  if (sheet == null) return [];
  
  int rowIndex = 0;
  for (var row in sheet.rows) {
    rowIndex++;
    // Přeskočit prázdné řádky a hlavičku (řádek 1)
    if (row.isEmpty || rowIndex == 1) continue;

    String getCellValue(int colIndex) {
      if (colIndex >= row.length || row[colIndex] == null) return '';
      var value = row[colIndex]!.value;
      if (value == null) return '';
      return value.toString().trim();
    }

    // Mapování sloupců Excelu:
    // A (0) -> ID
    // B (1) -> Název
    // C (2) -> IČ
    final String id = getCellValue(0);
    final String nazev = getCellValue(1);
    final String ic = getCellValue(2);

    if (nazev.isNotEmpty) {
      // Klíče musí sedět s CREATE TABLE v DbService!
      outputList.add({
        'externi_id': id,
        'nazev': nazev,
        'ic': ic,
        'folder_path': '', // Defaultně prázdné
        'timestamp': nowIso,
      });
    }
  }
  return outputList;
}