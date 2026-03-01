enum CustomerKeyType {
  externiId('ext'),
  ic('ic'),
  nazev('name');

  const CustomerKeyType(this.prefix);
  final String prefix;

  String format(String value) => '$prefix:$value';
}
