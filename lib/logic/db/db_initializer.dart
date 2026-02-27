import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'db_connection.dart';

class DbInitializer {
  static const String _dbFileName = 'mrb_obchodnik.db';

  /// Zkontroluje existenci DB souboru a případně ji vytvoří.
  /// Volejte v main() před runApp().
  static Future<void> initialize() async {
    final directory = await getApplicationSupportDirectory();
    final path = join(directory.path, _dbFileName);
    final exists = File(path).existsSync();

    if (exists) {
      debugPrint('DB: Nalezena existující databáze ($path)');
    } else {
      debugPrint('DB: Databáze neexistuje, vytvářím novou ($path)');
    }

    // Otevření (nebo vytvoření) DB — spustí onCreate / onUpgrade dle potřeby
    await DbConnection().database;

    debugPrint('DB: Inicializace dokončena${exists ? '' : ' — schéma vytvořeno'}.');
  }
}
