import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_provider.dart';

class CustomersRepository {
  final DatabaseProvider _provider;
  CustomersRepository(this._provider);

  Future<Database> get database => _provider.database;

  /// HLAVNÍ IMPORT: Zpracuje data z Excelu/externího zdroje
  Future<void> importZakazniku(
    List<Map<String, dynamic>> rawData,
    Function(double) onProgress,
  ) async {
    final db = await database;
    
    // 1. Předpříprava dat v Isolate (klíče, UID, normalizace)
    final processedData = await compute(_prepareImportData, rawData);
    
    await db.transaction((txn) async {
      final total = processedData.length;
      
      // Načtení existujících klíčů pro rychlé porovnání
      final existingRows = await txn.query('zakaznici', columns: ['id', 'customer_unique_key', 'timestamp', 'nazev', 'ic', 'externi_id', 'customer_profile_uid']);
      final existingMap = { for (var r in existingRows) r['customer_unique_key'].toString(): r };

      int inserted = 0;
      int updated = 0;
      int skipped = 0;
      final Set<int> touchedIds = {};

      for (int i = 0; i < total; i++) {
        final row = processedData[i];
        final key = row['customer_unique_key'];
        final existing = existingMap[key];

        if (existing == null) {
          // NOVÝ ZÁKAZNÍK
          final id = await txn.insert('zakaznici', row);
          touchedIds.add(id);
          inserted++;
        } else {
          // EXISTUJÍCÍ - Ochrana proti přepisu novějších dat staršími
          if (_shouldUpdate(existing, row)) {
            final id = existing['id'] as int;
            // Zachovat existující customer_profile_uid – import nesmí přetrhat napojení na profil
            final existingUid = existing['customer_profile_uid'];
            if (existingUid != null && existingUid.toString().isNotEmpty) {
              row['customer_profile_uid'] = existingUid;
            }
            await txn.update('zakaznici', row, where: 'id = ?', whereArgs: [id]);
            touchedIds.add(id);
            updated++;
          } else {
            touchedIds.add(existing['id'] as int);
            skipped++;
          }
        }

        if (i % 100 == 0) onProgress(i / total);
      }

      // 2. AUTOMATICKÉ PROVÁZÁNÍ: Synchronizace tabulky customer_profiles
      await _syncCustomerProfiles(txn, touchedIds);
      
      debugPrint('Import hotov: +$inserted vložených, ~$updated upravených, s$skipped přeskočených');
    });
    
    onProgress(1.0);
  }

  /// VYHLEDÁVÁNÍ: Metoda pro seznam zákazníků s filtry
  Future<List<Map<String, dynamic>>> getZakaznici({
    String query = '',
    bool jenBezSlozky = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    String sql = 'SELECT * FROM zakaznici WHERE 1=1';
    List<dynamic> args = [];

    if (jenBezSlozky) {
      sql += " AND (folder_path IS NULL OR folder_path = '')";
    }

    if (query.isNotEmpty) {
      sql += " AND (nazev LIKE ? OR ic LIKE ? OR externi_id LIKE ?)";
      args.addAll(["%$query%", "$query%", "$query%"]);
    }

    sql += " ORDER BY nazev ASC LIMIT ? OFFSET ?";
    args.addAll([limit, offset]);

    return await db.rawQuery(sql, args);
  }

  /// UPDATE: Aktualizace cesty ke složce
  Future<void> updateFolderPath(int id, String newPath) async {
    final db = await database;
    await db.update('zakaznici', {'folder_path': newPath.trim()}, where: 'id = ?', whereArgs: [id]);
  }

  /// UPDATE: Ruční přiřazení profilu
  Future<void> updateCustomerProfileUid(int id, String? profileUid) async {
    final db = await database;
    await db.update('zakaznici', {'customer_profile_uid': profileUid?.trim()}, where: 'id = ?', whereArgs: [id]);
  }

  /// GET: Detail zákazníka podle ID
  Future<Map<String, dynamic>?> getZakaznikById(dynamic id) async {
    final db = await database;
    final res = await db.query('zakaznici', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  /// GET: Detail zákazníka podle UID profilu (klíčové pro provázanost)
  Future<Map<String, dynamic>?> getZakaznikByProfileUid(String profileUid) async {
    final db = await database;
    final res = await db.query('zakaznici', where: 'customer_profile_uid = ?', whereArgs: [profileUid], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  // --- INTERNÍ LOGIKA ---

  bool _shouldUpdate(Map<String, dynamic> existing, Map<String, dynamic> incoming) {
    // 1. Kontrola časové značky (pokud je v příchozích datech starší čas, neaktualizujeme)
    final oldTsStr = existing['timestamp']?.toString() ?? '';
    final newTsStr = incoming['timestamp']?.toString() ?? '';
    
    if (oldTsStr.isNotEmpty && newTsStr.isNotEmpty) {
      final oldTs = DateTime.tryParse(oldTsStr) ?? DateTime(2000);
      final newTs = DateTime.tryParse(newTsStr) ?? DateTime.now();
      if (oldTs.isAfter(newTs)) return false; 
    }

    // 2. Kontrola změny dat (pokud jsou data identická, netřeba zápis)
    return existing['nazev'] != incoming['nazev'] || 
           existing['ic'] != incoming['ic'] || 
           existing['externi_id'] != incoming['externi_id'];
  }

  Future<void> _syncCustomerProfiles(Transaction txn, Set<int> customerIds) async {
    if (customerIds.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    
    // Načteme dotčené zákazníky
    final customers = await txn.query(
      'zakaznici', 
      where: 'id IN (${customerIds.join(',')})'
    );

    for (final c in customers) {
      final uid = c['customer_profile_uid']?.toString();
      final customerId = c['id'];
      if (uid == null || uid.isEmpty) continue;

      // Hledáme existující profil pro toto UID
      final profiles = await txn.query('customer_profiles', where: 'profile_uid = ?', whereArgs: [uid]);

      if (profiles.isEmpty) {
        // Vytvoření nového profilu
        await txn.insert('customer_profiles', {
          'customer_id': customerId,
          'profile_uid': uid,
          'display_name': c['nazev'],
          'ico': c['ic'],
          'created_at': now,
          'updated_at': now,
        });
      } else {
        // Aktualizace existujícího profilu (synchronizace názvu/IČ)
        await txn.update('customer_profiles', {
          'display_name': c['nazev'],
          'ico': c['ic'],
          'updated_at': now,
        }, where: 'profile_uid = ?', whereArgs: [uid]);
      }
    }
  }
}

// Pomocná funkce běžící v isolate pro maximální plynulost UI
List<Map<String, dynamic>> _prepareImportData(List<Map<String, dynamic>> raw) {
  final random = Random();
  return raw.map((item) {
    final row = Map<String, dynamic>.from(item);
    
    // 1. Normalizace textů
    row['nazev'] = row['nazev']?.toString().trim() ?? 'Neznámý';
    row['ic'] = row['ic']?.toString().trim();
    row['externi_id'] = row['externi_id']?.toString().trim();
    
    // 2. Unikátní klíč pro deduplikaci
    row['customer_unique_key'] = DatabaseProvider.buildCustomerUniqueKey(
      extId: row['externi_id'],
      ic: row['ic'],
      nazev: row['nazev']
    );

    // 3. Generování provázaného UID profilu (pokud chybí)
    // Používáme čas v ms + náhodné číslo pro 100% unikátnost
    if (row['customer_profile_uid'] == null || row['customer_profile_uid'].toString().isEmpty) {
      final ms = DateTime.now().millisecondsSinceEpoch;
      final rnd = random.nextInt(999).toString().padLeft(3, '0');
      row['customer_profile_uid'] = 'cp_${ms}_$rnd';
    }

    row['folder_path'] = row['folder_path'] ?? '';
    row['timestamp'] = row['timestamp'] ?? DateTime.now().toIso8601String();

    return row;
  }).toList();
}