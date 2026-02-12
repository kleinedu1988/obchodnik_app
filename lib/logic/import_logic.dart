import 'dart:io';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'db_service.dart';
import 'actions.dart'; 

class ImportLogic {
  static Future<void> spustitImport(BuildContext context, File file) async {
    final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
    zobrazImportProgress(context, progressNotifier);

    try {
      progressNotifier.value = 0.01;
      final bytes = await file.readAsBytes();

      debugPrint("Isolate: Start dekódování...");
      // PARSOVÁNÍ BĚŽÍ V JINÉM JÁDRU PROCESORU
      final List<Map<String, dynamic>> dataToInsert = await compute(_parsePartnersExcel, bytes);

      if (dataToInsert.isEmpty) {
        throw "Excel soubor neobsahuje platná data k importu.";
      }

      // ZÁPIS DO DB (Batch Transaction)
      await DbService().importZakazniku(dataToInsert, (progress) {
        if (progressNotifier.hasListeners) {
          progressNotifier.value = progress.clamp(0.0, 1.0);
        }
      });

      if (context.mounted) {
        ukonciImport(context, "PARTNEŘI");
      }
      
    } catch (e) {
      debugPrint("CHYBA IMPORTU: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e'), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 300));
      if (progressNotifier.hasListeners) progressNotifier.dispose();
    }
  }
}

/// Funkce pro Isolate (vytáhne data z Obchodní partneři.xlsx)
List<Map<String, dynamic>> _parsePartnersExcel(List<int> bytes) {
  final excel = ex.Excel.decodeBytes(bytes);
  final List<Map<String, dynamic>> list = [];
  final String nyni = DateTime.now().toIso8601String();

  if (excel.tables.isEmpty) return [];

  // Bereme pouze první list
  final String firstSheetName = excel.tables.keys.first;
  final sheet = excel.tables[firstSheetName]!;
  
  int rowIndex = 0;
  for (final row in sheet.rows) {
    rowIndex++;
    if (row.isEmpty || rowIndex == 1) continue;

    String extract(int index) {
      if (index >= row.length || row[index] == null) return '';
      return row[index]!.value.toString().trim();
    }

    final id = extract(0);    // ID partnera
    final nazev = extract(1); // Zkrácený název
    final ic = extract(2);    // IČ partnera

    if (nazev.isNotEmpty) {
      list.add({
        'externi_id': id,
        'nazev': nazev,
        'ic': ic,
        'folder_path': '',
        'timestamp': nyni,
      });
    }
  }
  return list;
}