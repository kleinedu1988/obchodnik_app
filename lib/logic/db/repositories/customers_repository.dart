import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db_connection.dart';

class CustomersRepository {
  static const int _isolateThresholdRows = 2000;

  final DbConnection _connection;

  CustomersRepository({DbConnection? connection})
      : _connection = connection ?? DbConnection();

  Future<List<Map<String, dynamic>>> getZakaznici({
    String query = '',
    bool jenBezSlozky = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _connection.database;
    final normalizedQuery = query.trim();
    final isNumericQuery = RegExp(r'^\d+$').hasMatch(normalizedQuery);

    String sql = 'SELECT * FROM zakaznici WHERE 1=1';
    final args = <dynamic>[];

    if (jenBezSlozky) {
      sql += ' AND (folder_path IS NULL OR folder_path = "")';
    }

    if (normalizedQuery.isNotEmpty) {
      if (isNumericQuery) {
        sql += ' AND (ic LIKE ? OR externi_id LIKE ?)';
        args.addAll(['$normalizedQuery%', '$normalizedQuery%']);
      } else {
        sql += ' AND nazev LIKE ?';
        args.add('%$normalizedQuery%');
      }
    }

    sql += ' ORDER BY nazev ASC LIMIT ? OFFSET ?';
    args.addAll([limit, offset]);

    final rawRows = await db.rawQuery(sql, args);
    return rawRows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> importZakazniku(
    List<Map<String, dynamic>> data,
    Function(double) onProgress,
  ) async {
    final db = await _connection.database;
    onProgress(0.01);

    final existingProfiles = await _loadExistingProfileUidMap(db);

    final processedData = data.length > _isolateThresholdRows
        ? await _runProcessImportData(data, existingProfiles)
        : _processImportData((data, existingProfiles));

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
              columns: [
                'id',
                'customer_unique_key',
                'externi_id',
                'nazev',
                'ic',
                'customer_profile_uid',
                'timestamp',
              ],
              where:
                  'customer_unique_key IN (${List.filled(importedKeys.length, '?').join(',')})',
              whereArgs: importedKeys.toList(),
            );

      final existingByKey = {
        for (final row in existingRows) row['customer_unique_key'].toString(): row,
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
                await txn.update(
                  'zakaznici',
                  row,
                  where: 'id = ?',
                  whereArgs: [existingId],
                );
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
      debugPrint(
        'Import zákazníků hotov: inserted=$inserted, updated=$updated, unchanged=$unchanged, total=$total',
      );
    });

    onProgress(1.0);
  }

  Future<void> updateFolderPath(int id, String newPath) async {
    final db = await _connection.database;
    final normalized = newPath.trim();
    final valueToStore = normalized.isEmpty ? null : normalized;

    await db.update(
      'zakaznici',
      {'folder_path': valueToStore},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCustomerProfileUid(int id, String? profileUid) async {
    final db = await _connection.database;
    await db.update(
      'zakaznici',
      {'customer_profile_uid': profileUid},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getZakaznikById(dynamic id) async {
    final db = await _connection.database;
    final rows = await db.query(
      'zakaznici',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
  }

  Future<Map<String, dynamic>?> getZakaznikByProfileUid(String profileUid) async {
    final db = await _connection.database;
    final rows = await db.query(
      'zakaznici',
      where: 'customer_profile_uid = ?',
      whereArgs: [profileUid],
      limit: 1,
    );
    return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
  }

  Future<Map<String, String>> _loadExistingProfileUidMap(Database db) async {
    final rows = await db.query(
      'zakaznici',
      columns: ['externi_id', 'ic', 'customer_profile_uid'],
      where: "customer_profile_uid IS NOT NULL AND customer_profile_uid != ''",
    );

    return rows.length > _isolateThresholdRows
        ? await _runBuildProfileMap(rows)
        : _buildProfileMapFromRows(rows);
  }

  Future<void> _rebuildCustomerProfilesForCustomers(
    Transaction txn,
    Set<int> customerIds,
  ) async {
    if (customerIds.isEmpty) return;

    final placeholders = List.filled(customerIds.length, '?').join(',');
    await txn.delete(
      'customer_profiles',
      where: 'customer_id IN ($placeholders)',
      whereArgs: customerIds.toList(),
    );

    final customers = await txn.query(
      'zakaznici',
      columns: ['id', 'nazev', 'ic', 'customer_profile_uid'],
      where: 'id IN ($placeholders)',
      whereArgs: customerIds.toList(),
    );

    final batch = txn.batch();
    final now = DateTime.now().toIso8601String();

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
          'keywords': '[]',
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

  static Future<List<Map<String, dynamic>>> _runProcessImportData(
    List<Map<String, dynamic>> data,
    Map<String, String> existingProfiles,
  ) {
    final args = (data, existingProfiles);
    return Isolate.run(() => _processImportData(args));
  }

  static Future<Map<String, String>> _runBuildProfileMap(
    List<Map<String, Object?>> rows,
  ) {
    return Isolate.run(() => _buildProfileMapFromRows(rows));
  }

  static List<Map<String, dynamic>> _processImportData(
    (List<Map<String, dynamic>>, Map<String, String>) args,
  ) {
    final data = args.$1;
    final existingProfiles = args.$2;
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
      final randomPart =
          random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
      return 'cp_${now}_$randomPart';
    }

    for (final row in data) {
      final extId = row['externi_id']?.toString().trim();
      final ic = row['ic']?.toString().trim();

      String? key;
      if (extId != null && extId.isNotEmpty) {
        key = 'ext:$extId';
      } else if (ic != null && ic.isNotEmpty) {
        key = 'ic:$ic';
      }

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

  static Map<String, String> _buildProfileMapFromRows(
    List<Map<String, Object?>> rows,
  ) {
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

  static bool _customerRowsEqual(
    Map<String, Object?> existing,
    Map<String, Object?> incoming,
  ) {
    const keys = [
      'externi_id',
      'nazev',
      'ic',
      'customer_profile_uid',
      'timestamp',
      'customer_unique_key',
    ];
    for (final key in keys) {
      final oldValue = existing[key]?.toString().trim();
      final newValue = incoming[key]?.toString().trim();
      if ((oldValue ?? '') != (newValue ?? '')) return false;
    }
    return true;
  }
}
