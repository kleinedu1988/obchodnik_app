import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Core Database Service pro MRB CRM 2026.
/// Zajišťuje bleskové vyhledávání díky indexům a stabilitu při importu velkých dat.
class DbService {
  static Database? _db;

  // VERZE 4: Přidána tabulka materialy (katalog)
  static const int _dbVersion = 4;

  // Singleton instance pro globální přístup
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  /// Inicializace a přístup k databázi
  Future<Database> get database async {
    if (_db != null) return _db!;

    // Inicializace FFI pro Desktop (Windows/Linux/macOS)
    if (!kIsWeb) {
      sqfliteFfiInit();
    }
    final databaseFactory = databaseFactoryFfi;

    final directory = await getApplicationSupportDirectory();
    final path = join(directory.path, 'mrb_obchodnik.db');

    debugPrint("DB PATH: $path");

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _upgradeSchema(db, oldVersion, newVersion);
        },
      ),
    );

    return _db!;
  }

  // =============================================================
  //  DEFINICE SCHÉMATU
  // =============================================================

  /// Schéma: zakaznici + operace + materialy(katalog)
  Future<void> _createSchema(Database db) async {
    // 1. ZÁKAZNÍCI
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

    // 2. OPERACE (bez ceny, jen technologický popis)
    await db.execute('''
      CREATE TABLE operace (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kod TEXT UNIQUE,
        nazev TEXT,
        poznamka TEXT
      )
    ''');

    // 3. MATERIÁLY (Katalog s definicí tlouštěk)
    await db.execute('''
      CREATE TABLE materialy (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nazev TEXT,
        alias TEXT,
        tloustky TEXT
      )
    ''');

    await _ensureIndexes(db);
  }

  /// Migrace databáze
  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    // V2: Indexy
    if (oldVersion < 2) {
      await _ensureIndexes(db);
    }

    // V3: Operace
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS operace (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          kod TEXT UNIQUE,
          nazev TEXT,
          poznamka TEXT
        )
      ''');
    }

    // V4: Materiály
    if (oldVersion < 4) {
      // Pro jistotu smažeme, pokud existovala (při vývoji)
      await db.execute('DROP TABLE IF EXISTS materialy');

      await db.execute('''
        CREATE TABLE materialy (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nazev TEXT,
          alias TEXT,
          tloustky TEXT
        )
      ''');
    }
  }

  /// Indexy zajišťují bleskové vyhledávání.
  Future<void> _ensureIndexes(Database db) async {
    // Zákazníci
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_nazev ON zakaznici (nazev)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_ic ON zakaznici (ic)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_folder ON zakaznici (folder_path)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_extid ON zakaznici (externi_id)');
    
    // Operace
    await db.execute('CREATE INDEX IF NOT EXISTS idx_operace_kod ON operace (kod)');
    
    // Materiály
    await db.execute('CREATE INDEX IF NOT EXISTS idx_materialy_nazev ON materialy (nazev)');
  }

  // =============================================================
  //  DIAGNOSTIKA (Pro DbStatusTab)
  // =============================================================

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.rawQuery(
      'SELECT MAX(timestamp) as last_import, COUNT(*) as count FROM zakaznici',
    );
    return res.first;
  }

  Future<Map<String, dynamic>?> getLastEntry() async {
    final db = await database;
    final maps = await db.query(
      'zakaznici',
      orderBy: 'timestamp DESC, id DESC',
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<int> getRowCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(DISTINCT externi_id) as cnt FROM zakaznici');
      return result.isNotEmpty ? int.parse(result.first['cnt'].toString()) : 0;
    } catch (e) {
      debugPrint("DB Error [getRowCount]: $e");
      return 0;
    }
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('zakaznici');
    debugPrint("Databáze zakaznici byla kompletně vyčištěna.");
  }

  // =============================================================
  //  VÝKONNÝ IMPORT ZÁKAZNÍKŮ
  // =============================================================

  Future<void> importZakazniku(
    List<Map<String, dynamic>> data,
    Function(double) onProgress,
  ) async {
    final db = await database;
    onProgress(0.01);

    await db.transaction((txn) async {
      await txn.delete('zakaznici'); // POZOR: Toto smaže i přiřazené složky!

      final batch = txn.batch();
      final total = data.length;

      for (int i = 0; i < total; i++) {
        batch.insert('zakaznici', data[i]);

        if (i % 300 == 0 && i != 0) {
          onProgress(i / total);
        }
      }

      debugPrint("Spouštím batch commit pro $total záznamů...");
      await batch.commit(noResult: true);
      debugPrint("Batch commit na disk dokončen.");
    });

    onProgress(1.0);
  }

  // =============================================================
  //  ZÁKAZNÍCI (Read & Update Path)
  // =============================================================

  Future<List<Map<String, dynamic>>> getZakaznici({
    String query = '',
    bool jenBezSlozky = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;

    String sql = 'SELECT * FROM zakaznici WHERE 1=1';
    final args = <dynamic>[];

    if (jenBezSlozky) {
      sql += ' AND (folder_path IS NULL OR folder_path = "")';
    }

    if (query.isNotEmpty) {
      sql += ' AND (nazev LIKE ? OR ic LIKE ? OR externi_id LIKE ?)';
      args.addAll(['%$query%', '%$query%', '%$query%']);
    }

    sql += ' ORDER BY nazev ASC LIMIT ? OFFSET ?';
    args.addAll([limit, offset]);

    return db.rawQuery(sql, args);
  }

  Future<void> updateFolderPath(int id, String newPath) async {
    final db = await database;
    final normalized = newPath.trim();
    final valueToStore = normalized.isEmpty ? null : normalized;

    await db.update(
      'zakaznici',
      {'folder_path': valueToStore},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =============================================================
  //  OPERACE (CRUD)
  // =============================================================

  Future<List<Map<String, dynamic>>> getOperace({String query = ''}) async {
    final db = await database;
    String sql = 'SELECT * FROM operace WHERE 1=1';
    final args = <dynamic>[];

    if (query.isNotEmpty) {
      sql += ' AND (nazev LIKE ? OR kod LIKE ? OR poznamka LIKE ?)';
      args.addAll(['%$query%', '%$query%', '%$query%']);
    }

    sql += ' ORDER BY kod ASC';
    return db.rawQuery(sql, args);
  }

  Future<void> saveOperace({
    int? id,
    required String kod,
    required String nazev,
    String poznamka = '',
  }) async {
    final db = await database;
    final data = <String, dynamic>{
      'kod': kod.trim().toUpperCase(),
      'nazev': nazev.trim(),
      'poznamka': poznamka.trim(),
    };

    if (id == null) {
      await db.insert('operace', data, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.update('operace', data, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteOperace(int id) async {
    final db = await database;
    await db.delete('operace', where: 'id = ?', whereArgs: [id]);
  }

  // =============================================================
  //  MATERIÁLY (CRUD)
  // =============================================================

  Future<List<Map<String, dynamic>>> getMaterialy({String query = ''}) async {
    final db = await database;
    String sql = 'SELECT * FROM materialy WHERE 1=1';
    final args = <dynamic>[];

    if (query.isNotEmpty) {
      sql += ' AND (nazev LIKE ? OR alias LIKE ?)';
      args.addAll(['%$query%', '%$query%']);
    }

    sql += ' ORDER BY nazev ASC';
    return db.rawQuery(sql, args);
  }

  Future<void> saveMaterial({
    int? id,
    required String nazev,
    String alias = '',
    String tloustky = '',
  }) async {
    final db = await database;
    final data = <String, dynamic>{
      'nazev': nazev.trim().toUpperCase(),
      'alias': alias.trim(),
      'tloustky': tloustky.trim(),
    };

    if (id == null) {
      await db.insert('materialy', data);
    } else {
      await db.update('materialy', data, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteMaterial(int id) async {
    final db = await database;
    await db.delete('materialy', where: 'id = ?', whereArgs: [id]);
  }
}