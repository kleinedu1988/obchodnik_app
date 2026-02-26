import 'dart:convert';

class CustomerProfile {
  final int? id;
  final int customerId;
  final String profileUid;
  final String displayName;
  final String ico;
  final List<String> aliases;
  final List<String> keywords;
  final String notes;
  final Map<String, String> mappings;

  const CustomerProfile({
    this.id,
    required this.customerId,
    required this.profileUid,
    required this.displayName,
    this.ico = '',
    this.aliases = const [],
    this.keywords = const [],
    this.notes = '',
    this.mappings = const {},
  });

  int get patternCount => aliases.length + keywords.length + (ico.isNotEmpty ? 1 : 0);

  CustomerProfile copyWith({
    int? id,
    int? customerId,
    String? profileUid,
    String? displayName,
    String? ico,
    List<String>? aliases,
    List<String>? keywords,
    String? notes,
    Map<String, String>? mappings,
  }) {
    return CustomerProfile(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      profileUid: profileUid ?? this.profileUid,
      displayName: displayName ?? this.displayName,
      ico: ico ?? this.ico,
      aliases: aliases ?? this.aliases,
      keywords: keywords ?? this.keywords,
      notes: notes ?? this.notes,
      mappings: mappings ?? this.mappings,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'profile_uid': profileUid,
      'display_name': displayName,
      'ico': ico,
      'aliases': jsonEncode(aliases),
      'keywords': jsonEncode(keywords),
      'notes': notes,
      'mappings': jsonEncode(mappings),
    };
  }

  factory CustomerProfile.fromDbMap(Map<String, dynamic> map) {
    return CustomerProfile(
      id: map['id'] as int?,
      customerId: (map['customer_id'] as num).toInt(),
      profileUid: map['profile_uid']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? '',
      ico: map['ico']?.toString() ?? '',
      aliases: _parseStringList(map['aliases']),
      keywords: _parseStringList(map['keywords']),
      notes: map['notes']?.toString() ?? '',
      mappings: _parseStringMap(map['mappings']),
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is List) {
        return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {
      return raw
          .toString()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const [];
  }

  static Map<String, String> _parseStringMap(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return const {};

    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
      }
    } catch (_) {
      return const {};
    }

    return const {};
  }
}