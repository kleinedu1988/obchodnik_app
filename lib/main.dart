import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

// --- LOGIKA ---
import 'package:mrb_obchodnik/logic/workflow_controller.dart';
import 'package:mrb_obchodnik/logic/notifications.dart';

// --- WIDGETY A POHLEDY ---
import 'widgets/sidebar.dart'; 
import 'views/ingestion/ingestion_view.dart';
import 'views/production/offer_editor_view.dart';
import 'views/production/order_editor_view.dart';
import 'views/tools/attachment_matching_view.dart';
import 'views/tools/data_validator_view.dart';
import 'views/tools/crm_export_view.dart';
import 'views/config/mapping_profiles_view.dart';
import 'views/settings/settings_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializace pro Desktop (Windows/Linux/macOS)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1360, 900),
      minimumSize: Size(1100, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: "MRB Data Bridge v0.4.2",
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MRB Data Bridge',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1115), // Deep Dark Background
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4077D1),
          brightness: Brightness.dark,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Segoe UI',
          bodyColor: Colors.white.withOpacity(0.9),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // Handler pro změnu stránky ze Sidebaru
  void _onMenuSelected(int index, String title) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  // Callback funkce, kterou předáme do IngestionView pro automatický skok
  void _handleWorkflowUnlocked() {
    setState(() {
      _selectedIndex = 1; // Přepne na Editor (Nabídka/Objednávka)
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // SIDEBAR (Naslouchá WorkflowControlleru interně)
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: _onMenuSelected,
          ),
          
          // HLAVNÍ OBSAH (Router)
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey<int>(_selectedIndex),
                  // ListenableBuilder zajistí, že se obsah překreslí,
                  // když WorkflowController změní docType (Offer -> Order)
                  child: ListenableBuilder(
                    listenable: WorkflowController(),
                    builder: (context, _) => _buildPageContent(_selectedIndex),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CENTRÁLNÍ ROZCESTNÍK (Router) ---
  // Sjednoceno s indexy v Sidebar (0-6)
  Widget _buildPageContent(int index) {
    final workflow = WorkflowController();

    switch (index) {
      case 0: 
        return IngestionView(onSuccess: _handleWorkflowUnlocked);
      
      case 1: 
        // Dynamické rozhodnutí na základě zanalyzovaných dat
        if (workflow.docType == DocType.order) {
          return const OrderEditorView();
        }
        return const OfferEditorView(); 
      
      case 2: return const AttachmentMatchingView();
      case 3: return const DataValidatorView();
      case 4: return const CrmExportView();
      case 5: return const MappingProfilesView();
      case 6: return const SettingsView();
      
      default: 
        return const Center(child: Text("Modul nenalezen"));
    }
  }
}