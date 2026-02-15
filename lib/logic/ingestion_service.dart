import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart'; // Nutný import pro pickFromDisk
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum FileCategory { data, drawing, cad, assets, archive, unknown }

class ProcessedFile {
  final String path;
  final String name;
  final String ext;
  final FileCategory category;

  const ProcessedFile({required this.path, required this.name, required this.ext, required this.category});
  File get asFile => File(path);
}

class IngestionResult {
  final List<ProcessedFile> files;
  final List<File> dataFiles;
  final List<File> drawings;
  final String sessionPath;
  final int ignoredCount;

  IngestionResult({
    required this.files,
    required this.dataFiles,
    required this.drawings,
    required this.sessionPath,
    this.ignoredCount = 0,
  });

  bool get isEmpty => files.isEmpty;
  bool get hasExcel => dataFiles.isNotEmpty;
  String get summaryLine => "DATA ${dataFiles.length} • VÝKRESY ${drawings.length} • IGN $ignoredCount";
}

class IngestionService {
  
  // =============================================================
  //  METODA PRO TLAČÍTKO (System File Picker)
  // =============================================================
  
  /// Otevře systémové okno, nechá uživatele vybrat soubory 
  /// a následně je pošle do procesu Ingesce.
  Future<IngestionResult?> pickFromDisk() async {
    // 1. Vyvolání nativního dialogu
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any, // Povolíme vše, třídění si uděláme sami
    );

    // Pokud uživatel okno zavřel bez výběru
    if (result == null || result.paths.isEmpty) return null;

    // 2. Převod String cest na XFile objekty
    final List<XFile> xFiles = result.paths
        .whereType<String>()
        .map((path) => XFile(path))
        .toList();

    // 3. Spuštění hlavního procesu (Sandbox, Unpack, Sort)
    return await processFiles(xFiles);
  }

  // =============================================================
  //  METODA PRO DRAG & DROP A VNITŘNÍ ZPRACOVÁNÍ
  // =============================================================

  Future<IngestionResult> processFiles(List<XFile> incomingFiles) async {
    final tempDir = await getTemporaryDirectory();
    final sessionPath = p.join(tempDir.path, 'mrb_bridge_${DateTime.now().millisecondsSinceEpoch}');
    final sessionDir = Directory(sessionPath);
    await sessionDir.create(recursive: true);

    final List<File> filesToCatalog = [];
    int ignored = 0;

    for (final xFile in incomingFiles) {
      final ext = p.extension(xFile.path).toLowerCase();

      if (ext == '.zip') {
        try {
          final bytes = await File(xFile.path).readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);
          for (final entry in archive) {
            if (!entry.isFile) continue;
            final outPath = p.join(sessionPath, entry.name);
            final outFile = File(outPath);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(entry.content as List<int>);
            filesToCatalog.add(outFile);
          }
        } catch (_) { ignored++; }
      } else {
        try {
          final outFile = File(p.join(sessionPath, p.basename(xFile.path)));
          await File(xFile.path).copy(outFile.path);
          filesToCatalog.add(outFile);
        } catch (_) { ignored++; }
      }
    }

    final List<ProcessedFile> allProcessed = [];
    final List<File> data = [];
    final List<File> drawings = [];

    for (final file in filesToCatalog) {
      final ext = p.extension(file.path).toLowerCase();
      final cat = _determineCategory(ext);

      if (cat == FileCategory.unknown) {
        ignored++;
        continue;
      }

      final pf = ProcessedFile(
        path: file.path,
        name: p.basename(file.path),
        ext: ext,
        category: cat,
      );

      allProcessed.add(pf);
      if (cat == FileCategory.data) data.add(file);
      if (cat == FileCategory.drawing) drawings.add(file);
    }

    return IngestionResult(
      files: allProcessed,
      dataFiles: data,
      drawings: drawings,
      sessionPath: sessionPath,
      ignoredCount: ignored,
    );
  }

  FileCategory _determineCategory(String ext) {
    if (['.xlsx', '.xls', '.csv'].contains(ext)) return FileCategory.data;
    if (ext == '.pdf') return FileCategory.drawing;
    if (['.step', '.stp', '.igs', '.iges', '.dxf', '.dwg'].contains(ext)) return FileCategory.cad;
    if (['.jpg', '.jpeg', '.png', '.webp', '.txt'].contains(ext)) return FileCategory.assets;
    return FileCategory.unknown;
  }
}