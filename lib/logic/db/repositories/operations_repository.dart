import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../db_connection.dart';

class OperationsRepository {
  final DbConnection _connection;

  OperationsRepository({DbConnection? connection})
      : _connection = connection ?? DbConnection();

  Future<List<Map<String, dynamic>>> getOperace({String query = ''}) async {
    final db = await _connection.database;
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

  Future<void> saveOperace({
    int? id,
    required String kod,
    required String nazev,
    String poznamka = '',
  }) async {
    final db = await _connection.database;
    final data = {
      'kod': kod.trim().toUpperCase(),
      'nazev': nazev.trim(),
      'poznamka': poznamka.trim(),
    };
    if (id == null) {
      await db.insert('operace', data, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.update('operace', data, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteOperace(int id) async {
    final db = await _connection.database;
    await db.delete('operace', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getOperaceCount() async {
    final db = await _connection.database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM operace');
    return res.isNotEmpty ? (res.first['cnt'] as int) : 0;
  }
}
