import 'dart:convert';

import 'db_service.dart';

enum ResolvedMappingSource {
  explicitCustomerProfile,
  matcherProfile,
  customerHistory,
  defaultProfile,
}

class ResolvedMapping {
  final String? profileUid;
  final Map<String, String> mappings;
  final ResolvedMappingSource source;
  final double confidence;
  final bool isAutoApplied;

  const ResolvedMapping({
    required this.profileUid,
    required this.mappings,
    required this.source,
    required this.confidence,
    required this.isAutoApplied,
  });
}

class MappingProfileResolver {
  final DbService _dbService;

  MappingProfileResolver({DbService? dbService}) : _dbService = dbService ?? DbService();

  Future<ResolvedMapping> resolve({
    String? customerId,
    String? customerProfileUid,
    String? matchedProfileUid,
    required Map<String, String> defaultProfile,
  }) async {
    final normalizedCustomerId = customerId?.trim();
    final normalizedExplicitUid = customerProfileUid?.trim();
    final normalizedMatchedUid = matchedProfileUid?.trim();

    if (normalizedExplicitUid != null && normalizedExplicitUid.isNotEmpty) {
      final explicit = await _dbService.getCustomerProfile(profileUid: normalizedExplicitUid);
      if (explicit != null) {
        return ResolvedMapping(
          profileUid: normalizedExplicitUid,
          mappings: _decodeMappings(explicit['mappings']),
          source: ResolvedMappingSource.explicitCustomerProfile,
          confidence: 1.0,
          isAutoApplied: true,
        );
      }
    }

    if (normalizedMatchedUid != null && normalizedMatchedUid.isNotEmpty) {
      final matched = await _dbService.getCustomerProfile(profileUid: normalizedMatchedUid);
      if (matched != null) {
        return ResolvedMapping(
          profileUid: normalizedMatchedUid,
          mappings: _decodeMappings(matched['mappings']),
          source: ResolvedMappingSource.matcherProfile,
          confidence: 0.9,
          isAutoApplied: true,
        );
      }
    }

    if (normalizedCustomerId != null && normalizedCustomerId.isNotEmpty) {
      final history = await _dbService.getCustomerProfile(customerId: normalizedCustomerId);
      if (history != null) {
        return ResolvedMapping(
          profileUid: history['profile_uid']?.toString(),
          mappings: _decodeMappings(history['mappings']),
          source: ResolvedMappingSource.customerHistory,
          confidence: 0.75,
          isAutoApplied: true,
        );
      }
    }

    return ResolvedMapping(
      profileUid: null,
      mappings: Map<String, String>.from(defaultProfile),
      source: ResolvedMappingSource.defaultProfile,
      confidence: 0.35,
      isAutoApplied: false,
    );
  }

  Map<String, String> _decodeMappings(dynamic raw) {
    if (raw == null) return {};
    if (raw is String) {
      try {
        return Map<String, String>.from(jsonDecode(raw));
      } catch (_) {
        return {};
      }
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return {};
  }
}
