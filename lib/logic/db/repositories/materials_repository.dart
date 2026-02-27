import '../db_connection.dart';

class MaterialsRepository {
  final DbConnection _connection;

  MaterialsRepository({DbConnection? connection})
      : _connection = connection ?? DbConnection();

  Future<List<Map<String, dynamic>>> getMaterialy({String query = ''}) async {
    final db = await _connection.database;
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

  Future<void> saveMaterial({
    int? id,
    required String nazev,
    String alias = '',
    String tloustky = '',
  }) async {
    final db = await _connection.database;
    final data = {
      'nazev': nazev.trim().toUpperCase(),
      'alias': alias.trim(),
      'tloustky': tloustky.trim(),
    };
    if (id == null) {
      await db.insert('materialy', data);
    } else {
      await db.update('materialy', data, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteMaterial(int id) async {
    final db = await _connection.database;
    await db.delete('materialy', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getMaterialyCount() async {
    final db = await _connection.database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM materialy');
    return res.isNotEmpty ? (res.first['cnt'] as int) : 0;
  }
}
