import 'package:mrb_obchodnik/repositories/db/database_provider.dart';
import 'package:mrb_obchodnik/repositories/db/enums/db_table.dart';
import 'package:mrb_obchodnik/repositories/db_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DiagnosticsRepository implements DbRepository {
  DiagnosticsRepository(this._provider);

  final DatabaseProvider _provider;

  @override
  Future<Database> get database => _provider.database;

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT MAX(timestamp) as last_import, COUNT(*) as count FROM ${DbTable.zakaznici.tableName}',
    );
    return Map<String, dynamic>.from(res.first);
  }

  Future<Map<String, dynamic>?> getLastEntry() async {
    final db = await database;
    final maps = await db.query(
      DbTable.zakaznici.tableName,
      orderBy: 'timestamp DESC, id DESC',
      limit: 1,
    );
    return maps.isNotEmpty ? Map<String, dynamic>.from(maps.first) : null;
  }

  Future<int> getRowCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(DISTINCT externi_id) as cnt FROM ${DbTable.zakaznici.tableName}');
      return result.isNotEmpty ? int.parse(result.first['cnt'].toString()) : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete(DbTable.zakaznici.tableName);
    await db.delete(DbTable.customerProfiles.tableName);
  }
}
