import 'package:sqflite_common_ffi/sqflite_ffi.dart';

abstract class DbRepository {
  Future<Database> get database;
}
