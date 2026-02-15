import 'dart:math';
import 'package:diacritic/diacritic.dart'; // Nutné: flutter pub add diacritic

/// Úrovně důvěryhodnosti pro vizuální indikaci v UI
enum MappingConfidence { high, medium, low, none }

/// Výsledek extrakce PN a popisu z jednoho řetězce
class ExtractionResult {
  final String? partNumber;
  final String cleanDescription;
  ExtractionResult({this.partNumber, required this.cleanDescription});
}

/// Výsledek mapování systémového pole na sloupec Excelu
class MappingMatch {
  final String systemField;
  final String? excelColumn;
  final double confidence;
  final MappingConfidence level;

  MappingMatch({
    required this.systemField,
    this.excelColumn,
    required this.confidence,
    required this.level,
  });
}

class _PotentialMatch {
  final String systemField;
  final String excelColumn;
  final double score;
  _PotentialMatch(this.systemField, this.excelColumn, this.score);
}

class SmartMappingEngine {
  static const String version = "2.4.0-ULTRA-CONTENT";

  // --- KONFIGURACE ---
  static const double kMinAcceptableScore = 0.70;
  static const double kRobustMargin = 0.15;
  static const double kHeuristicWeight = 0.40; // Váha, kterou dáváme obsahu dat (40%)

  // Slovník synonym
  final Map<String, List<String>> _dictionary = {
    'part_number': ['cislo', 'vykres', 'oznaceni', 'drawing', 'art nr', 'pn', 'id', 'item', 'kod', 'pozice'],
    'name': ['nazev', 'popis', 'description', 'tovar', 'polozka', 'nazev dilu', 'specifikace'],
    'quantity': ['ks', 'mnozstvi', 'pocet', 'qty', 'quantity', 'count', 'mnoz'],
    'material': ['material', 'jakost', 'grade', 'steel', 'norma', 'provedeni', 'typ', 'jak'],
    'thickness': ['tloustka', 'thickness', 'th', 'tl', 'rozmer', 's', 'tl'],
  };

  // VÁŠ PRINCIP: Pattern Detection (RegExp)
  final Map<String, RegExp> _contentPatterns = {
    'part_number': RegExp(r'^[a-zA-Z0-9/_-]{6,}$'), // PN: 6+ znaků, technické symboly
    'quantity': RegExp(r'^\d+(\s?ks)?$'),           // Qty: Číslo, volitelně "ks"
    'thickness': RegExp(r'^\d{1,2}([,.]\d+)?$'),    // Thick: Krátké číslo/desetinné
    'material': RegExp(r'(s235|s355|11\s?373|11\s?523|nerez|hlinik|alu|dc01)', caseSensitive: false),
  };

  // ===========================================================================
  //  1. POKROČILÁ NORMALIZACE
  // ===========================================================================
  
  String normalize(String input) {
    if (input.isEmpty) return "";
    String text = removeDiacritics(input).toLowerCase();
    text = text.replaceAll(RegExp(r'\b(ks|kus|kusy|kusu)\b'), 'ks');
    text = text.replaceAll(RegExp(r'\b(metru|metr|m)\b'), 'm');
    text = text.replaceFirst(RegExp(r'^(pozice|polozka|cislo|vykres|dil|pos|art|nr)[:.\-\s]+'), '');
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ===========================================================================
  //  2. KOMBINACE METRIK PODOBNOSTI (Fuzzy Matching)
  // ===========================================================================

  double _calculateSimilarity(String source, String target) {
    final String s1 = normalize(source);
    final String s2 = normalize(target);
    
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    int levDist = _levenshtein(s1, s2);
    double levScore = 1.0 - (levDist / max(s1.length, s2.length));
    double jaroScore = _jaroWinkler(s1, s2);
    double tokenScore = _tokenSimilarity(s1, s2);

    return (levScore * 0.2) + (jaroScore * 0.5) + (tokenScore * 0.3);
  }

  // ===========================================================================
  //  3. STATISTICKÁ HEURISTIKA (Column Sampling) - NOVÉ!
  // ===========================================================================

  double _calculateContentScore(String field, List<String> samples) {
    if (samples.isEmpty) return 0.0;
    
    // Získáme pouze neprázdné hodnoty pro analýzu
    List<String> validSamples = samples.where((s) => s.trim().isNotEmpty).toList();
    if (validSamples.isEmpty) return 0.0;

    int matches = 0;
    RegExp? pattern = _contentPatterns[field];
    
    for (var val in validSamples) {
      String cleanVal = val.trim();

      // 1. Kontrola přes RegExp (Váš Pattern Detection)
      if (pattern != null && pattern.hasMatch(cleanVal)) {
        matches++;
      } 
      // 2. Kontrola pro Quantity (Čistě číselná heuristika, pokud selže regex)
      else if (field == 'quantity') {
         // Akceptujeme "10", "10,5", "10.5"
         if (double.tryParse(cleanVal.replaceAll(',', '.')) != null) {
           matches++;
         }
      }
    }

    double ratio = matches / validSamples.length;

    // VÁŠ PRINCIP: Pokud 80 % hodnot odpovídá, je to silný signál
    if (ratio >= 0.8) return 1.0; 
    if (ratio >= 0.5) return 0.6;
    return ratio * 0.5; // Penazilace za nízkou shodu
  }

  // ===========================================================================
  //  4. FINÁLNÍ ANALÝZA (Weighted Average + Robust Decision)
  // ===========================================================================

  List<MappingMatch> analyzeHeadersWithData(List<String> headers, List<List<String>> dataPreview) {
    // 1. Příprava vzorků dat (Column Sampling)
    // Pro každý sloupec vytáhneme data ze všech řádků preview
    Map<int, List<String>> colSamples = {};
    for (int i = 0; i < headers.length; i++) {
      colSamples[i] = dataPreview.map((row) => i < row.length ? row[i] : "").toList();
    }

    List<MappingMatch> bestCandidatesPerField = [];

    // 2. Iterace přes systémová pole
    for (var systemField in _dictionary.keys) {
      List<_PotentialMatch> candidates = [];

      for (int i = 0; i < headers.length; i++) {
        String header = headers[i].trim();
        if (header.isEmpty) continue;

        // A) Fuzzy Matching (Název sloupce)
        double fuzzyScore = 0.0;
        for (var syn in _dictionary[systemField]!) {
          fuzzyScore = max(fuzzyScore, _calculateSimilarity(header, syn));
        }

        // B) Heuristika obsahu (Sampling)
        double contentScore = _calculateContentScore(systemField, colSamples[i]!);

        // C) Kombinované skóre (Weighted Average)
        // 60% váha názvu sloupce, 40% váha obsahu
        double totalScore = (fuzzyScore * (1 - kHeuristicWeight)) + (contentScore * kHeuristicWeight);

        candidates.add(_PotentialMatch(systemField, header, totalScore.clamp(0.0, 1.0)));
      }

      // Seřadíme kandidáty od nejlepšího
      candidates.sort((a, b) => b.score.compareTo(a.score));

      if (candidates.isNotEmpty) {
        var best = candidates[0];
        var secondBestScore = candidates.length > 1 ? candidates[1].score : 0.0;

        // Robustní rozhodnutí (Margin check)
        // Musí mít min 0.70 skóre a náskok 0.15 nad druhým
        bool isRobust = best.score >= kMinAcceptableScore && (best.score - secondBestScore) >= kRobustMargin;

        // Pokud je skóre příliš nízké, vůbec to nebereme (nebo s velmi nízkou důvěrou)
        MappingConfidence level;
        if (isRobust) {
          level = MappingConfidence.high;
        } else if (best.score >= 0.5) {
          level = MappingConfidence.medium;
        } else {
          level = MappingConfidence.low;
        }

        // Přidáme do seznamu potenciálních vítězů (kolize řešíme níže)
        if (best.score > 0.1) { // Ignorujeme naprosté nesmysly
             bestCandidatesPerField.add(MappingMatch(
              systemField: systemField,
              excelColumn: best.excelColumn,
              confidence: best.score,
              level: level,
            ));
        }
      }
    }

    // 3. Řešení kolizí (Conflict Resolution)
    // Pokud 'name' a 'description' oba chtějí sloupec "Popis", vyhraje ten s vyšším skóre.
    bestCandidatesPerField.sort((a, b) => b.confidence.compareTo(a.confidence));

    Map<String, MappingMatch> finalMappings = {};
    Set<String> usedExcelHeaders = {};

    for (var match in bestCandidatesPerField) {
      if (match.excelColumn != null && !usedExcelHeaders.contains(match.excelColumn)) {
        finalMappings[match.systemField] = match;
        usedExcelHeaders.add(match.excelColumn!);
      }
    }

    // 4. Sestavení finálního výstupu (doplnění nenalezených polí)
    return _dictionary.keys.map((field) {
      return finalMappings[field] ?? MappingMatch(
        systemField: field, 
        excelColumn: null, 
        confidence: 0.0, 
        level: MappingConfidence.none
      );
    }).toList();
  }

  // ===========================================================================
  //  HELPER METODY (Levenshtein, Jaro-Winkler, Token)
  // ===========================================================================

  int _levenshtein(String s, String t) {
    final m = s.length;
    final n = t.length;
    List<List<int>> dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        int cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[m][n];
  }

  double _tokenSimilarity(String a, String b) {
    final setA = a.split(' ').where((s) => s.isNotEmpty).toSet();
    final setB = b.split(' ').where((s) => s.isNotEmpty).toSet();
    if (setA.isEmpty || setB.isEmpty) return 0.0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return intersection / union;
  }

  double _jaroWinkler(String s1, String s2) {
    int m = 0;
    int s1Len = s1.length;
    int s2Len = s2.length;
    int range = (max(s1Len, s2Len) ~/ 2) - 1;
    List<bool> s1Matches = List.filled(s1Len, false);
    List<bool> s2Matches = List.filled(s2Len, false);

    for (int i = 0; i < s1Len; i++) {
      int start = max(0, i - range);
      int end = min(i + range + 1, s2Len);
      for (int j = start; j < end; j++) {
        if (!s2Matches[j] && s1[i] == s2[j]) {
          s1Matches[i] = true; s2Matches[j] = true;
          m++; break;
        }
      }
    }
    if (m == 0) return 0.0;
    double t = 0; int k = 0;
    for (int i = 0; i < s1Len; i++) {
      if (s1Matches[i]) {
        while (!s2Matches[k]) {
          k++;
        }
        if (s1[i] != s2[k]) t++;
        k++;
      }
    }
    double jaro = (m / s1Len + m / s2Len + (m - t / 2) / m) / 3;
    int prefixLen = 0;
    for (int i = 0; i < min(4, min(s1Len, s2Len)); i++) {
      if (s1[i] == s2[i]) {
        prefixLen++;
      } else {
        break;
      }
    }
    return jaro + (prefixLen * 0.1 * (1 - jaro));
  }

  ExtractionResult extractTechnicalData(String input) {
    if (input.isEmpty) return ExtractionResult(cleanDescription: "");
    final RegExp pnRegex = RegExp(r'(?<=^|\s)([a-zA-Z0-9/_-]{6,})');
    final match = pnRegex.firstMatch(input);
    if (match != null) {
      String foundPn = match.group(0)!;
      String cleanDesc = input.replaceFirst(foundPn, "").replaceAll(RegExp(r'\s+'), ' ').trim();
      return ExtractionResult(partNumber: foundPn, cleanDescription: cleanDesc);
    }
    return ExtractionResult(cleanDescription: input);
  }
}