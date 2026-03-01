import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:mrb_obchodnik/logic/customer_profile.dart';
import 'package:mrb_obchodnik/repositories/db/database_provider.dart';
import 'package:mrb_obchodnik/repositories/db/enums/db_table.dart';
import 'package:mrb_obchodnik/repositories/db_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CustomerProfilesRepository implements DbRepository {
  CustomerProfilesRepository(this._provider);

  final DatabaseProvider _provider;

  @override
  Future<Database> get database => _provider.database;

  Future<List<CustomerProfile>> getCustomerProfiles() async {
    final db = await database;
    try {
      final rawRows = await db.query(
        DbTable.customerProfiles.tableName,
        orderBy: 'display_name COLLATE NOCASE ASC',
      );

      List<CustomerProfile> parseProfiles() {
        return rawRows.map((e) => CustomerProfile.fromDbMap(e)).toList();
      }

      return rawRows.length > DatabaseProvider.isolateThresholdRows
          ? await Isolate.run(parseProfiles)
          : parseProfiles();
    } catch (e) {
      debugPrint('DB Error [getCustomerProfiles]: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerProfilesRaw({int limit = 500}) async {
    final db = await database;
    try {
      final rows = await db.query(DbTable.customerProfiles.tableName, limit: limit);
      return rows.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> getCustomerProfile({String? profileUid, dynamic customerId}) async {
    final db = await database;

    if (profileUid != null && profileUid.isNotEmpty) {
      final byUid = await db.query(
        DbTable.customerProfiles.tableName,
        where: 'profile_uid = ?',
        whereArgs: [profileUid],
        limit: 1,
      );
      if (byUid.isNotEmpty) return Map<String, dynamic>.from(byUid.first);
    }

    if (customerId != null) {
      final byCustomer = await db.query(
        DbTable.customerProfiles.tableName,
        where: 'customer_id = ?',
        whereArgs: [customerId.toString()],
        orderBy: 'updated_at DESC',
        limit: 1,
      );
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
      DbTable.customerProfiles.tableName,
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
      final id = await db.insert(
        DbTable.customerProfiles.tableName,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return profile.copyWith(id: id);
    }

    await db.update(
      DbTable.customerProfiles.tableName,
      data,
      where: 'id = ?',
      whereArgs: [profile.id],
    );
    return profile;
  }

  Future<bool> deleteCustomerProfile(String profileUid) async {
    final db = await database;
    final linked = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DbTable.zakaznici.tableName} WHERE customer_profile_uid = ?',
      [profileUid],
    );
    final usedCount = int.tryParse(linked.first['cnt'].toString()) ?? 0;

    if (usedCount > 0) return false;

    await db.delete(
      DbTable.customerProfiles.tableName,
      where: 'profile_uid = ?',
      whereArgs: [profileUid],
    );
    return true;
  }

  Future<List<Map<String, dynamic>>> getCustomerProfilesForCustomer(String customerId) async {
    final db = await database;
    final rows = await db.query(
      DbTable.customerProfiles.tableName,
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
