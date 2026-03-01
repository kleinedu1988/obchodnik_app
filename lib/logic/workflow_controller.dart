import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart'; // Nutné pro práci s typem Data a Sheet
import 'package:path/path.dart' as p;

import 'db_service.dart';
import 'ingestion_service.dart';
import 'excel_header_detector.dart';
import 'customer_matcher.dart';
import 'mapping_profile_resolver.dart';

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
  final String id;
  String name;
  bool isDefault;
  Map<String, String> mappings; // Key: SystemField (pos, qty...), Value: "ks, pocet, qty"

  MappingProfile({
    required this.id,
    required this.name,
    this.isDefault = false,
    required this.mappings,
  });

  // --- OCHRANA SYSTÉMOVÉHO PROFILU ---
  static const String systemProfileId = "system_default_01";
  bool get isSystem => id == systemProfileId;

  // Pevně zakódovaný (Hardcoded) systémový profil, obsahující to nejlepší z dřívějších
  static MappingProfile get systemDefault {
    return MappingProfile(
      id: systemProfileId,
      name: "Základní Import (Systémový)",
      isDefault: true,
      mappings: {
        "pos": "poz, pozice, č., no., item, pos, position",
        "name": "název, popis, description, name, part name, tovar, benennung",
        "qty": "ks, počet, mn., qty, quantity, amount, pocet, mnozstvi, menge, anzahl",
        "material": "materiál, mat, jakost, material, grade, werkstoff",
        "thickness": "tl, tl., tloušťka, thickness, th, s, tloustka, dicke",
        "dims": "rozměry, format, rozmer, dims"
      },
    );
  }

  /// Vrátí všechna klíčová slova jako jeden plochý seznam pro detektor
  List<String> get allKeywords {
    final Set<String> keywords = {};
    for (var val in mappings.values) {
      final parts = val.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty);
      keywords.addAll(parts);
    }
    return keywords.toList();
  }

  // --- SERIALIZACE PRO DATABÁZI ---
  factory MappingProfile.fromMap(Map<String, dynamic> map) {
    return MappingProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      isDefault: (map['is_default'] as int) == 1,
      mappings: Map<String, String>.from(jsonDecode(map['mappings'] as String)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_default': isDefault ? 1 : 0,
      'mappings': jsonEncode(mappings),
    };
  }
}

// =============================================================
//  WORKFLOW CONTROLLER
// =============================================================

class WorkflowController extends ChangeNotifier {
  static final WorkflowController _instance = WorkflowController._internal();
  factory WorkflowController() => _instance;
  
  WorkflowController._internal() {
    _loadProfilesInit();
  }

  // --- DEPENDENCIES ---
  final ExcelHeaderDetector _detector = ExcelHeaderDetector();
  final CustomerMatcher _customerMatcher = CustomerMatcher();
  final MappingProfileResolver _mappingProfileResolver = MappingProfileResolver();

  // --- GLOBÁLNÍ STAVY PROCESU ---
  bool isEditorUnlocked = false; 
  bool isProcessing = false;
  DocType docType = DocType.offer;

  // --- STAVY PRO WIZARD ---
  bool isVerifyingHeader = false;
  bool isMatchingCustomer = false;
  bool isMappingPending = false;
  bool wasCustomerProfileAutoApplied = false;

  HeaderDetectionResult? headerResult;
  CustomerMatchResult? pendingCustomerResult;
  Map<String, dynamic>? assignedCustomer;
  String? customerProfileUid;
  Map<String, String>? customerProfileMappings;
  ResolvedMapping? resolvedMapping;

  // --- DATA ---
  IngestionResult? lastIngestion;
  List<EditorRow> loadedData = [];
  int activeRowIndex = -1;

  // --- PROFILY ---
  List<MappingProfile> profiles = [];

  Future<void> _loadProfilesInit() async {
    await loadProfiles();
  }

  Future<void> loadProfiles() async {
    final dbData = await DbService().getProfily();
    
    profiles = dbData.map((row) => MappingProfile.fromMap(row)).toList();

    // KONTROLA: Obsahuje seznam náš systémový profil?
    bool hasSystemProfile = profiles.any((p) => p.isSystem);

    if (!hasSystemProfile) {
      // Získáme náš hardcoded profil
      final sysProfile = MappingProfile.systemDefault;
      
      // Uložíme ho rovnou do databáze (asynchronně)
      DbService().saveProfil(
        id: sysProfile.id,
        name: sysProfile.name,
        isDefault: sysProfile.isDefault,
        mappings: sysProfile.mappings,
      );

      // Přidáme ho do paměti aplikace (na první místo)
      profiles.insert(0, sysProfile);
    }
    notifyListeners();
  }

  MappingProfile get activeProfile {
    // Pokud ještě nejsou načtené profily z DB, vrátíme systémový, aby to nespadlo
    if (profiles.isEmpty) return MappingProfile.systemDefault;
    return profiles.firstWhere((p) => p.isDefault, orElse: () => profiles.first);
  }

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
        debugPrint("Chyba: Excel neobsahuje žádné listy.");
      }

    } catch (e) {
      debugPrint("Chyba analýzy Excelu: $e");
      updateSidebarItem(0, status: ItemStatus.error);
    } finally {
      setProcessing(false);
      notifyListeners();
    }
  }

  /// Manuální korekce hlavičky uživatelem (kliknutí v UI)
  void manualHeaderAdjust(int newIndex) {
    if (headerResult == null) return;
    
    final newHeaders = headerResult!.previewRows[newIndex]
        .map((cellString) {
          return cellString.replaceAll('\n', ' ').trim();
        })
        .toList();

    headerResult = HeaderDetectionResult(
      headerRowIndex: newIndex,
      cleanedHeaders: newHeaders,
      previewRows: headerResult!.previewRows,
      knownSpans: headerResult!.knownSpans,
      rowScores: headerResult!.rowScores,
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
  Future<void> confirmCustomer(Map<String, dynamic>? customer) async {
    // SQLite vrací read-only mapy – uděláme mutable kopii, abychom mohli ukládat customer_profile_uid
    assignedCustomer = customer != null ? Map<String, dynamic>.from(customer) : null;
    customerProfileUid = null;
    customerProfileMappings = null;
    resolvedMapping = null;
    wasCustomerProfileAutoApplied = false;

    final resolved = await _mappingProfileResolver.resolve(
      customerId: customer?['id']?.toString(),
      customerProfileUid: customer?['customer_profile_uid']?.toString(),
      matchedProfileUid: pendingCustomerResult?.profileUid,
      defaultProfile: MappingProfile.systemDefault.mappings,
    );

    resolvedMapping = resolved;
    customerProfileUid = resolved.profileUid;
    customerProfileMappings = Map<String, String>.from(resolved.mappings);

    if (customer != null && customerProfileUid == null) {
      customerProfileUid = await _createCustomerProfileForCustomer(
        customer: customer,
        initialMappings: customerProfileMappings ?? MappingProfile.systemDefault.mappings,
      );
      resolvedMapping = ResolvedMapping(
        profileUid: customerProfileUid,
        mappings: customerProfileMappings ?? MappingProfile.systemDefault.mappings,
        source: resolved.source,
        confidence: resolved.confidence,
        isAutoApplied: resolved.isAutoApplied,
      );
    }

    if (assignedCustomer != null && customerProfileUid != null && assignedCustomer!['id'] != null) {
      await DbService().updateCustomerProfileUid(assignedCustomer!['id'] as int, customerProfileUid);
      assignedCustomer!['customer_profile_uid'] = customerProfileUid;
    }

    isMatchingCustomer = false;
    final hasCompleteProfile = _hasRequiredMappingForCurrentDoc(customerProfileMappings);
    isMappingPending = !hasCompleteProfile;
    wasCustomerProfileAutoApplied = hasCompleteProfile;
    notifyListeners();
  }

  bool _hasRequiredMappingForCurrentDoc(Map<String, String>? mappings) {
    if (mappings == null || mappings.isEmpty) return false;

    final requiredFields = <String>{'name', 'qty'};
    if (docType == DocType.order) {
      requiredFields.add('material');
    }

    bool hasValueForField(String field) {
      final raw = mappings[field]?.trim() ?? '';
      if (raw.isEmpty) return false;
      return raw.split(',').any((token) => token.trim().isNotEmpty);
    }

    return requiredFields.every(hasValueForField);
  }

  Future<String> _createCustomerProfileForCustomer({
    required Map<String, dynamic> customer,
    required Map<String, String> initialMappings,
  }) async {
    final generatedUid = 'cp_${DateTime.now().microsecondsSinceEpoch}';
    final defaults = Map<String, String>.from(initialMappings);
    final customerId = customer['id']?.toString() ?? '';

    await DbService().saveCustomerProfileRaw(
      uid: generatedUid,
      customerId: customerId,
      customerName: customer['nazev']?.toString() ?? 'Neznámý zákazník',
      mappings: defaults,
    );
    return generatedUid;
  }

  void completeMappingReview() {
    isMappingPending = false;
    wasCustomerProfileAutoApplied = false;
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
    customerProfileUid = null;
    customerProfileMappings = null;
    resolvedMapping = null;
    wasCustomerProfileAutoApplied = false;

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
  //  SPRÁVA PROFILŮ (CRUD A DATABÁZE)
  // =============================================================

  void saveProfile(MappingProfile updatedProfile) {
    // 1. Asynchronní uložení do databáze (neblokujeme UI)
    DbService().saveProfil(
      id: updatedProfile.id,
      name: updatedProfile.name,
      isDefault: updatedProfile.isDefault,
      mappings: updatedProfile.mappings,
    );

    // 2. Rychlá aktualizace lokální paměti pro plynulost UI
    final index = profiles.indexWhere((p) => p.id == updatedProfile.id);
    
    // Pokud je nastavován jako výchozí, zrušit výchozí u všech ostatních v paměti
    if (updatedProfile.isDefault) {
      for (var p in profiles) {
        if (p.id != updatedProfile.id) p.isDefault = false;
      }
    }

    if (index != -1) {
      profiles[index] = updatedProfile;
    } else {
      profiles.add(updatedProfile);
    }
    
    notifyListeners();
  }

  void addProfile(MappingProfile newProfile) {
    // Vytvoření a uložení je stejné jako aktualizace
    saveProfile(newProfile);
  }

  void deleteProfile(String id) {
    // Pojistka proti smazání systémového profilu z paměti i databáze
    if (id == MappingProfile.systemProfileId) {
      debugPrint("Nelze smazat systémový profil.");
      return;
    }

    // 1. Asynchronní smazání z databáze
    DbService().deleteProfil(id);

    // 2. Okamžité smazání z lokální paměti pro UI
    profiles.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}