import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db_connection.dart';

class MappingProfilesRepository {
  final DbConnection _connection;

  MappingProfilesRepository({DbConnection? connection})
      : _connection = connection ?? DbConnection();

  Future<List<Map<String, dynamic>>> getProfily() async {
    final db = await _connection.database;
    final rows = await db.query('profily', orderBy: 'is_default DESC, name ASC');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveProfil({
    required String id,
    required String name,
    required bool isDefault,
    required Map<String, String> mappings,
  }) async {
    final db = await _connection.database;
    if (isDefault) await db.update('profily', {'is_default': 0});
    final data = {
      'id': id,
      'name': name.trim(),
      'is_default': isDefault ? 1 : 0,
      'mappings': jsonEncode(mappings),
    };
    await db.insert('profily', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProfil(String id) async {
    if (id == 'system_default_01') return;
    final db = await _connection.database;
    await db.delete('profily', where: 'id = ?', whereArgs: [id]);
  }
}
