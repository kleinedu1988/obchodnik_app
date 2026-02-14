import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Core Database Service pro MRB CRM 2026.
/// Zajišťuje bleskové vyhledávání díky indexům a stabilitu při importu velkých dat.
class DbService {
  static Database? _db;

  // 1) ZVEDNUTO: nová tabulka operace => bump verze DB
  static const int _dbVersion = 3;

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

  /// 2) SCHÉMA: přidána tabulka operace (bez ceny)
  Future<void> _createSchema(Database db) async {
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

    // NOVÁ TABULKA OPERACE
    await db.execute('''
      CREATE TABLE operace (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kod TEXT UNIQUE,
        nazev TEXT,
        poznamka TEXT
      )
    ''');

    await _ensureIndexes(db);
  }

  /// 3) MIGRACE: verze 3 přidává tabulku operace (bez ceny)
  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _ensureIndexes(db);
    }

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
  }

  /// Indexy zajišťují bleskové vyhledávání. Přidán index i na externi_id pro COUNT DISTINCT.
  Future<void> _ensureIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_nazev ON zakaznici (nazev)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_ic ON zakaznici (ic)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_folder ON zakaznici (folder_path)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_extid ON zakaznici (externi_id)');
  }

  // =============================================================
  //  DIAGNOSTIKA (Pro DbStatusTab)
  // =============================================================

  /// Získá souhrnné informace o databázi v jednom dotazu.
  /// Vrací 'last_import' (ISO string) a 'count' (počet řádků).
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.rawQuery(
      'SELECT MAX(timestamp) as last_import, COUNT(*) as count FROM zakaznici',
    );
    return res.first;
  }

  /// Získá poslední záznam pro informaci o čerstvosti dat
  Future<Map<String, dynamic>?> getLastEntry() async {
    final db = await database;
    final maps = await db.query(
      'zakaznici',
      orderBy: 'timestamp DESC, id DESC',
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  /// Vrátí celkový počet unikátních zákazníků v systému podle externího ID.
  /// To zabrání zkreslení, pokud by se v DB objevily duplicity.
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

  /// Metoda pro kompletní promazání databáze.
  /// Užitečné pro odstranění "nepořádku" po chybných importech.
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('zakaznici');
    debugPrint("Databáze zakaznici byla kompletně vyčištěna.");
  }

  // =============================================================
  //  VÝKONNÝ IMPORT
  // =============================================================

  /// Importuje data v dávkách (Batch).
  Future<void> importZakazniku(
    List<Map<String, dynamic>> data,
    Function(double) onProgress,
  ) async {
    final db = await database;

    onProgress(0.01);

    await db.transaction((txn) async {
      await txn.delete('zakaznici');

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
  //  DOTAZY (Paging + Filter + Search)
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

  // =============================================================
  //  AKTUALIZACE CESTY
  // =============================================================

  Future<void> updateFolderPath(int id, String newPath) async {
    final db = await database;

    final normalized = newPath.trim();
    final valueToStore = normalized.isEmpty ? null : normalized;

    final existing = await db.query(
      'zakaznici',
      columns: ['folder_path'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final current = (existing.first['folder_path'] ?? '').toString().trim();
      if (current == normalized) return;
    }

    await db.update(
      'zakaznici',
      {'folder_path': valueToStore},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =============================================================
  //  OPERACE (CRUD) - NOVÉ
  // =============================================================

  Future<List<Map<String, dynamic>>> getOperace({String query = ''}) async {
    final db = await database;

    String sql = 'SELECT * FROM operace WHERE 1=1';
    final args = <dynamic>[];

    if (query.isNotEmpty) {
      sql += ' AND (nazev LIKE ? OR kod LIKE ?)';
      args.addAll(['%$query%', '%$query%']);
    }

    sql += ' ORDER BY kod ASC';
    return db.rawQuery(sql, args);
  }

  /// Uložení operace (bez ceny).
  /// - id == null => insert
  /// - id != null => update
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
      await db.insert(
        'operace',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.update(
        'operace',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> deleteOperace(int id) async {
    final db = await database;
    await db.delete('operace', where: 'id = ?', whereArgs: [id]);
  }
}
