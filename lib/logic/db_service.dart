import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:mrb_obchodnik/logic/customer_profile.dart';

/// Core Database Service pro MRB CRM 2026.
/// Zajišťuje bleskové vyhledávání a optimalizovanou práci na pozadí (Isolates).
class DbService {
  static Database? _db;
  static const int _isolateThresholdRows = 2000;

  // VERZE 7: Stabilní unique key pro upsert zákazníků
  static const int _dbVersion = 7;
  static final Random _random = Random();

  // Singleton instance pro globální přístup
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  /// Inicializace a přístup k databázi
  Future<Database> get database async {
    if (_db != null) return _db!;

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

  Future<void> _createSchema(Database db) async {
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

    await _ensureIndexes(db);
  }

  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _ensureIndexes(db);
    
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
        debugPrint("Poznámka: Sloupec customer_profile_uid pravděpodobně již existuje.");
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

    await _ensureIndexes(db);
  }

  Future<void> _ensureIndexes(Database db) async {
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

  // =============================================================
  //  DIAGNOSTIKA
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
    return maps.isNotEmpty ? Map<String, dynamic>.from(maps.first) : null;
  }

  Future<int> getRowCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(DISTINCT externi_id) as cnt FROM zakaznici');
      return result.isNotEmpty ? int.parse(result.first['cnt'].toString()) : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('zakaznici');
    await db.delete('customer_profiles');
    debugPrint("Databáze vyčištěna.");
  }

  // =============================================================
  //  VÝKONNÝ IMPORT ZÁKAZNÍKŮ S VYUŽITÍM POZADÍ (Isolates)
  // =============================================================

  Future<void> importZakazniku(
    List<Map<String, dynamic>> data,
    Function(double) onProgress,
  ) async {
    final db = await database;
    onProgress(0.01);

    final existingProfiles = await _loadExistingProfileUidMap(db);
    
    List<Map<String, dynamic>> processData() {
      final random = Random();
      final generatedInRun = <String>{};

      String? buildUniqueKey(Map<String, dynamic> row) {
        final extId = row['externi_id']?.toString().trim();
        if (extId != null && extId.isNotEmpty) return 'ext:$extId';

        final ic = row['ic']?.toString().trim();
        if (ic != null && ic.isNotEmpty) return 'ic:$ic';

        final nazev = row['nazev']?.toString().trim().toLowerCase();
        if (nazev != null && nazev.isNotEmpty) return 'name:$nazev';

        return null;
      }

      String generateUid() {
        final now = DateTime.now().microsecondsSinceEpoch;
        final randomPart = random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
        return 'cp_${now}_$randomPart';
      }

      for (final row in data) {
        final extId = row['externi_id']?.toString().trim();
        final ic = row['ic']?.toString().trim();

        String? key;
        if (extId != null && extId.isNotEmpty) key = 'ext:$extId';
        else if (ic != null && ic.isNotEmpty) key = 'ic:$ic';

        final existingUid = key != null ? existingProfiles[key] : null;
        
        String uid = existingUid ?? '';
        if (uid.isEmpty) {
          uid = generateUid();
          while (generatedInRun.contains(uid)) {
            uid = generateUid();
          }
        }

        row['customer_profile_uid'] = uid;
        row['customer_unique_key'] = buildUniqueKey(row);
        generatedInRun.add(uid);
      }
      return data;
    }

    // PŘESUN VÝPOČTU UID DO VLÁKNA NA POZADÍ jen pro velké importy
    final processedData = data.length > _isolateThresholdRows
        ? await Isolate.run(processData)
        : processData();

    // SAMOTNÝ ZÁPIS DO DB
    await db.transaction((txn) async {
      final total = processedData.length;

      final importedKeys = processedData
          .map((row) => row['customer_unique_key']?.toString())
          .whereType<String>()
          .where((key) => key.isNotEmpty)
          .toSet();

      final existingRows = importedKeys.isEmpty
          ? <Map<String, Object?>>[]
          : await txn.query(
              'zakaznici',
              columns: ['id', 'customer_unique_key', 'externi_id', 'nazev', 'ic', 'customer_profile_uid', 'timestamp'],
              where: 'customer_unique_key IN (${List.filled(importedKeys.length, '?').join(',')})',
              whereArgs: importedKeys.toList(),
            );

      final existingByKey = {
        for (final row in existingRows)
          row['customer_unique_key'].toString(): row,
      };

      int inserted = 0;
      int updated = 0;
      int unchanged = 0;
      final touchedCustomerIds = <int>{};
      const progressChunk = 750;

      for (int i = 0; i < total; i++) {
        final row = Map<String, Object?>.from(processedData[i]);
        final uniqueKey = row['customer_unique_key']?.toString();

        if (uniqueKey == null || uniqueKey.isEmpty) {
          final newId = await txn.insert('zakaznici', row);
          touchedCustomerIds.add(newId);
          inserted++;
        } else {
          final existing = existingByKey[uniqueKey];
          if (existing == null) {
            final newId = await txn.insert(
              'zakaznici',
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            touchedCustomerIds.add(newId);
            inserted++;
          } else {
            final sameData = _customerRowsEqual(existing, row);
            final existingId = existing['id'] as int?;

            if (sameData && existingId != null) {
              unchanged++;
              touchedCustomerIds.add(existingId);
            } else {
              if (existingId != null) {
                await txn.update('zakaznici', row, where: 'id = ?', whereArgs: [existingId]);
                touchedCustomerIds.add(existingId);
              } else {
                final newId = await txn.insert(
                  'zakaznici',
                  row,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                touchedCustomerIds.add(newId);
              }
              updated++;
            }
          }
        }

        if ((i + 1) % progressChunk == 0) {
          onProgress((i + 1) / total);
        }
      }

      await _rebuildCustomerProfilesForCustomers(txn, touchedCustomerIds);
      debugPrint('Import zákazníků hotov: inserted=$inserted, updated=$updated, unchanged=$unchanged, total=$total');
    });

    onProgress(1.0);
  }

  Future<Map<String, String>> _loadExistingProfileUidMap(Database db) async {
    final rows = await db.query(
      'zakaznici',
      columns: ['externi_id', 'ic', 'customer_profile_uid'],
      where: 'customer_profile_uid IS NOT NULL AND customer_profile_uid != ""',
    );

    Map<String, String> buildProfileMap() {
      final result = <String, String>{};
      for (final row in rows) {
        final uid = row['customer_profile_uid']?.toString();
        if (uid == null || uid.isEmpty) continue;

        final extId = row['externi_id']?.toString().trim();
        if (extId != null && extId.isNotEmpty) result['ext:$extId'] = uid;

        final ic = row['ic']?.toString().trim();
        if (ic != null && ic.isNotEmpty) result.putIfAbsent('ic:$ic', () => uid);
      }
      return result;
    }

    // Parsování probíhá na pozadí jen při velkém množství řádků
    return rows.length > _isolateThresholdRows
        ? await Isolate.run(buildProfileMap)
        : buildProfileMap();
  }

  Future<void> _rebuildCustomerProfilesForCustomers(Transaction txn, Set<int> customerIds) async {
    if (customerIds.isEmpty) return;

    final placeholders = List.filled(customerIds.length, '?').join(',');
    await txn.delete(
      'customer_profiles',
      where: 'customer_id IN ($placeholders)',
      whereArgs: customerIds.toList(),
    );

    final customers = await txn.query(
      'zakaznici',
      columns: ['id', 'externi_id', 'nazev', 'ic', 'customer_profile_uid'],
      where: 'customer_profile_uid IS NOT NULL AND customer_profile_uid != "" AND id IN ($placeholders)',
      whereArgs: customerIds.toList(),
    );

    final now = DateTime.now().toIso8601String();
    final batch = txn.batch();

    for (final customer in customers) {
      final uid = customer['customer_profile_uid']?.toString();
      final customerId = customer['id'];
      if (uid == null || uid.isEmpty || customerId == null) continue;

      batch.insert(
        'customer_profiles',
        {
          'customer_id': customerId,
          'profile_uid': uid,
          'display_name': customer['nazev'] ?? 'Neznámý',
          'ico': customer['ic'],
          'aliases': jsonEncode([customer['nazev']]),
          'keywords': jsonEncode([]),
          'notes': '',
          'mappings': null,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  static bool _customerRowsEqual(Map<String, Object?> existing, Map<String, Object?> incoming) {
    const keys = ['externi_id', 'nazev', 'ic', 'customer_profile_uid', 'timestamp', 'customer_unique_key'];
    for (final key in keys) {
      final oldValue = existing[key]?.toString().trim();
      final newValue = incoming[key]?.toString().trim();
      if ((oldValue ?? '') != (newValue ?? '')) return false;
    }
    return true;
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

  // =============================================================
  //  ZÁKAZNÍCI (Přesun parsování seznamů na pozadí)
  // =============================================================

  Future<List<Map<String, dynamic>>> getZakaznici({
    String query = '',
    bool jenBezSlozky = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final normalizedQuery = query.trim();
    final isNumericQuery = RegExp(r'^\d+$').hasMatch(normalizedQuery);

    String sql = 'SELECT * FROM zakaznici WHERE 1=1';
    final args = <dynamic>[];

    if (jenBezSlozky) {
      sql += ' AND (folder_path IS NULL OR folder_path = "")';
    }

    if (normalizedQuery.isNotEmpty) {
      if (isNumericQuery) {
        // Číselný vstup: preferuj prefix vyhledávání v IC / externím ID.
        sql += ' AND (ic LIKE ? OR externi_id LIKE ?)';
        args.addAll(['$normalizedQuery%', '$normalizedQuery%']);
      } else {
        // Textový vstup: hledej pouze v názvu.
        sql += ' AND nazev LIKE ?';
        args.add('%$normalizedQuery%');
      }
    }

    sql += ' ORDER BY nazev ASC LIMIT ? OFFSET ?';
    args.addAll([limit, offset]);

    final rawRows = await db.rawQuery(sql, args);

    return rawRows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> updateFolderPath(int id, String newPath) async {
    final db = await database;
    final normalized = newPath.trim();
    final valueToStore = normalized.isEmpty ? null : normalized;

    await db.update('zakaznici', {'folder_path': valueToStore}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateCustomerProfileUid(int id, String? profileUid) async {
    final db = await database;
    await db.update('zakaznici', {'customer_profile_uid': profileUid}, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getZakaznikById(dynamic id) async {
    final db = await database;
    final rows = await db.query('zakaznici', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
  }

  Future<Map<String, dynamic>?> getZakaznikByProfileUid(String profileUid) async {
    final db = await database;
    final rows = await db.query('zakaznici', where: 'customer_profile_uid = ?', whereArgs: [profileUid], limit: 1);
    return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
  }

  // =============================================================
  //  OPERACE
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
    final rows = await db.rawQuery(sql, args);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveOperace({int? id, required String kod, required String nazev, String poznamka = ''}) async {
    final db = await database;
    final data = {'kod': kod.trim().toUpperCase(), 'nazev': nazev.trim(), 'poznamka': poznamka.trim()};
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

  Future<int> getOperaceCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM operace');
    return res.isNotEmpty ? (res.first['cnt'] as int) : 0;
  }

  // =============================================================
  //  MATERIÁLY
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
    final rows = await db.rawQuery(sql, args);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveMaterial({int? id, required String nazev, String alias = '', String tloustky = ''}) async {
    final db = await database;
    final data = {'nazev': nazev.trim().toUpperCase(), 'alias': alias.trim(), 'tloustky': tloustky.trim()};
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

  Future<int> getMaterialyCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM materialy');
    return res.isNotEmpty ? (res.first['cnt'] as int) : 0;
  }

  // =============================================================
  //  MAPOVACÍ PROFILY (Základní)
  // =============================================================

  Future<List<Map<String, dynamic>>> getProfily() async {
    final db = await database;
    final rows = await db.query('profily', orderBy: 'is_default DESC, name ASC');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveProfil({required String id, required String name, required bool isDefault, required Map<String, String> mappings}) async {
    final db = await database;
    if (isDefault) await db.update('profily', {'is_default': 0});
    final data = {'id': id, 'name': name.trim(), 'is_default': isDefault ? 1 : 0, 'mappings': jsonEncode(mappings)};
    await db.insert('profily', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProfil(String id) async {
    if (id == 'system_default_01') return;
    final db = await database;
    await db.delete('profily', where: 'id = ?', whereArgs: [id]);
  }

  // =============================================================
  //  ZÁKAZNICKÉ PROFILY (Optimalizováno přes Isolates)
  // =============================================================

  Future<List<CustomerProfile>> getCustomerProfiles() async {
    final db = await database;
    try {
      final rawRows = await db.query('customer_profiles', orderBy: 'display_name COLLATE NOCASE ASC');
      
      List<CustomerProfile> parseProfiles() {
        return rawRows.map((e) => CustomerProfile.fromDbMap(e)).toList();
      }

      // DELEGACE: Odloučení složitého dekódování JSON klíčových slov do pozadí jen pro velké dávky
      return rawRows.length > _isolateThresholdRows
          ? await Isolate.run(parseProfiles)
          : parseProfiles();
    } catch (e) {
      debugPrint("DB Error [getCustomerProfiles]: $e");
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerProfilesRaw({int limit = 500}) async {
    final db = await database;
    try {
      final rows = await db.query('customer_profiles', limit: limit);
      return rows.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> getCustomerProfile({String? profileUid, dynamic customerId}) async {
    final db = await database;

    if (profileUid != null && profileUid.isNotEmpty) {
      final byUid = await db.query('customer_profiles', where: 'profile_uid = ?', whereArgs: [profileUid], limit: 1);
      if (byUid.isNotEmpty) return Map<String, dynamic>.from(byUid.first);
    }

    if (customerId != null) {
      final byCustomer = await db.query('customer_profiles', where: 'customer_id = ?', whereArgs: [customerId.toString()], orderBy: 'updated_at DESC', limit: 1);
      if (byCustomer.isNotEmpty) return Map<String, dynamic>.from(byCustomer.first);
    }

    return null;
  }

  Future<void> saveCustomerProfileRaw({
    required String uid,
    required String customerId,
    required String customerName,
    required Map<String, String> mappings,
  }) async {
    final db = await database;
    await db.insert(
      'customer_profiles',
      {
        'profile_uid': uid,
        'customer_id': customerId,
        'display_name': customerName,
        'mappings': jsonEncode(mappings),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CustomerProfile> saveCustomerProfile(CustomerProfile profile) async {
    final db = await database;
    final data = profile.toDbMap()..remove('id');
    data['updated_at'] = DateTime.now().toIso8601String();

    if (profile.id == null) {
      data['created_at'] = data['updated_at'];
      final id = await db.insert('customer_profiles', data, conflictAlgorithm: ConflictAlgorithm.replace);
      return profile.copyWith(id: id);
    }

    await db.update('customer_profiles', data, where: 'id = ?', whereArgs: [profile.id]);
    return profile;
  }

  Future<bool> deleteCustomerProfile(String profileUid) async {
    final db = await database;
    final linked = await db.rawQuery('SELECT COUNT(*) as cnt FROM zakaznici WHERE customer_profile_uid = ?', [profileUid]);
    final usedCount = int.tryParse(linked.first['cnt'].toString()) ?? 0;
    
    if (usedCount > 0) return false;

    await db.delete('customer_profiles', where: 'profile_uid = ?', whereArgs: [profileUid]);
    return true;
  }

  Future<List<Map<String, dynamic>>> getCustomerProfilesForCustomer(String customerId) async {
    final db = await database;
    final rows = await db.query('customer_profiles', where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'updated_at DESC');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}