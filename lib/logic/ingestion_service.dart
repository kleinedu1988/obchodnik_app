import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

// Jednoduchý model pro roztříděná data (zatím jen v paměti)
class IngestionResult {
  final List<File> dataFiles;   // Excel, CSV
  final List<File> drawings;    // PDF
  final List<File> cadFiles;    // DXF, DWG, STEP
  final List<File> archives;    // ZIP, RAR

  IngestionResult({
    required this.dataFiles,
    required this.drawings,
    required this.cadFiles,
    required this.archives,
  });

  bool get isEmpty => dataFiles.isEmpty && drawings.isEmpty && cadFiles.isEmpty && archives.isEmpty;
  
  int get totalCount => dataFiles.length + drawings.length + cadFiles.length + archives.length;

  @override
  String toString() {
    return 'IngestionResult: ${dataFiles.length} Data, ${drawings.length} Výkresů, ${cadFiles.length} CAD, ${archives.length} Archivů';
  }
}

class IngestionService {
  
  // Metoda 1: Zpracování seznamu souborů (z Drag&Drop nebo Pickeru)
  Future<IngestionResult> processFiles(List<XFile> rawFiles) async {
    final List<File> data = [];
    final List<File> drawings = [];
    final List<File> cads = [];
    final List<File> archives = [];

    for (var xFile in rawFiles) {
      final String path = xFile.path;
      final String ext = p.extension(path).toLowerCase();
      final File file = File(path);

      // --- LOGIKA TŘÍDĚNÍ ---
      if (['.xlsx', '.xls', '.csv'].contains(ext)) {
        data.add(file);
      } 
      else if (['.pdf'].contains(ext)) {
        drawings.add(file);
      }
      else if (['.dxf', '.dwg', '.step', '.stp', '.igs', '.iges'].contains(ext)) {
        cads.add(file);
      }
      else if (['.zip', '.rar', '.7z'].contains(ext)) {
        archives.add(file);
        // TODO: Zde v budoucnu zavoláme Smart Unpack Logic
      }
      else {
        print("Ignoruji nepodporovaný soubor: ${p.basename(path)}");
      }
    }

    final result = IngestionResult(
      dataFiles: data,
      drawings: drawings,
      cadFiles: cads,
      archives: archives,
    );

    // Debug výpis
    print("--- INGESCE DOKONČENA ---");
    print(result.toString());
    
    return result;
  }

  // Metoda 2: Otevření systémového dialogu (Tlačítko Procházet)
  Future<IngestionResult> pickFilesFromDisk() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'pdf', 'dxf', 'dwg', 'step', 'stp', 'zip', 'rar'],
    );

    if (result != null) {
      // Konverze PlatformFile na XFile pro jednotné zpracování
      List<XFile> xFiles = result.paths
          .where((path) => path != null)
          .map((path) => XFile(path!))
          .toList();
      
      return processFiles(xFiles);
    } else {
      // Uživatel zrušil výběr
      return IngestionResult(dataFiles: [], drawings: [], cadFiles: [], archives: []);
    }
  }
}