import 'package:flutter/material.dart';
import 'package:excel/excel.dart'; // Nutné pro práci s typem Data a Sheet
import 'package:path/path.dart' as p;
import 'ingestion_service.dart';
import 'excel_header_detector.dart';
import 'customer_matcher.dart';

// =============================================================
//  MODELY PRO SIDEBAR A EDITOR
// =============================================================

enum ItemStatus { neutral, success, error }

class SidebarItemState {
  final ItemStatus status;
  final bool isEnabled;
  final bool isProcessing;

  const SidebarItemState({
    this.status = ItemStatus.neutral,
    this.isEnabled = true,
    this.isProcessing = false,
  });
}

enum DocType { offer, order }

class EditorRow {
  String partNumber;
  String name;
  String quantity;
  String material;
  String thickness;

  EditorRow({
    this.partNumber = "",
    this.name = "",
    this.quantity = "",
    this.material = "",
    this.thickness = "",
  });
}

/// Model pro mapovací profil (Definice klíčových slov pro sloupce)
class MappingProfile {
  String id;
  String name;
  bool isDefault;
  Map<String, String> mappings; // Key: SystemField (pos, qty...), Value: "ks, pocet, qty"

  MappingProfile({
    required this.id,
    required this.name,
    this.isDefault = false,
    required this.mappings,
  });

  /// Vrátí všechna klíčová slova jako jeden plochý seznam pro detektor
  List<String> get allKeywords {
    final Set<String> keywords = {};
    for (var val in mappings.values) {
      final parts = val.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty);
      keywords.addAll(parts);
    }
    return keywords.toList();
  }
}

// =============================================================
//  WORKFLOW CONTROLLER
// =============================================================

class WorkflowController extends ChangeNotifier {
  static final WorkflowController _instance = WorkflowController._internal();
  factory WorkflowController() => _instance;
  WorkflowController._internal();

  // --- DEPENDENCIES ---
  final ExcelHeaderDetector _detector = ExcelHeaderDetector();
  final CustomerMatcher _customerMatcher = CustomerMatcher();

  // --- GLOBÁLNÍ STAVY PROCESU ---
  bool isEditorUnlocked = false; 
  bool isProcessing = false;
  DocType docType = DocType.offer;

  // --- STAVY PRO WIZARD ---
  bool isVerifyingHeader = false;
  bool isMatchingCustomer = false;
  bool isMappingPending = false;

  HeaderDetectionResult? headerResult;
  CustomerMatchResult? pendingCustomerResult;
  Map<String, dynamic>? assignedCustomer;

  // --- DATA ---
  IngestionResult? lastIngestion;
  List<EditorRow> loadedData = [];
  int activeRowIndex = -1;

  // --- PROFILY ---
  List<MappingProfile> profiles = [
    MappingProfile(
      id: '1',
      name: 'Standardní Import (Default)',
      isDefault: true,
      mappings: {
        'pos': 'poz, pozice, č., no., item',
        'name': 'název, popis, description, name, part name',
        'qty': 'ks, počet, mn., qty, quantity, amount',
        'material': 'materiál, mat, jakost, material',
        'thickness': 'tl, tl., tloušťka, thickness, th',
      },
    ),
    MappingProfile(
      id: '2',
      name: 'Export SAP (Německo)',
      isDefault: false,
      mappings: {
        'pos': 'pos, position',
        'name': 'benennung, name',
        'qty': 'menge, anzahl',
        'material': 'werkstoff',
        'thickness': 'dicke',
      },
    ),
  ];

  MappingProfile get activeProfile => profiles.firstWhere((p) => p.isDefault, orElse: () => profiles.first);

  // --- SIDEBAR STATE MATRIX ---
  Map<int, SidebarItemState> sidebarStates = {
    0: const SidebarItemState(isEnabled: true, isProcessing: true),
    1: const SidebarItemState(isEnabled: false),
    2: const SidebarItemState(isEnabled: false),
    3: const SidebarItemState(isEnabled: false),
    4: const SidebarItemState(isEnabled: false),
    5: const SidebarItemState(isEnabled: true),
    6: const SidebarItemState(isEnabled: true),
  };

  void updateSidebarItem(int index, {ItemStatus? status, bool? isEnabled, bool? isProcessing}) {
    final current = sidebarStates[index] ?? const SidebarItemState();
    sidebarStates[index] = SidebarItemState(
      status: status ?? current.status,
      isEnabled: isEnabled ?? current.isEnabled,
      isProcessing: isProcessing ?? current.isProcessing,
    );
    notifyListeners();
  }

  void setProcessing(bool value) {
    isProcessing = value;
    notifyListeners();
  }

  // =============================================================
  //  LOGIKA INGESCE A ANALÝZY
  // =============================================================

  Future<void> handleIngestion(IngestionResult result) async {
    lastIngestion = result;
    updateSidebarItem(0, status: ItemStatus.success, isProcessing: false);
    
    if (result.hasExcel) {
      // Pokud je přítomen Excel, spustíme analýzu hlaviček
      await runHeaderAnalysis();
    } else {
      // Jinak rovnou editor (pro jiné typy souborů)
      updateSidebarItem(1, isEnabled: true);
    }
    notifyListeners();
  }

  /// Spuštění Fáze 1: Analýza hlaviček (REÁLNÁ DATA)
  Future<void> runHeaderAnalysis() async {
    if (lastIngestion == null || !lastIngestion!.hasExcel) return;

    setProcessing(true);
    try {
      // 1. Najdeme první Excel soubor v seznamu
      final excelFile = lastIngestion!.dataFiles.firstWhere(
        (file) => file.path.toLowerCase().endsWith('.xlsx') || file.path.toLowerCase().endsWith('.xls'),
      );

      // 2. Přečteme byty ze souboru (XFile -> Uint8List)
      final bytes = await excelFile.readAsBytes();
      
      // 3. Dekódujeme Excel
      final excel = Excel.decodeBytes(bytes);
      
      // 4. Vezmeme první sheet (tabulku)
      final firstTableName = excel.tables.keys.first;
      final sheet = excel.tables[firstTableName];

      if (sheet != null) {
        // 5. Spustíme externí detektor s klíčovými slovy z AKTIVNÍHO PROFILU
        headerResult = _detector.analyze(
          sheet, 
          customKeywords: activeProfile.allKeywords
        );
        
        // 6. Přepneme UI do režimu verifikace
        isVerifyingHeader = true;
        updateSidebarItem(0, status: ItemStatus.success);
      } else {
        print("Chyba: Excel neobsahuje žádné listy.");
      }

    } catch (e) {
      print("Chyba analýzy Excelu: $e");
      updateSidebarItem(0, status: ItemStatus.error);
    } finally {
      setProcessing(false);
      notifyListeners();
    }
  }

  /// Manuální korekce hlavičky uživatelem (kliknutí v UI)
  void manualHeaderAdjust(int newIndex) {
    if (headerResult == null) return;
    
    // OPRAVA: HeaderDetectionResult.previewRows už obsahuje Stringy (List<String>), nikoliv Excel objekty.
    // Proto přistupujeme k proměnné přímo jako k textu a nevoláme .value.
    final newHeaders = headerResult!.previewRows[newIndex]
        .map((cellString) {
          return cellString.replaceAll('\n', ' ').trim();
        })
        .toList();

    // Vytvoříme novou instanci výsledku s novým indexem hlavičky
    // DŮLEŽITÉ: Musíme předat i knownSpans, aby UI vědělo o spojených buňkách i po změně řádku
    headerResult = HeaderDetectionResult(
      headerRowIndex: newIndex,
      cleanedHeaders: newHeaders,
      previewRows: headerResult!.previewRows,
      knownSpans: headerResult!.knownSpans, // <--- PŘIDÁNO: Zachováme detekované spany
      rowScores: headerResult!.rowScores,   // <--- PŘIDÁNO: Zachováme skóre pro barvení
    );
    notifyListeners();
  }

  void confirmHeader() {
    isVerifyingHeader = false;
    notifyListeners();
    runCustomerMatch(); // spustí async, výsledek oznámí přes notifyListeners
  }

  /// Fáze 2: Automatické rozpoznání zákazníka ze souboru
  Future<void> runCustomerMatch() async {
    isProcessing = true;
    notifyListeners();

    try {
      if (lastIngestion == null || headerResult == null) {
        pendingCustomerResult = const CustomerMatchResult(
          customer: null, confidence: 0.0,
          level: CustomerMatchConfidence.none, matchedOn: '',
        );
      } else {
        final excelFile = lastIngestion!.dataFiles.firstWhere(
          (f) => ['.xlsx', '.xls'].contains(p.extension(f.path).toLowerCase()),
          orElse: () => lastIngestion!.dataFiles.first,
        );

        pendingCustomerResult = await _customerMatcher.findBestMatch(
          p.basename(excelFile.path),
          headerResult!.previewRows,
          headerResult!.headerRowIndex,
        );
      }
    } catch (e) {
      debugPrint("CustomerMatcher error: $e");
      pendingCustomerResult = const CustomerMatchResult(
        customer: null, confidence: 0.0,
        level: CustomerMatchConfidence.none, matchedOn: '',
      );
    } finally {
      isProcessing = false;
      isMatchingCustomer = true;
      notifyListeners();
    }
  }

  /// Potvrzení zákazníka uživatelem (nebo null = přeskočit)
  void confirmCustomer(Map<String, dynamic>? customer) {
    assignedCustomer = customer;
    isMatchingCustomer = false;
    isMappingPending = true;
    notifyListeners();
  }

  // =============================================================
  //  EDITOR A NAVIGACE
  // =============================================================

  void unlockEditor(DocType type, {List<EditorRow>? initialData}) {
    docType = type;
    isEditorUnlocked = true;
    isMappingPending = false; 

    loadedData = initialData ?? [EditorRow()];
    if (loadedData.isNotEmpty) activeRowIndex = 0;

    updateSidebarItem(0, isEnabled: false, status: ItemStatus.success);
    updateSidebarItem(1, isEnabled: true, isProcessing: true, status: ItemStatus.neutral);
    updateSidebarItem(2, isEnabled: true);
    updateSidebarItem(3, isEnabled: true);
    updateSidebarItem(4, isEnabled: true);

    notifyListeners();
  }

  void setDocType(DocType type) {
    if (docType == type) return;
    docType = type;
    notifyListeners();
  }

  void updateRow(int index, EditorRow updatedRow) {
    if (index >= 0 && index < loadedData.length) {
      loadedData[index] = updatedRow;
      notifyListeners();
    }
  }

  void setActiveRow(int index) {
    activeRowIndex = index;
    notifyListeners();
  }

  void reset() {
    isEditorUnlocked = false;
    isProcessing = false;
    lastIngestion = null;
    loadedData = [];
    activeRowIndex = -1;
    docType = DocType.offer;

    isVerifyingHeader = false;
    isMatchingCustomer = false;
    isMappingPending = false;
    headerResult = null;
    pendingCustomerResult = null;
    assignedCustomer = null;

    sidebarStates = {
      0: const SidebarItemState(isEnabled: true, isProcessing: true),
      1: const SidebarItemState(isEnabled: false),
      2: const SidebarItemState(isEnabled: false),
      3: const SidebarItemState(isEnabled: false),
      4: const SidebarItemState(isEnabled: false),
      5: const SidebarItemState(isEnabled: true),
      6: const SidebarItemState(isEnabled: true),
    };

    notifyListeners();
  }

  // =============================================================
  //  SPRÁVA PROFILŮ (CRUD)
  // =============================================================

  void saveProfile(MappingProfile updatedProfile) {
    final index = profiles.indexWhere((p) => p.id == updatedProfile.id);
    if (index != -1) {
      profiles[index] = updatedProfile;
      // Pokud je tento defaultní, zrušit default u ostatních
      if (updatedProfile.isDefault) {
        for (var p in profiles) {
          if (p.id != updatedProfile.id) p.isDefault = false;
        }
      }
      notifyListeners();
    }
  }

  void addProfile(MappingProfile newProfile) {
    profiles.add(newProfile);
    notifyListeners();
  }

  void deleteProfile(String id) {
    profiles.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}