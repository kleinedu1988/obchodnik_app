import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'db_service.dart';

class ImportLogic {
  static Future<void> spustitImport(BuildContext context, File file) async {
    // 1. Definujeme proměnnou pro sledování pokroku
    ValueNotifier<double> progressNotifier = ValueNotifier(0.0);

    // 2. Zobrazíme vyskakovací okno (Dialog)
    showDialog(
      context: context,
      barrierDismissible: false, // Uživatel to nemůže zavřít kliknutím vedle
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161616),
          title: const Text("Importuji data..."),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, value, child) {
                  return Column(
                    children: [
                      LinearProgressIndicator(
                        value: value,
                        backgroundColor: Colors.white10,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(height: 10),
                      Text("${(value * 100).toInt()}% hotovo"),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    try {
      // 3. Načtení Excelu (v paměti)
      var bytes = file.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      List<Map<String, dynamic>> dataToInsert = [];
      String nyni = DateTime.now().toIso8601String();

      for (var table in excel.tables.keys) {
        var rows = excel.tables[table]!.rows;
        for (int i = 1; i < rows.length; i++) {
          var row = rows[i];
          if (row.length >= 3) {
            dataToInsert.add({
              'externi_id': row[0]?.value?.toString() ?? '',
              'nazev': row[1]?.value?.toString() ?? '',
              'ic': row[2]?.value?.toString() ?? '',
              'folder_path': '',
              'timestamp': nyni,
            });
          }
        }
      }

      // 4. Samotný zápis do DB s aktualizací progress baru
      await DbService().importZakazniku(dataToInsert, (progress) {
        progressNotifier.value = progress;
      });

      // 5. Zavření dialogu po dokončení
      Navigator.pop(context); 
      
    } catch (e) {
      Navigator.pop(context); // Zavřít okno i v případě chyby
      print("Chyba při importu: $e");
    }
  }
}