import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

// --- LOGIKA A STAV ---
import 'package:mrb_obchodnik/logic/workflow_controller.dart';

// --- UI KOMPONENTY ---
import 'widgets/sidebar.dart'; 
import 'views/ingestion/ingestion_view.dart';
import 'package:mrb_obchodnik/views/production/editor_dispatcher.dart';
import 'views/tools/attachment_matching_view.dart';
import 'views/tools/data_validator_view.dart';
import 'views/tools/crm_export_view.dart';
// NOVÝ IMPORT PIPELINE:
import 'views/production/order_pipeline_view.dart'; 
import 'views/config/mapping_profiles_view.dart';
import 'views/settings/settings_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializace pro Desktop (Windows/macOS/Linux)
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
      title: "MRB Data Bridge v0.5.0",
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
        scaffoldBackgroundColor: const Color(0xFF0F1115),
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
  final WorkflowController _workflow = WorkflowController();

  // Handler pro změnu stránky ze Sidebaru
  void _onMenuSelected(int index, String title) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _workflow,
      builder: (context, _) {
        
        // AUTOMATICKÝ SKOK: Pokud se odemkne editor a jsme na úvodní ploše
        if (_workflow.isEditorUnlocked && _selectedIndex == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedIndex != 1) {
              setState(() => _selectedIndex = 1);
            }
          });
        }

        return Scaffold(
          body: Row(
            children: [
              // 1. SIDEBAR
              Sidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onMenuSelected,
              ),
              
              // 2. HLAVNÍ OBSAH: Reaktivní router
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeInOutCubic,
                    child: KeyedSubtree(
                      key: ValueKey<int>(_selectedIndex),
                      child: _buildPageContent(_selectedIndex),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- CENTRÁLNÍ ROZCESTNÍK (Router) ---
  Widget _buildPageContent(int index) {
    switch (index) {
      case 0: return const IngestionView();
      case 1: 
        return _workflow.isEditorUnlocked 
            ? const EditorDispatcher() 
            : const IngestionView();
      case 2: return const AttachmentMatchingView();
      case 3: return const DataValidatorView();
      case 4: return const CrmExportView();
      
      // NOVÝ INDEX PRO PIPELINE
      case 5: return const OrderPipelineView(); 
      
      // POSUNUTÉ INDEXY PRO SYSTÉM
      case 6: return const MappingProfilesView();
      case 7: return const SettingsView();
      
      default: 
        return const Center(child: Text("Modul nenalezen"));
    }
  }
}