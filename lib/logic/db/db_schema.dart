import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbSchema {
  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE zakaznici (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        externi_id TEXT,
        customer_unique_key TEXT,
        nazev TEXT,
        ic TEXT,
        customer_profile_uid TEXT,
        folder_path TEXT,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE operace (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kod TEXT UNIQUE,
        nazev TEXT,
        poznamka TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE materialy (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nazev TEXT,
        alias TEXT,
        tloustky TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE profily (
        id TEXT PRIMARY KEY,
        name TEXT,
        is_default INTEGER,
        mappings TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE customer_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        profile_uid TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        ico TEXT,
        aliases TEXT,
        keywords TEXT,
        notes TEXT,
        mappings TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES zakaznici (id) ON DELETE CASCADE
      )
    ''');

    await ensureIndexes(db);
  }

  static Future<void> upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await ensureIndexes(db);

    if (oldVersion < 3) {
      await db.execute('CREATE TABLE IF NOT EXISTS operace (id INTEGER PRIMARY KEY AUTOINCREMENT, kod TEXT UNIQUE, nazev TEXT, poznamka TEXT)');
    }

    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS materialy');
      await db.execute('CREATE TABLE materialy (id INTEGER PRIMARY KEY AUTOINCREMENT, nazev TEXT, alias TEXT, tloustky TEXT)');
    }

    if (oldVersion < 5) {
      await db.execute('CREATE TABLE IF NOT EXISTS profily (id TEXT PRIMARY KEY, name TEXT, is_default INTEGER, mappings TEXT)');
    }

    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE zakaznici ADD COLUMN customer_profile_uid TEXT');
      } catch (e) {
        debugPrint('Poznámka: Sloupec customer_profile_uid pravděpodobně již existuje.');
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS customer_profiles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          profile_uid TEXT NOT NULL UNIQUE,
          display_name TEXT NOT NULL,
          ico TEXT,
          aliases TEXT,
          keywords TEXT,
          notes TEXT,
          mappings TEXT,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (customer_id) REFERENCES zakaznici (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE zakaznici ADD COLUMN customer_unique_key TEXT');
      } catch (_) {
        debugPrint('Poznámka: Sloupec customer_unique_key pravděpodobně již existuje.');
      }

      final rows = await db.query('zakaznici', columns: ['id', 'externi_id', 'ic', 'nazev']);
      final batch = db.batch();
      for (final row in rows) {
        final key = _buildCustomerUniqueKey(
          externiId: row['externi_id']?.toString(),
          ic: row['ic']?.toString(),
          nazev: row['nazev']?.toString(),
        );
        if (key == null) continue;

        batch.update(
          'zakaznici',
          {'customer_unique_key': key},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      await batch.commit(noResult: true);
    }

    await ensureIndexes(db);
  }

  static Future<void> ensureIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_nazev ON zakaznici (nazev)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_ic ON zakaznici (ic)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_folder ON zakaznici (folder_path)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_extid ON zakaznici (externi_id)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_zakaznici_unique_key ON zakaznici (customer_unique_key) WHERE customer_unique_key IS NOT NULL');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zakaznici_profile_uid ON zakaznici (customer_profile_uid)');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_operace_kod ON operace (kod)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_materialy_nazev ON materialy (nazev)');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_profiles_customer ON customer_profiles (customer_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_profiles_uid ON customer_profiles (profile_uid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_profiles_name ON customer_profiles (display_name)');
  }

  static String? _buildCustomerUniqueKey({String? externiId, String? ic, String? nazev}) {
    final normalizedExterniId = externiId?.trim();
    if (normalizedExterniId != null && normalizedExterniId.isNotEmpty) {
      return 'ext:$normalizedExterniId';
    }

    final normalizedIc = ic?.trim();
    if (normalizedIc != null && normalizedIc.isNotEmpty) {
      return 'ic:$normalizedIc';
    }

    final normalizedNazev = nazev?.trim().toLowerCase();
    if (normalizedNazev != null && normalizedNazev.isNotEmpty) {
      return 'name:$normalizedNazev';
    }

    return null;
  }
}
