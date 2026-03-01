import 'package:mrb_obchodnik/repositories/db/database_provider.dart';
import 'package:mrb_obchodnik/repositories/db/enums/db_table.dart';
import 'package:mrb_obchodnik/repositories/db_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class OperationsRepository implements DbRepository {
  OperationsRepository(this._provider);

  final DatabaseProvider _provider;

  @override
  Future<Database> get database => _provider.database;

  Future<List<Map<String, dynamic>>> getOperace({String query = ''}) async {
    final db = await database;
    String sql = 'SELECT * FROM ${DbTable.operace.tableName} WHERE 1=1';
    final args = <dynamic>[];

    if (query.isNotEmpty) {
      sql += ' AND (nazev LIKE ? OR kod LIKE ? OR poznamka LIKE ?)';
      args.addAll(['%$query%', '%$query%', '%$query%']);
    }
    sql += ' ORDER BY kod ASC';
    final rows = await db.rawQuery(sql, args);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveOperace({
    int? id,
    required String kod,
    required String nazev,
    String poznamka = '',
  }) async {
    final db = await database;
    final data = {
      'kod': kod.trim().toUpperCase(),
      'nazev': nazev.trim(),
      'poznamka': poznamka.trim(),
    };
    if (id == null) {
      await db.insert(DbTable.operace.tableName, data, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.update(DbTable.operace.tableName, data, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteOperace(int id) async {
    final db = await database;
    await db.delete(DbTable.operace.tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getOperaceCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${DbTable.operace.tableName}');
    return res.isNotEmpty ? (res.first['cnt'] as int) : 0;
  }
}
