import 'dart:convert';

import 'package:mrb_obchodnik/repositories/db/database_provider.dart';
import 'package:mrb_obchodnik/repositories/db/enums/db_table.dart';
import 'package:mrb_obchodnik/repositories/db_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MappingProfilesRepository implements DbRepository {
  MappingProfilesRepository(this._provider);

  final DatabaseProvider _provider;

  @override
  Future<Database> get database => _provider.database;

  Future<List<Map<String, dynamic>>> getProfily() async {
    final db = await database;
    final rows = await db.query(DbTable.profily.tableName, orderBy: 'is_default DESC, name ASC');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveProfil({
    required String id,
    required String name,
    required bool isDefault,
    required Map<String, String> mappings,
  }) async {
    final db = await database;
    if (isDefault) {
      await db.update(DbTable.profily.tableName, {'is_default': 0});
    }
    final data = {
      'id': id,
      'name': name.trim(),
      'is_default': isDefault ? 1 : 0,
      'mappings': jsonEncode(mappings),
    };
    await db.insert(DbTable.profily.tableName, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProfil(String id) async {
    if (id == 'system_default_01') return;
    final db = await database;
    await db.delete(DbTable.profily.tableName, where: 'id = ?', whereArgs: [id]);
  }
}
