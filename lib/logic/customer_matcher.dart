import 'dart:math';
import 'package:diacritic/diacritic.dart';
import 'package:path/path.dart' as p;
import 'db_service.dart';

enum CustomerMatchConfidence { high, medium, none }

class CustomerMatchResult {
  final Map<String, dynamic>? customer;
  final double confidence;
  final CustomerMatchConfidence level;
  final String matchedOn; // 'IČ', 'název souboru', 'obsah souboru'

  const CustomerMatchResult({
    required this.customer,
    required this.confidence,
    required this.level,
    required this.matchedOn,
  });
}

class CustomerMatcher {
  static const double _highThreshold = 0.85;
  static const double _medThreshold = 0.60;

  // České IČ: 6–8 číslic, nesmí sousedit s další číslicí
  static final RegExp _icPattern = RegExp(r'(?<!\d)(\d{6,8})(?!\d)');

  // Právní formy k odebrání před porovnáváním názvů
  static const List<String> _legalSuffixes = [
    's.r.o.', 'spol. s r.o.', 'spol. s r. o.', 'a.s.', 'k.s.', 'v.o.s.',
    's.e.', 'z.s.', 'o.p.s.', ' sro', ' as',
  ];

  /// Hlavní vstupní bod.
  /// [fileName]       – název souboru (bez cesty)
  /// [previewRows]    – výstup z HeaderDetectionResult.previewRows
  /// [headerRowIndex] – index řádku záhlaví; prohledáváme pouze řádky NAD ním
  Future<CustomerMatchResult> findBestMatch(
    String fileName,
    List<List<String>> previewRows,
    int headerRowIndex,
  ) async {
    final scanRows = previewRows.sublist(0, min(headerRowIndex, previewRows.length));

    // 1. Přesná shoda přes IČ (prioritní)
    final icHit = await _tryIcMatch(scanRows);
    if (icHit != null) return icHit;

    // 2. Načtení všech zákazníků pro fuzzy matching
    final customers = await DbService().getZakaznici(limit: 9999);
    if (customers.isEmpty) {
      return const CustomerMatchResult(
        customer: null, confidence: 0.0,
        level: CustomerMatchConfidence.none, matchedOn: '',
      );
    }

    // 3. Extrakce textových kandidátů
    final candidates = _extractCandidates(fileName, scanRows);
    if (candidates.isEmpty) {
      return const CustomerMatchResult(
        customer: null, confidence: 0.0,
        level: CustomerMatchConfidence.none, matchedOn: '',
      );
    }

    // 4. Fuzzy matching
    double bestScore = 0.0;
    Map<String, dynamic>? bestCustomer;
    String bestSource = '';

    for (final customer in customers) {
      final nazev = customer['nazev']?.toString() ?? '';
      if (nazev.isEmpty) continue;
      final normNazev = _normalize(nazev);

      for (int i = 0; i < candidates.length; i++) {
        final normCand = _normalize(candidates[i]);
        if (normCand.length < 3) continue;
        final score = _score(normCand, normNazev);
        if (score > bestScore) {
          bestScore = score;
          bestCustomer = customer;
          bestSource = i == 0 ? 'název souboru' : 'obsah souboru';
        }
      }
    }

    final level = bestScore >= _highThreshold
        ? CustomerMatchConfidence.high
        : bestScore >= _medThreshold
            ? CustomerMatchConfidence.medium
            : CustomerMatchConfidence.none;

    return CustomerMatchResult(
      customer: bestScore >= _medThreshold ? bestCustomer : null,
      confidence: bestScore,
      level: level,
      matchedOn: bestSource,
    );
  }

  // ---------------------------------------------------------------------------
  //  SOUKROMÉ METODY
  // ---------------------------------------------------------------------------

  Future<CustomerMatchResult?> _tryIcMatch(List<List<String>> rows) async {
    for (final row in rows) {
      for (final cell in row) {
        final clean = cell.replaceAll(RegExp(r'[\s\-/]'), '');
        final match = _icPattern.firstMatch(clean);
        if (match == null) continue;
        final ic = match.group(1)!;
        final hits = await DbService().getZakaznici(query: ic, limit: 1);
        if (hits.isNotEmpty) {
          return CustomerMatchResult(
            customer: hits.first,
            confidence: 1.0,
            level: CustomerMatchConfidence.high,
            matchedOn: 'IČ',
          );
        }
      }
    }
    return null;
  }

  List<String> _extractCandidates(String fileName, List<List<String>> rows) {
    final result = <String>[];

    // Z názvu souboru: odstraníme čísla, extension, oddělovače
    final base = p.basenameWithoutExtension(fileName)
        .replaceAll(RegExp(r'\d{4,}'), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
    if (base.length > 3) result.add(base);

    // Z obsahu horních řádků
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
    // Datum: dd.mm.rrrr nebo varianty
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

    // Containment: kratší je podřetězcem delšího
    if (b.contains(a) || a.contains(b)) {
      return 0.72 + 0.28 * (min(a.length, b.length) / max(a.length, b.length));
    }

    // Token overlap (Jaccard)
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
