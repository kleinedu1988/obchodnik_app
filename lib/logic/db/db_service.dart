import 'package:mrb_obchodnik/logic/customer_profile.dart';

import 'db_connection.dart';
import 'repositories/customer_profiles_repository.dart';
import 'repositories/customers_repository.dart';
import 'repositories/mapping_profiles_repository.dart';
import 'repositories/materials_repository.dart';
import 'repositories/operations_repository.dart';

/// Tenký fasádní adaptér pro zachování kompatibility stávajícího API.
class DbService {
  final DbConnection _connection;
  final CustomersRepository _customers;
  final OperationsRepository _operations;
  final MaterialsRepository _materials;
  final MappingProfilesRepository _mappingProfiles;
  final CustomerProfilesRepository _customerProfiles;

  static final DbService _instance = DbService._internal();

  factory DbService() => _instance;

  DbService._internal()
      : _connection = DbConnection(),
        _customers = CustomersRepository(),
        _operations = OperationsRepository(),
        _materials = MaterialsRepository(),
        _mappingProfiles = MappingProfilesRepository(),
        _customerProfiles = CustomerProfilesRepository();

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await _connection.database;
    final res = await db.rawQuery(
      'SELECT MAX(timestamp) as last_import, COUNT(*) as count FROM zakaznici',
    );
    return res.first;
  }

  Future<Map<String, dynamic>?> getLastEntry() async {
    final db = await _connection.database;
    final maps = await db.query(
      'zakaznici',
      orderBy: 'timestamp DESC, id DESC',
      limit: 1,
    );
    return maps.isNotEmpty ? Map<String, dynamic>.from(maps.first) : null;
  }

  Future<int> getRowCount() async {
    try {
      final db = await _connection.database;
      final result = await db
          .rawQuery('SELECT COUNT(DISTINCT externi_id) as cnt FROM zakaznici');
      return result.isNotEmpty ? int.parse(result.first['cnt'].toString()) : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearDatabase() async {
    final db = await _connection.database;
    await db.delete('zakaznici');
    await db.delete('customer_profiles');
  }

  Future<List<Map<String, dynamic>>> getZakaznici({
    String query = '',
    bool jenBezSlozky = false,
    int limit = 50,
    int offset = 0,
  }) {
    return _customers.getZakaznici(
      query: query,
      jenBezSlozky: jenBezSlozky,
      limit: limit,
      offset: offset,
    );
  }

  Future<void> importZakazniku(
    List<Map<String, dynamic>> data,
    Function(double) onProgress,
  ) {
    return _customers.importZakazniku(data, onProgress);
  }

  Future<void> updateFolderPath(int id, String newPath) {
    return _customers.updateFolderPath(id, newPath);
  }

  Future<void> updateCustomerProfileUid(int id, String? profileUid) {
    return _customers.updateCustomerProfileUid(id, profileUid);
  }

  Future<Map<String, dynamic>?> getZakaznikById(dynamic id) {
    return _customers.getZakaznikById(id);
  }

  Future<Map<String, dynamic>?> getZakaznikByProfileUid(String profileUid) {
    return _customers.getZakaznikByProfileUid(profileUid);
  }

  Future<List<Map<String, dynamic>>> getOperace({String query = ''}) {
    return _operations.getOperace(query: query);
  }

  Future<void> saveOperace({
    int? id,
    required String kod,
    required String nazev,
    String poznamka = '',
  }) {
    return _operations.saveOperace(
      id: id,
      kod: kod,
      nazev: nazev,
      poznamka: poznamka,
    );
  }

  Future<void> deleteOperace(int id) {
    return _operations.deleteOperace(id);
  }

  Future<int> getOperaceCount() {
    return _operations.getOperaceCount();
  }

  Future<List<Map<String, dynamic>>> getMaterialy({String query = ''}) {
    return _materials.getMaterialy(query: query);
  }

  Future<void> saveMaterial({
    int? id,
    required String nazev,
    String alias = '',
    String tloustky = '',
  }) {
    return _materials.saveMaterial(
      id: id,
      nazev: nazev,
      alias: alias,
      tloustky: tloustky,
    );
  }

  Future<void> deleteMaterial(int id) {
    return _materials.deleteMaterial(id);
  }

  Future<int> getMaterialyCount() {
    return _materials.getMaterialyCount();
  }

  Future<List<Map<String, dynamic>>> getProfily() {
    return _mappingProfiles.getProfily();
  }

  Future<void> saveProfil({
    required String id,
    required String name,
    required bool isDefault,
    required Map<String, String> mappings,
  }) {
    return _mappingProfiles.saveProfil(
      id: id,
      name: name,
      isDefault: isDefault,
      mappings: mappings,
    );
  }

  Future<void> deleteProfil(String id) {
    return _mappingProfiles.deleteProfil(id);
  }

  Future<List<CustomerProfile>> getCustomerProfiles() {
    return _customerProfiles.getCustomerProfiles();
  }

  Future<List<Map<String, dynamic>>> getCustomerProfilesRaw({int limit = 500}) {
    return _customerProfiles.getCustomerProfilesRaw(limit: limit);
  }

  Future<Map<String, dynamic>?> getCustomerProfile({
    String? profileUid,
    dynamic customerId,
  }) {
    return _customerProfiles.getCustomerProfile(
      profileUid: profileUid,
      customerId: customerId,
    );
  }

  Future<void> saveCustomerProfileRaw({
    required String uid,
    required String customerId,
    required String customerName,
    required Map<String, String> mappings,
  }) {
    return _customerProfiles.saveCustomerProfileRaw(
      uid: uid,
      customerId: customerId,
      customerName: customerName,
      mappings: mappings,
    );
  }

  Future<CustomerProfile> saveCustomerProfile(CustomerProfile profile) {
    return _customerProfiles.saveCustomerProfile(profile);
  }

  Future<bool> deleteCustomerProfile(String profileUid) {
    return _customerProfiles.deleteCustomerProfile(profileUid);
  }

  Future<List<Map<String, dynamic>>> getCustomerProfilesForCustomer(
    String customerId,
  ) {
    return _customerProfiles.getCustomerProfilesForCustomer(customerId);
  }
}