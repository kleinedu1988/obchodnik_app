import 'package:excel/excel.dart';
import 'dart:math';

/// Třída pro reprezentaci sloučené oblasti (nyní veřejná)
class ExcelSpan {
  final int rowStart;
  final int rowEnd;
  final int colStart;
  final int colEnd;

  ExcelSpan(this.rowStart, this.rowEnd, this.colStart, this.colEnd);

  /// Zjistí, zda se daná buňka [r, c] nachází v této oblasti
  bool contains(int r, int c) {
    return r >= rowStart && r <= rowEnd && c >= colStart && c <= colEnd;
  }
}

/// Přepravka pro výsledek detekce
class HeaderDetectionResult {
  final int headerRowIndex;
  final List<String> cleanedHeaders;
  final List<List<String>> previewRows;
  final List<ExcelSpan> knownSpans;
  final List<double> rowScores;

  HeaderDetectionResult({
    required this.headerRowIndex,
    required this.cleanedHeaders,
    required this.previewRows,
    required this.knownSpans,
    required this.rowScores,
  });

  /// Vypočítá důvěryhodnost (0.0 - 1.0) pro konkrétní řádek.
  /// Slouží pro vizualizaci (Červená -> Oranžová -> Zelená).
  double getConfidence(int rowIndex) {
    if (rowScores.isEmpty || rowIndex < 0 || rowIndex >= rowScores.length) return 0.0;
    
    double score = rowScores[rowIndex];
    if (score <= 0) return 0.0;

    // Normalizace:
    // 1. Najdeme nejvyšší dosažené skóre v dokumentu.
    // 2. Stanovíme "Baseline" (práh solidní hlavičky), např. 20.0 bodů.
    //    (20 bodů = cca 4-5 perfektních klíčových slov).
    // 3. Pokud je max skóre v dokumentu nízké (např. 5), tak i "vítěz" bude mít nízkou confidence (červená),
    //    což je správně - varujeme uživatele, že to asi není ono.
    
    double maxFound = rowScores.reduce(max);
    double baseline = max(maxFound, 20.0); 
    
    return (score / baseline).clamp(0.0, 1.0);
  }

  /// Vrátí indexy řádků s nejvyšším skóre (pro rychlý výběr v UI)
  /// Řeší problém "praktického výběru" bez nutnosti scrollování.
  List<int> getTopCandidates({int count = 3}) {
    // Vytvoříme seznam párů [index, score]
    List<MapEntry<int, double>> indexedScores = [];
    for (int i = 0; i < rowScores.length; i++) {
      indexedScores.add(MapEntry(i, rowScores[i]));
    }
    
    // Seřadíme sestupně podle skóre
    indexedScores.sort((a, b) => b.value.compareTo(a.value));
    
    // Vrátíme top N indexů (filtrováno na kladné skóre)
    return indexedScores
        .where((e) => e.value > 0)
        .take(count)
        .map((e) => e.key)
        .toList();
  }
}

class ExcelHeaderDetector {
  static const double wText = 2.0;
  static const double wEmpty = -0.5;
  static const double wNumber = -2.0;
  static const double wKeyword = 4.0; // Bonus za typický název sloupce

  // Typické názvy sloupců v průmyslových objednávkách (CZ + EN)
  static const List<String> _defaultKeywords = [
    'poz', 'pozice', 'číslo', 'číslo dílu', 'kód', 'č',
    'název', 'popis', 'díl', 'název dílu',
    'ks', 'množství', 'počet', 'qty', 'quantity',
    'materiál', 'material', 'mat',
    'tloušťka', 'tl', 'tl.', 'thickness', 'th',
    'hmotnost', 'hmot', 'weight',
    'part', 'part number', 'part no', 'part no.', 'p/n',
    'name', 'description', 'desc',
    'no', 'no.', '#', 'item',
    'poznámka', 'note', 'notes',
    'délka', 'šířka', 'výška', 'length', 'width', 'height',
  ];

  HeaderDetectionResult analyze(Sheet sheet, {int scanLimit = 50, List<String>? customKeywords}) {
    int bestIndex = 0;
    double maxScore = -double.infinity;
    int rowsToScan = min(sheet.rows.length, scanLimit);

    // 1. NAČTENÍ A PARSOVÁNÍ SPOJENÝCH BUNĚK
    List<ExcelSpan> parsedSpans = _parseSpans(sheet);

    // 2. PŘEDZPRACOVÁNÍ — DVA ODDĚLENÉ VÝSTUPY
    //
    // scoreRows   = surové hodnoty BEZ propagace spanů  → pro SKÓROVÁNÍ
    //              (sloučená buňka = hodnota pouze v master pozici)
    // resolvedRows = s propagací spanů                  → pro ZOBRAZENÍ v UI
    //
    // BEZ tohoto oddělení titulek přes 8 sloupců ("OBJEDNÁVKA...")
    // získá 8× wText = +16.0 a přebije skutečné záhlaví sloupců (+10.0).

    List<List<String>> scoreRows = [];
    List<List<String>> resolvedRows = [];
    List<double> calculatedScores = [];

    // Použijeme buď vlastní klíčová slova z profilu, nebo defaultní sadu
    final keywords = customKeywords ?? _defaultKeywords;

    for (int r = 0; r < rowsToScan; r++) {
      if (r >= sheet.rows.length) {
        scoreRows.add([]);
        resolvedRows.add([]);
        continue;
      }

      final rowData = sheet.rows[r];
      List<String> rawRow = [];
      List<String> resolvedRow = [];

      for (int c = 0; c < rowData.length; c++) {
        // scoreRows: pouze surová hodnota (merge-slave buňky zůstávají prázdné)
        final cell = rowData[c];
        rawRow.add(cell?.value?.toString() ?? "");

        // resolvedRows: s propagací spanů (pro UI preview)
        resolvedRow.add(_getEffectiveCellValue(sheet, r, c, parsedSpans));
      }

      scoreRows.add(rawRow);
      resolvedRows.add(resolvedRow);
    }

    // 3. ANALÝZA SKÓRE (používáme scoreRows, ne resolvedRows)
    for (int i = 0; i < scoreRows.length; i++) {
      final row = scoreRows[i];
      double score = 0.0;
      int filledCount = 0;

      for (var val in row) {
        if (val.isEmpty) {
          score += wEmpty;
          continue;
        }
        filledCount++;
        if (_isNumberString(val)) {
          score += wNumber;
        } else {
          score += wText;
        }
      }

      if (filledCount < 2) score -= 10.0;

      // Bonus: shoda s typickými názvy sloupců objednávky/nabídky
      score += _keywordBonus(row, keywords);

      // Look-ahead: pokud NÁSLEDUJÍCÍ řádek vypadá jako datový (hodně čísel),
      // pak AKTUÁLNÍ řádek je pravděpodobně záhlaví → bonus
      if (i + 1 < scoreRows.length) {
        score += _lookAheadBonus(scoreRows[i + 1]);
      }

      calculatedScores.add(score);

      if (score > maxScore) {
        maxScore = score;
        bestIndex = i;
      }
    }

    // 4. VÝSTUP — headers bereme z resolvedRows (správná hodnota sloučených buněk)
    List<String> detectedHeaders = [];
    if (resolvedRows.isNotEmpty && bestIndex < resolvedRows.length) {
      detectedHeaders = resolvedRows[bestIndex]
          .map((s) => s.replaceAll('\n', ' ').trim())
          .toList();
    }

    return HeaderDetectionResult(
      headerRowIndex: bestIndex,
      cleanedHeaders: detectedHeaders,
      previewRows: resolvedRows,
      knownSpans: parsedSpans,
      rowScores: calculatedScores,
    );
  }

  // --- POMOCNÉ METODY ---

  List<ExcelSpan> _parseSpans(Sheet sheet) {
    List<ExcelSpan> spans = [];
    for (var spanString in sheet.spannedItems) {
      try {
        final parts = spanString.split(':');
        if (parts.length == 2) {
          final start = CellIndex.indexByString(parts[0]);
          final end = CellIndex.indexByString(parts[1]);
          spans.add(ExcelSpan(
            start.rowIndex, end.rowIndex,
            start.columnIndex, end.columnIndex,
          ));
        }
      } catch (e) {
        print("Error parsing span: $e");
      }
    }
    return spans;
  }

  String _getEffectiveCellValue(Sheet sheet, int rowIndex, int colIndex, List<ExcelSpan> spans) {
    var cellValue = "";
    if (rowIndex < sheet.rows.length && colIndex < sheet.rows[rowIndex].length) {
      final cell = sheet.rows[rowIndex][colIndex];
      cellValue = cell?.value?.toString() ?? "";
    }

    if (cellValue.isNotEmpty) return cellValue;

    for (var span in spans) {
      if (span.contains(rowIndex, colIndex)) {
        final masterRow = span.rowStart;
        final masterCol = span.colStart;

        if (masterRow == rowIndex && masterCol == colIndex) return "";

        if (masterRow < sheet.rows.length && masterCol < sheet.rows[masterRow].length) {
          return sheet.rows[masterRow][masterCol]?.value?.toString() ?? "";
        }
      }
    }
    return "";
  }

  /// Bonus za shodu s typickými názvy sloupců průmyslové objednávky.
  /// Aktivuje se pouze při ≥2 shodách (ochrana před náhodnou shodou).
  double _keywordBonus(List<String> row, List<String> keywords) {
    int matches = 0;
    for (var val in row) {
      final lower = val.toLowerCase().trim();
      if (lower.isEmpty) continue;
      for (var kw in keywords) {
        if (lower == kw ||
            lower.startsWith('$kw ') ||
            lower.startsWith('$kw.') ||
            lower.startsWith('$kw/') ||
            lower.startsWith('$kw(')) {
          matches++;
          break;
        }
      }
    }
    return matches >= 2 ? matches * wKeyword : 0.0;
  }

  /// Look-ahead: pokud NÁSLEDUJÍCÍ řádek vypadá jako datový (>50 % čísel),
  /// pak AKTUÁLNÍ řádek pravděpodobně záhlaví → bonus +5.0.
  double _lookAheadBonus(List<String> nextRow) {
    int numbers = 0;
    int filled = 0;
    for (var val in nextRow) {
      if (val.isEmpty) continue;
      filled++;
      if (_isNumberString(val)) numbers++;
    }
    if (filled == 0) return 0.0;
    return (numbers / filled) > 0.5 ? 5.0 : 0.0;
  }

  bool _isNumberString(String value) {
    if (value.isEmpty) return false;
    return double.tryParse(value) != null;
  }
}
