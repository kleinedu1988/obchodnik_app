import 'dart:io';
import 'package:flutter/material.dart';
import 'ingestion_service.dart';

// --- MODELY PRO SIDEBAR A EDITOR ---

/// Stavy pro vizuální indikaci u položek menu v Sidebaru
enum ItemStatus { neutral, success, error }

/// Model stavu pro jednu položku v Sidebaru (ovládaný z Workflow)
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

/// Režimy dokumentu
enum DocType { offer, order }

/// Model dat pro jeden řádek v tabulce editoru
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

// =============================================================
//  WORKFLOW CONTROLLER (Policista s dálkovým ovládáním)
// =============================================================

class WorkflowController extends ChangeNotifier {
  // Singleton pattern
  static final WorkflowController _instance = WorkflowController._internal();
  factory WorkflowController() => _instance;
  WorkflowController._internal();

  // --- GLOBÁLNÍ STAVY PROCESU ---
  bool isEditorUnlocked = false; 
  bool isProcessing = false;      // Globální systémový zámek (loading)
  DocType docType = DocType.offer;

  // --- DATOVÉ SKLADY ---
  IngestionResult? lastIngestion;
  List<EditorRow> loadedData = [];
  int activeRowIndex = -1;

  // --- SIDEBAR STATE MATRIX ---
  // Mapa indexů (0-6) a jejich aktuálních stavů
  Map<int, SidebarItemState> sidebarStates = {
    0: const SidebarItemState(isEnabled: true, isProcessing: true), // Drop Zone
    1: const SidebarItemState(isEnabled: false), // Editor
    2: const SidebarItemState(isEnabled: false), // Párování
    3: const SidebarItemState(isEnabled: false), // Validace
    4: const SidebarItemState(isEnabled: false), // CRM Export
    5: const SidebarItemState(isEnabled: true),  // Profily
    6: const SidebarItemState(isEnabled: true),  // Nastavení
  };

  // =============================================================
  //  1. OVLÁDÁNÍ SIDEBARU (Remote Control)
  // =============================================================

  /// Aktualizuje stav konkrétní položky v menu
  void updateSidebarItem(int index, {ItemStatus? status, bool? isEnabled, bool? isProcessing}) {
    final current = sidebarStates[index] ?? const SidebarItemState();
    sidebarStates[index] = SidebarItemState(
      status: status ?? current.status,
      isEnabled: isEnabled ?? current.isEnabled,
      isProcessing: isProcessing ?? current.isProcessing,
    );
    notifyListeners();
  }

  // =============================================================
  //  2. ŽIVOTNÍ CYKLUS WORKFLOW (Business Logika)
  // =============================================================

  /// A) GLOBÁLNÍ LOCK (Při parsování nebo náročných operacích)
  void setProcessing(bool value) {
    isProcessing = value;
    notifyListeners();
  }

  /// B) PŘIJETÍ DAT (Volá IngestionView po Dropu)
  Future<void> handleIngestion(IngestionResult result) async {
    lastIngestion = result;
    
    // Po nahrání označíme Drop Zone jako "Hotovo" (Success), ale stále Enabled pro případnou změnu
    updateSidebarItem(0, status: ItemStatus.success, isProcessing: false);
    
    // Pokud máme data, dáme uživateli vědět, že Editor čeká (Neutral, ale Enabled)
    updateSidebarItem(1, isEnabled: true);
    
    notifyListeners();
  }

  /// C) VSTUP DO EDITORU (Definitivní volba Nabídka / Objednávka)
  /// Zde dochází k zešednutí Drop Zone a odemčení editoru
  void unlockEditor(DocType type, {List<EditorRow>? initialData}) {
    docType = type;
    isEditorUnlocked = true;

    // 1. Naplníme data (buď z Excelu nebo prázdná)
    loadedData = initialData ?? [EditorRow()];
    if (loadedData.isNotEmpty) activeRowIndex = 0;

    // 2. State Matrix: ZAMKNEME Drop Zone (index 0) a ZEŠEDNE
    updateSidebarItem(0, isEnabled: false, status: ItemStatus.success);
    
    // 3. State Matrix: AKTIVUJEME Editor (index 1) a zapneme u něj pulzování
    updateSidebarItem(1, isEnabled: true, isProcessing: true, status: ItemStatus.neutral);
    
    // 4. State Matrix: ODEMKNEME navazující kroky
    updateSidebarItem(2, isEnabled: true);
    updateSidebarItem(3, isEnabled: true);
    updateSidebarItem(4, isEnabled: true);

    notifyListeners();
    print("👮 Workflow: Vstup do editoru povolen. Režim: ${type.name.toUpperCase()}");
  }

  /// D) PŘEPÍNÁNÍ REŽIMŮ (Z EditorDispatcheru)
  void setDocType(DocType type) {
    if (docType == type) return;
    docType = type;
    notifyListeners();
  }

  // =============================================================
  //  3. SYNCHRONIZACE DAT (Editor -> UI)
  // =============================================================

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

  // =============================================================
  //  4. CELKOVÝ RESET (Tlačítko zpět)
  // =============================================================

  void reset() {
    isEditorUnlocked = false;
    isProcessing = false;
    lastIngestion = null;
    loadedData = [];
    activeRowIndex = -1;
    docType = DocType.offer;

    // Obnova Sidebar Matrix do výchozího stavu
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
    print("👮 Workflow: Systém vyčištěn a resetován.");
  }
}