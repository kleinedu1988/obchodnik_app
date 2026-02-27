import 'dart:convert';

import 'package:mrb_obchodnik/logic/customer_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db_connection.dart';

class CustomerProfilesRepository {
  final DbConnection _connection;

  CustomerProfilesRepository({DbConnection? connection})
      : _connection = connection ?? DbConnection();

  Future<List<CustomerProfile>> getCustomerProfiles() async {
    final db = await _connection.database;
    final rows = await db.query('customer_profiles', orderBy: 'display_name ASC');
    return rows.map((r) => CustomerProfile.fromDbMap(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getCustomerProfilesRaw({int limit = 500}) async {
    final db = await _connection.database;
    final rows = await db.query(
      'customer_profiles',
      orderBy: 'display_name ASC',
      limit: limit,
    );
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> getCustomerProfile({
    String? profileUid,
    dynamic customerId,
  }) async {
    final db = await _connection.database;
    if (profileUid != null) {
      final rows = await db.query(
        'customer_profiles',
        where: 'profile_uid = ?',
        whereArgs: [profileUid],
        limit: 1,
      );
      return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
    }
    if (customerId != null) {
      final rows = await db.query(
        'customer_profiles',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
    }
    return null;
  }

  Future<void> saveCustomerProfileRaw({
    required String uid,
    required String customerId,
    required String customerName,
    required Map<String, String> mappings,
  }) async {
    final db = await _connection.database;
    final customerIdInt = int.tryParse(customerId);
    if (customerIdInt == null) return;

    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'customer_profiles',
      where: 'profile_uid = ?',
      whereArgs: [uid],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(
        'customer_profiles',
        {
          'customer_id': customerIdInt,
          'profile_uid': uid,
          'display_name': customerName,
          'ico': null,
          'aliases': jsonEncode([customerName]),
          'keywords': '[]',
          'notes': '',
          'mappings': jsonEncode(mappings),
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.update(
        'customer_profiles',
        {
          'mappings': jsonEncode(mappings),
          'updated_at': now,
        },
        where: 'profile_uid = ?',
        whereArgs: [uid],
      );
    }
  }

  Future<CustomerProfile> saveCustomerProfile(CustomerProfile profile) async {
    final db = await _connection.database;
    final now = DateTime.now().toIso8601String();
    final map = Map<String, dynamic>.from(profile.toDbMap());
    map.remove('id');
    map['updated_at'] = now;

    if (profile.id == null) {
      map['created_at'] = now;
      final newId = await db.insert(
        'customer_profiles',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return profile.copyWith(id: newId);
    } else {
      await db.update(
        'customer_profiles',
        map,
        where: 'id = ?',
        whereArgs: [profile.id],
      );
      return profile;
    }
  }

  Future<bool> deleteCustomerProfile(String profileUid) async {
    final db = await _connection.database;
    final count = await db.delete(
      'customer_profiles',
      where: 'profile_uid = ?',
      whereArgs: [profileUid],
    );
    return count > 0;
  }

  Future<List<Map<String, dynamic>>> getCustomerProfilesForCustomer(
    String customerId,
  ) async {
    final db = await _connection.database;
    final rows = await db.query(
      'customer_profiles',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'display_name ASC',
    );
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
