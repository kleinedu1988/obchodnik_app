import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; // Toto definuje debugPrint

class DbService {
  static Database? _db;

  // Inicializace databáze - vytvoří soubor, pokud neexistuje
  Future<Database> get database async {
    if (_db != null) return _db!;

    // Inicializace pro Windows
    sqfliteFfiInit();
    var databaseFactory = databaseFactoryFfi;

    // Cesta k souboru (uloží se do uživatelských dat aplikace)
    final directory = await getApplicationSupportDirectory();
    final path = join(directory.path, 'mrb_obchodnik.db');

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          // Vytvoření tabulky při prvním spuštění
          await db.execute('''
            CREATE TABLE zakaznici (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              externi_id TEXT,
              nazev TEXT,
              ic TEXT,
              folder_path TEXT,
              timestamp TEXT
            )
          ''');
        },
      ),
    );
    return _db!;
  }

  // Funkce, kterou volá tvá diagnostika v SettingsView
  Future<Map<String, dynamic>?> getLastEntry() async {
    final db = await database;
    // Zkusíme vzít první záznam, abychom zjistili timestamp
    final List<Map<String, dynamic>> maps = await db.query(
      'zakaznici',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null; // Databáze je prázdná
  }

  // Hromadné vložení dat - EXTRÉMNĚ RYCHLÉ díky Transaction
  Future<void> importZakazniku(
    List<Map<String, dynamic>> data, 
    Function(double) onProgress
  ) async {
    final db = await database;
    
    await db.transaction((txn) async {
      await txn.delete('zakaznici'); // Vyčistíme starou tabulku
      
      int total = data.length;
      for (int i = 0; i < total; i++) {
        await txn.insert('zakaznici', data[i]);
        
        // Každých 100 záznamů pošleme info o pokroku (kvůli výkonu neposíláme každý řádek)
        if (i % 100 == 0) {
          onProgress(i / total);
        }
      }
      onProgress(1.0); // Hotovo
    });
  }

  Future<int> getRowCount() async {
    try {
      final db = await database;
      // rawQuery spustí čistý SQL příkaz a vrátí výsledek jako tabulku (List)
      final List<Map<String, Object?>> x = await db.rawQuery('SELECT COUNT(*) FROM zakaznici');
      
      // Výsledek vypadá jako [{'COUNT(*)': 15000}]
      // My vytáhneme tu první hodnotu a převedeme ji na celé číslo (int)
      if (x.isNotEmpty) {
        return int.parse(x.first.values.first.toString());
      }
      return 0;
    } catch (e) {
      debugPrint("Chyba při počítání řádků: $e");
      return 0; // Pokud se něco pokazí, vrátíme 0, aby aplikace nespadla
    }
  }
}