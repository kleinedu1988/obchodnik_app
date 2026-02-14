import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// =============================================================
//  Kategorizace + metadata (pro UI checklist / staging)
// =============================================================

// Pozn.: archive tu nechávám kvůli UI souhrnu, ale po SMART UNPACK
// se do finálního result.files standardně už nedává (archiv „nefiguruje“).
enum FileCategory { data, drawing, cad, assets, archive, unknown }

class ProcessedFile {
  final String path;       // plná cesta (TEMP session path)
  final String name;       // basename
  final String ext;        // ".pdf"
  final FileCategory category;

  const ProcessedFile({
    required this.path,
    required this.name,
    required this.ext,
    required this.category,
  });

  File get asFile => File(path);
}

// =============================================================
//  Výsledek ingesce (kanonický seznam + kompatibilní listy File)
// =============================================================

class IngestionResult {
  /// Hlavní kanonický seznam (kategorizované položky)
  final List<ProcessedFile> files;

  /// Kompatibilní listy
  final List<File> dataFiles;
  final List<File> drawings;
  final List<File> cadFiles;
  final List<File> archives; // původní archivní soubory (volitelné logování)
  final List<File> assets;

  final int ignoredCount;

  IngestionResult({
    required this.files,
    required this.dataFiles,
    required this.drawings,
    required this.cadFiles,
    required this.archives,
    required this.assets,
    this.ignoredCount = 0,
  });

  int get dataCount => files.where((f) => f.category == FileCategory.data).length;
  int get drawingCount => files.where((f) => f.category == FileCategory.drawing).length;
  int get cadCount => files.where((f) => f.category == FileCategory.cad).length;
  int get assetCount => files.where((f) => f.category == FileCategory.assets).length;

  /// ZIP count: počítá původní přijaté archivy (ne rozbalené soubory)
  int get zipCount => archives.length;

  bool get isEmpty => files.isEmpty;

  int get totalCount => files.length;

  String get summaryLine {
    final parts = <String>[];
    if (dataCount > 0) parts.add("DATA $dataCount");
    if (drawingCount > 0) parts.add("VÝKRESY $drawingCount");
    if (cadCount > 0) parts.add("CAD/3D $cadCount");
    if (assetCount > 0) parts.add("ASSETY $assetCount");
    if (zipCount > 0) parts.add("ZIP $zipCount");
    if (ignoredCount > 0) parts.add("IGN $ignoredCount");
    return parts.isEmpty ? "SOUBORY 0" : parts.join("  •  ");
  }

  @override
  String toString() {
    return 'IngestionResult: $dataCount Data, $drawingCount Výkresů, $cadCount CAD/3D, $assetCount Assetů, ZIP $zipCount, IGN $ignoredCount';
  }
}

class IngestionService {
  // =============================================================
  // Metoda 1: Zpracování seznamu souborů (DnD / Picker) + SMART UNPACK ZIP
  // =============================================================
  Future<IngestionResult> processFiles(List<XFile> incomingFiles) async {
    // 1) Příprava dočasného úložiště (session sandbox)
    final tempDir = await getTemporaryDirectory();
    final sessionDir = Directory(
      p.join(tempDir.path, 'mrb_ingestion_${DateTime.now().millisecondsSinceEpoch}'),
    );
    await sessionDir.create(recursive: true);

    // Sem budeme sbírat finální soubory (po rozbalení + po kopírování)
    final List<File> filesToCatalog = [];

    // Tohle je “jen pro info”: seznam přijatých archivů (zip/rar/7z) – zatím unpackujeme jen zip
    final List<File> archives = [];

    int ignored = 0;

    for (final xFile in incomingFiles) {
      final inPath = xFile.path;
      final ext = p.extension(inPath).toLowerCase();

      // 2) SMART UNPACK: ZIP (ostatní archivy zatím jen evidujeme / můžeme ignorovat)
      if (ext == '.zip') {
        archives.add(File(inPath));

        try {
          final bytes = await File(inPath).readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);

          for (final entry in archive) {
            if (!entry.isFile) continue;

            final String filename = entry.name;
            final data = entry.content as List<int>;

            final outPath = p.join(sessionDir.path, filename);
            final outFile = File(outPath);

            await outFile.create(recursive: true);
            await outFile.writeAsBytes(data);

            filesToCatalog.add(outFile);
          }
        } catch (_) {
          // když je zip poškozený, nepadáme – jen zvýšíme ignored
          ignored++;
        }
        continue;
      }

      // 3) Ostatní soubory zkopírujeme do sessionDir pro konzistenci
      //    (tím zajistíš, že editor/import pracuje vždy s temp sandboxem)
      try {
        final outFile = File(p.join(sessionDir.path, p.basename(inPath)));
        await File(inPath).copy(outFile.path);
        filesToCatalog.add(outFile);
      } catch (_) {
        ignored++;
      }
    }

    // 4) Katalogizace finálních souborů (ZIP už nefiguruje v result.files – jen v archives listu)
    final List<ProcessedFile> processed = [];
    final List<File> data = [];
    final List<File> drawings = [];
    final List<File> cads = [];
    final List<File> assets = [];

    for (final file in filesToCatalog) {
      final ext = p.extension(file.path).toLowerCase();
      final cat = _determineCategory(ext);

      if (cat == FileCategory.unknown) {
        ignored++;
        continue;
      }

      processed.add(
        ProcessedFile(
          path: file.path,
          name: p.basename(file.path),
          ext: ext,
          category: cat,
        ),
      );

      // plníme kompatibilní listy
      switch (cat) {
        case FileCategory.data:
          data.add(file);
          break;
        case FileCategory.drawing:
          drawings.add(file);
          break;
        case FileCategory.cad:
          cads.add(file);
          break;
        case FileCategory.assets:
          assets.add(file);
          break;
        case FileCategory.archive:
        case FileCategory.unknown:
          // sem se nedostaneme (archive se nekatalogizuje, unknown skip)
          break;
      }
    }

    final result = IngestionResult(
      files: processed,
      dataFiles: data,
      drawings: drawings,
      cadFiles: cads,
      archives: archives, // původní zipy (pro souhrn / audit)
      assets: assets,
      ignoredCount: ignored,
    );

    print("--- INGESCE DOKONČENA ---");
    print("SESSION: ${sessionDir.path}");
    print(result.toString());

    return result;
  }

  FileCategory _determineCategory(String ext) {
    if (['.xlsx', '.xls', '.csv'].contains(ext)) return FileCategory.data;
    if (ext == '.pdf') return FileCategory.drawing;
    if (['.step', '.stp', '.igs', '.iges', '.dxf', '.dwg'].contains(ext)) return FileCategory.cad;
    if (['.jpg', '.jpeg', '.png', '.webp', '.gif', '.html', '.htm', '.txt'].contains(ext)) return FileCategory.assets;
    return FileCategory.unknown;
  }

  // =============================================================
  // Metoda 2: Otevření systémového dialogu (Tlačítko Procházet)
  // - FileType.any, aby šly i assety
  // =============================================================
  Future<IngestionResult> pickFilesFromDisk() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result == null) {
      return IngestionResult(
        files: const [],
        dataFiles: const [],
        drawings: const [],
        cadFiles: const [],
        archives: const [],
        assets: const [],
        ignoredCount: 0,
      );
    }

    final List<XFile> xFiles = result.paths
        .where((path) => path != null && path!.isNotEmpty)
        .map((path) => XFile(path!))
        .toList();

    return processFiles(xFiles);
  }
}
