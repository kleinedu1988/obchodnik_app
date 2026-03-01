enum DbTable {
  zakaznici('zakaznici'),
  operace('operace'),
  materialy('materialy'),
  profily('profily'),
  customerProfiles('customer_profiles');

  const DbTable(this.tableName);
  final String tableName;
}
