import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db_schema.dart';

class DbConnection {
  static const int dbVersion = 7;

  static Database? _db;
  static final DbConnection _instance = DbConnection._internal();

  factory DbConnection() => _instance;
  DbConnection._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;

    if (!kIsWeb) {
      sqfliteFfiInit();
    }

    final databaseFactory = databaseFactoryFfi;
    final directory = await getApplicationSupportDirectory();
    final path = join(directory.path, 'mrb_obchodnik.db');

    debugPrint('DB PATH: $path');

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: dbVersion,
        onCreate: (db, version) => DbSchema.createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) =>
            DbSchema.upgradeSchema(db, oldVersion, newVersion),
      ),
    );

    return _db!;
  }
}
