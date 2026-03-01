import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseProvider {
  DatabaseProvider._internal();
  static final DatabaseProvider _instance = DatabaseProvider._internal();
  factory DatabaseProvider() => _instance;

  static const int dbVersion = 10; // v10: aliases + keywords v customer_profiles
  static const int isolateThresholdRows = 1000;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    if (!kIsWeb) sqfliteFfiInit();
    
    final databaseFactory = databaseFactoryFfi;
    final directory = await getApplicationSupportDirectory();
    final path = join(directory.path, 'mrb_obchodnik.db');

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: dbVersion,
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
    return _db!;
  }

  Future<void> _createSchema(Database db, int version) async {
    // Tabulka zákazníků - hlavní evidence
    await db.execute('''
      CREATE TABLE zakaznici (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        externi_id TEXT,
        ic TEXT,
        nazev TEXT NOT NULL,
        customer_unique_key TEXT UNIQUE,
        customer_profile_uid TEXT,
        folder_path TEXT,
        timestamp TEXT
      )
    ''');

    // Tabulka profilů - technické nastavení a mapování
    await db.execute('''
      CREATE TABLE customer_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        profile_uid TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        ico TEXT,
        aliases TEXT,
        keywords TEXT,
        mappings TEXT,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES zakaznici (id) ON DELETE CASCADE
      )
    ''');

    // Pomocné číselníky
    await db.execute('CREATE TABLE operace (id INTEGER PRIMARY KEY AUTOINCREMENT, kod TEXT UNIQUE, nazev TEXT, poznamka TEXT)');
    await db.execute('CREATE TABLE materialy (id INTEGER PRIMARY KEY AUTOINCREMENT, nazev TEXT, alias TEXT, tloustky TEXT)');

    // Mapovací profily pro import
    await db.execute('CREATE TABLE profily (id TEXT PRIMARY KEY, name TEXT NOT NULL, is_default INTEGER NOT NULL DEFAULT 0, mappings TEXT NOT NULL DEFAULT \'{}\')');


    await _ensureIndexes(db);
  }

  Future<void> _upgradeSchema(Database db, int old, int next) async {
    if (old < 8) {
      // Pokud upgradujeme na verzi 8, zajistíme existenci všech klíčových sloupců
      try { await db.execute('ALTER TABLE zakaznici ADD COLUMN customer_unique_key TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE zakaznici ADD COLUMN timestamp TEXT'); } catch (_) {}
    }
    if (old < 9) {
      // v9: vytvoření tabulky profily, pokud ještě neexistuje
      await db.execute('CREATE TABLE IF NOT EXISTS profily (id TEXT PRIMARY KEY, name TEXT NOT NULL, is_default INTEGER NOT NULL DEFAULT 0, mappings TEXT NOT NULL DEFAULT \'{}\')');
    }
    if (old < 10) {
      // v10: přidání aliases a keywords do customer_profiles
      try { await db.execute('ALTER TABLE customer_profiles ADD COLUMN aliases TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE customer_profiles ADD COLUMN keywords TEXT'); } catch (_) {}
    }
    await _ensureIndexes(db);
  }

  Future<void> _ensureIndexes(Database db) async {
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_zak_unique ON zakaznici (customer_unique_key) WHERE customer_unique_key IS NOT NULL');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zak_nazev ON zakaznici (nazev)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zak_profile ON zakaznici (customer_profile_uid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_prof_cust ON customer_profiles (customer_id)');
  }

  // Pomocná metoda pro tvorbu unikátního klíče (používaná napříč aplikací)
  static String? buildCustomerUniqueKey({String? extId, String? ic, String? nazev}) {
    final e = extId?.trim();
    if (e != null && e.isNotEmpty) return "EXT_$e";
    
    final i = ic?.trim();
    if (i != null && i.isNotEmpty) return "IC_$i";
    
    final n = nazev?.trim().toLowerCase();
    if (n != null && n.isNotEmpty) return "NAME_${n.hashCode}";
    
    return null;
  }
}