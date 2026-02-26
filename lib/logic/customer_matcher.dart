import 'dart:math';
import 'package:diacritic/diacritic.dart';
import 'package:path/path.dart' as p;
import 'db_service.dart';

enum CustomerMatchConfidence { high, medium, none }

class CustomerMatchResult {
  final Map<String, dynamic>? customer;
  final String? profileUid;
  final Map<String, dynamic>? customerProfile;
  final double confidence;
  final CustomerMatchConfidence level;
  final String matchedOn; // 'IČ', 'alias', 'keywords', 'fuzzy'

  const CustomerMatchResult({
    required this.customer,
    this.profileUid,
    this.customerProfile,
    required this.confidence,
    required this.level,
    required this.matchedOn,
  });
}

class CustomerMatcher {
  static const double _highThreshold = 0.90;
  static const double _medThreshold = 0.70;
  static const double _keywordThreshold = 0.72;

  // České IČ: 6–8 číslic, nesmí sousedit s další číslicí
  static final RegExp _icPattern = RegExp(r'(?<!\d)(\d{6,8})(?!\d)');

  // Právní formy k odebrání před porovnáváním názvů
  static const List<String> _legalSuffixes = [
    's.r.o.', 'spol. s r.o.', 'spol. s r. o.', 'a.s.', 'k.s.', 'v.o.s.',
    's.e.', 'z.s.', 'o.p.s.', ' sro', ' as',
  ];

  /// Hlavní vstupní bod párování.
  Future<CustomerMatchResult> findBestMatch(
    String fileName,
    List<List<String>> previewRows,
    int headerRowIndex,
  ) async {
    // Načtení profilů pro pokročilé párování
    final customerProfiles = await DbService().getCustomerProfiles();
    
    final scanRows = previewRows.sublist(0, min(headerRowIndex, previewRows.length));

    // 1. Přesná shoda přes IČ (nejvyšší priorita)
    final icHit = await _tryIcMatch(scanRows, customerProfiles);
    if (icHit != null) return icHit;

    // 2. Přesná shoda přes Aliasy definované v profilech
    final aliasHit = await _tryAliasMatch(fileName, scanRows, customerProfiles);
    if (aliasHit != null) return aliasHit;

    // 3. Načtení všech základních zákazníků pro fuzzy matching
    final customers = await DbService().getZakaznici(limit: 9999);
    if (customers.isEmpty) {
      return const CustomerMatchResult(
        customer: null,
        confidence: 0.0,
        level: CustomerMatchConfidence.none,
        matchedOn: '',
      );
    }

    // 4. Extrakce textových kandidátů (název souboru + hlavička)
    final candidates = _extractCandidates(fileName, scanRows);
    if (candidates.isEmpty) {
      return const CustomerMatchResult(
        customer: null,
        confidence: 0.0,
        level: CustomerMatchConfidence.none,
        matchedOn: '',
      );
    }

    // 5. Keyword + Fuzzy matching
    double bestScore = 0.0;
    Map<String, dynamic>? bestCustomer;
    Map<String, dynamic>? bestProfile;
    String? bestProfileUid;
    String bestSource = '';

    final normalizedCandidates = candidates.map(_normalize).where((c) => c.length >= 3).toList();

    // A) Kontrola klíčových slov v profilech
    for (final profile in customerProfiles) {
      final profileKeywords = _extractTokens(profile.keywords); // profile je CustomerProfile objekt z DB service
      if (profileKeywords.isEmpty) continue;

      for (int i = 0; i < normalizedCandidates.length; i++) {
        final candidateTokens = normalizedCandidates[i].split(' ').where((t) => t.length > 2).toSet();
        if (candidateTokens.isEmpty) continue;

        final overlap = candidateTokens.intersection(profileKeywords).length;
        if (overlap == 0) continue;

        final keywordScore = (overlap / profileKeywords.length).clamp(0.0, 1.0);
        if (keywordScore > bestScore && keywordScore >= _keywordThreshold) {
          bestScore = keywordScore;
          final pMap = profile.toDbMap();
          bestProfile = pMap;
          bestProfileUid = _readProfileUid(pMap);
          bestSource = '${i == 0 ? 'keywords:file' : 'keywords:header'}/${bestProfileUid ?? 'no_profile'}';
        }
      }
    }

    // B) Standardní fuzzy matching podle názvu
    final profilesAsMaps = customerProfiles.map((p) => p.toDbMap()).toList();
    for (final customer in customers) {
      final nazev = customer['nazev']?.toString() ?? '';
      if (nazev.isEmpty) continue;
      final normNazev = _normalize(nazev);

      for (int i = 0; i < normalizedCandidates.length; i++) {
        final normCand = normalizedCandidates[i];
        final score = _score(normCand, normNazev);
        
        if (score > bestScore) {
          bestScore = score;
          bestCustomer = customer;
          bestProfile = _profileForCustomer(profilesAsMaps, customer);
          bestProfileUid = _readProfileUid(bestProfile);
          bestSource = '${i == 0 ? 'fuzzy:file' : 'fuzzy:header'}/${bestProfileUid ?? 'no_profile'}';
        }
      }
    }

    final level = bestScore >= _highThreshold
        ? CustomerMatchConfidence.high
        : bestScore >= _medThreshold
            ? CustomerMatchConfidence.medium
            : CustomerMatchConfidence.none;

    // Pokud jsme našli profil, ale nemáme zákazníka (u keyword match), zkusíme ho dohledat
    if (bestCustomer == null && bestProfile != null) {
      bestCustomer = await _customerForProfile(bestProfile);
    }

    return CustomerMatchResult(
      customer: bestScore >= _medThreshold ? bestCustomer : null,
      profileUid: bestScore >= _medThreshold ? bestProfileUid : null,
      customerProfile: bestScore >= _medThreshold ? bestProfile : null,
      confidence: bestScore,
      level: level,
      matchedOn: bestSource,
    );
  }

  // ---------------------------------------------------------------------------
  //  SOUKROMÉ METODY
  // ---------------------------------------------------------------------------

  Future<CustomerMatchResult?> _tryIcMatch(
    List<List<String>> rows,
    dynamic customerProfiles, // List<CustomerProfile>
  ) async {
    final List<Map<String, dynamic>> profiles = (customerProfiles as Iterable).map((p) => p.toDbMap() as Map<String, dynamic>).toList();

    for (final row in rows) {
      for (final cell in row) {
        final clean = cell.replaceAll(RegExp(r'[\s\-/]'), '');
        final match = _icPattern.firstMatch(clean);
        if (match == null) continue;
        final ic = match.group(1)!;
        
        final hits = await DbService().getZakaznici(query: ic, limit: 1);
        if (hits.isNotEmpty) {
          final profile = _profileForIc(profiles, ic);
          final profileUid = _readProfileUid(profile);
          
          return CustomerMatchResult(
            customer: hits.first,
            profileUid: profileUid,
            customerProfile: profile,
            confidence: 1.0,
            level: CustomerMatchConfidence.high,
            matchedOn: 'IČ/${profileUid ?? 'no_profile'}',
          );
        }
      }
    }
    return null;
  }

  Future<CustomerMatchResult?> _tryAliasMatch(
    String fileName,
    List<List<String>> rows,
    dynamic customerProfiles, // List<CustomerProfile>
  ) async {
    final List<Map<String, dynamic>> profiles = (customerProfiles as Iterable).map((p) => p.toDbMap() as Map<String, dynamic>).toList();
    if (profiles.isEmpty) return null;

    final candidates = _extractCandidates(fileName, rows);
    final normalizedCandidates = candidates.map(_normalize).where((c) => c.length >= 3).toList();
    if (normalizedCandidates.isEmpty) return null;

    for (final profile in profiles) {
      final aliases = _extractTokens(profile['aliases']);
      if (aliases.isEmpty) continue;

      for (final candidate in normalizedCandidates) {
        if (aliases.any((alias) => candidate.contains(alias) || alias.contains(candidate))) {
          final customer = await _customerForProfile(profile);
          final profileUid = _readProfileUid(profile);
          
          return CustomerMatchResult(
            customer: customer,
            profileUid: profileUid,
            customerProfile: profile,
            confidence: 0.95,
            level: CustomerMatchConfidence.high,
            matchedOn: 'alias/${profileUid ?? 'no_profile'}',
          );
        }
      }
    }
    return null;
  }

  Set<String> _extractTokens(dynamic raw) {
    if (raw == null) return {};
    final source = raw.toString();
    if (source.isEmpty) return {};
    
    return source
        .split(RegExp(r'[,;|\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(_normalize)
        .where((token) => token.length >= 3)
        .toSet();
  }

  String? _readProfileUid(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final uid = profile['profile_uid'] ?? profile['profileUid'] ?? profile['id'];
    final value = uid?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Map<String, dynamic>? _profileForIc(List<Map<String, dynamic>> profiles, String ic) {
    final normalizedIc = ic.trim();
    if (normalizedIc.isEmpty) return null;
    for (final profile in profiles) {
      final profileIc = profile['ico']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
      if (profileIc == normalizedIc) return profile;
    }
    return null;
  }

  Map<String, dynamic>? _profileForCustomer(
    List<Map<String, dynamic>> profiles,
    Map<String, dynamic> customer,
  ) {
    final customerId = customer['id']?.toString();
    final customerIc = customer['ic']?.toString().replaceAll(RegExp(r'\D'), '');
    
    for (final profile in profiles) {
      final profileCustomerId = profile['customer_id']?.toString();
      if (customerId != null && profileCustomerId == customerId) return profile;

      final profileIc = profile['ico']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
      if (customerIc != null && customerIc.isNotEmpty && profileIc == customerIc) return profile;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _customerForProfile(Map<String, dynamic> profile) async {
    final customerId = profile['customer_id'];
    if (customerId != null) {
      // Předpokládáme existenci metody getZakaznikById v DbService
      final hits = await DbService().getZakaznici(query: '', limit: 1); // fallback pokud nemáme přímé ID hledání
      final db = await DbService().database;
      final res = await db.query('zakaznici', where: 'id = ?', whereArgs: [customerId], limit: 1);
      if (res.isNotEmpty) return res.first;
    }

    final ic = profile['ico']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
    if (ic.isNotEmpty) {
      final hits = await DbService().getZakaznici(query: ic, limit: 1);
      if (hits.isNotEmpty) return hits.first;
    }

    final displayName = profile['display_name']?.toString() ?? '';
    if (displayName.isNotEmpty) {
      final hits = await DbService().getZakaznici(query: displayName, limit: 1);
      if (hits.isNotEmpty) return hits.first;
    }
    return null;
  }

  List<String> _extractCandidates(String fileName, List<List<String>> rows) {
    final result = <String>[];

    final base = p.basenameWithoutExtension(fileName)
        .replaceAll(RegExp(r'\d{4,}'), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
    if (base.length > 3) result.add(base);

    for (final row in rows) {
      for (final cell in row) {
        final t = cell.trim();
        if (t.length >= 4 && t.length <= 80 && !_skipCell(t)) {
          result.add(t);
        }
      }
    }
    return result;
  }

  bool _skipCell(String v) {
    if (double.tryParse(v) != null) return true;
    if (v.contains('@') || v.contains('://')) return true;
    if (RegExp(r'^\d{1,2}[./\-]\d{1,2}[./\-]\d{2,4}$').hasMatch(v)) return true;
    return false;
  }

  String _normalize(String s) {
    String t = removeDiacritics(s).toLowerCase();
    for (final suf in _legalSuffixes) {
      t = t.replaceAll(suf, '');
    }
    return t
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _score(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    if (b.contains(a) || a.contains(b)) {
      return 0.72 + 0.28 * (min(a.length, b.length) / max(a.length, b.length));
    }

    final ta = a.split(' ').where((s) => s.length > 1).toSet();
    final tb = b.split(' ').where((s) => s.length > 1).toSet();
    if (ta.isNotEmpty && tb.isNotEmpty) {
      final ts = ta.intersection(tb).length / ta.union(tb).length;
      if (ts >= 0.5) return ts;
    }

    return _jaroWinkler(a, b);
  }

  double _jaroWinkler(String s1, String s2) {
    final n = s1.length, m = s2.length;
    if (n == 0 || m == 0) return 0.0;
    final range = max(0, max(n, m) ~/ 2 - 1);
    final m1 = List.filled(n, false), m2 = List.filled(m, false);
    int matches = 0;
    for (int i = 0; i < n; i++) {
      for (int j = max(0, i - range); j < min(i + range + 1, m); j++) {
        if (!m2[j] && s1[i] == s2[j]) {
          m1[i] = m2[j] = true;
          matches++;
          break;
        }
      }
    }
    if (matches == 0) return 0.0;
    double t = 0;
    int k = 0;
    for (int i = 0; i < n; i++) {
      if (m1[i]) {
        while (!m2[k]) { k++; }
        if (s1[i] != s2[k]) { t++; }
        k++;
      }
    }
    final jaro = (matches / n + matches / m + (matches - t / 2) / matches) / 3;
    int pref = 0;
    for (int i = 0; i < min(4, min(n, m)); i++) {
      if (s1[i] == s2[i]) { pref++; } else { break; }
    }
    return jaro + pref * 0.1 * (1 - jaro);
  }
}