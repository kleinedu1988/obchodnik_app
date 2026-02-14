import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Důležité pro kIsWeb
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

// --- IMPORTY POHLEDŮ ---
// Použijeme relativní cestu, je to bezpečnější
import 'widgets/sidebar.dart'; 
import 'views/settings/settings_view.dart';
import 'logic/notifications.dart';

// --- IMPORTY NOVÝCH MODULŮ ---
import 'views/ingestion/ingestion_view.dart';
import 'views/production/offer_editor_view.dart';
import 'views/production/order_editor_view.dart';
import 'views/tools/attachment_matching_view.dart';
import 'views/tools/data_validator_view.dart';
import 'views/tools/crm_export_view.dart';
import 'views/config/mapping_profiles_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializace pro Desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(1024, 768),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: "MRB Data Bridge",
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
        scaffoldBackgroundColor: const Color(0xFF0F1115), // Deep Dark
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4077D1),
          brightness: Brightness.dark,
          surface: const Color(0xFF181818), 
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Segoe UI',
          bodyColor: Colors.white.withOpacity(0.85),
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

  // OPRAVA: Přidán parametr 'title', aby to sedělo s definicí v sidebar.dart
  void _onMenuSelected(int index, String title) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    
    // Volitelné: Zde můžeš použít 'title' pro logování nebo analytics
    // debugPrint("Uživatel kliknul na: $title");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // OPRAVA: Voláme 'Sidebar' (ne AppSidebar) a parametr je 'onItemSelected'
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: _onMenuSelected,
          ),
          
          // HLAVNÍ PRACOVNÍ PLOCHA
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
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
  }

  // --- ROZCESTNÍK (ROUTER) ---
Widget _buildPageContent(int index) {
    switch (index) {
      case 0: return const IngestionView();          // Drop Zone
      case 1: return const OfferEditorView();        // Nabídky
      case 2: return const OrderEditorView();        // Objednávky
      case 3: return const AttachmentMatchingView(); // Párování
      case 4: return const DataValidatorView();      // Validace Operací
      case 5: return const CrmExportView();          // Export
      
      case 6: return const MappingProfilesView();    // Mapovací profily (Excel)
      case 7: return const SettingsView();           // Nastavení (vč. Materiálů a Operací)
      
      default: return const Center(child: Text("Stránka nenalezena"));
    }
  }
}
