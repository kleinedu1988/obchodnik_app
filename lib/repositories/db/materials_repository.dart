import 'package:mrb_obchodnik/repositories/db/database_provider.dart';
import 'package:mrb_obchodnik/repositories/db/enums/db_table.dart';
import 'package:mrb_obchodnik/repositories/db_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MaterialsRepository implements DbRepository {
  MaterialsRepository(this._provider);

  final DatabaseProvider _provider;

  @override
  Future<Database> get database => _provider.database;

  Future<List<Map<String, dynamic>>> getMaterialy({String query = ''}) async {
    final db = await database;
    String sql = 'SELECT * FROM ${DbTable.materialy.tableName} WHERE 1=1';
    final args = <dynamic>[];

    if (query.isNotEmpty) {
      sql += ' AND (nazev LIKE ? OR alias LIKE ?)';
      args.addAll(['%$query%', '%$query%']);
    }
    sql += ' ORDER BY nazev ASC';
    final rows = await db.rawQuery(sql, args);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveMaterial({
    int? id,
    required String nazev,
    String alias = '',
    String tloustky = '',
  }) async {
    final db = await database;
    final data = {
      'nazev': nazev.trim().toUpperCase(),
      'alias': alias.trim(),
      'tloustky': tloustky.trim(),
    };
    if (id == null) {
      await db.insert(DbTable.materialy.tableName, data);
    } else {
      await db.update(DbTable.materialy.tableName, data, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteMaterial(int id) async {
    final db = await database;
    await db.delete(DbTable.materialy.tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getMaterialyCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${DbTable.materialy.tableName}');
    return res.isNotEmpty ? (res.first['cnt'] as int) : 0;
  }
}
