import 'package:flutter/material.dart';
import 'views/settings/settings_view.dart';
import 'widgets/sidebar.dart';
import 'logic/actions.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MRB CRM',
      theme: ThemeData.dark().copyWith(
        // Změna na měkčí, profesionální tmavou šedou
        scaffoldBackgroundColor: const Color(0xFF111111), 
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4077D1),
          brightness: Brightness.dark,
          // Povrchy prvků (karty, dialogy)
          surface: const Color(0xFF181818), 
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'Inter',
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

  void _onMenuSelected(int index, String title) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    
    try {
      zpracujKliknuti(context, title);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Integrovaný sidebar (nyní na pozadí 0xFF0D0D0D pro jemný kontrast)
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: _onMenuSelected,
          ),
          
          // Hlavní pracovní plocha
          Expanded(
            child: Container(
              // Jemný přechod nebo pevná barva pracovní plochy
              color: Theme.of(context).scaffoldBackgroundColor,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                // Plynulý přechod mezi sekcemi
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

  Widget _buildPageContent(int index) {
    switch (index) {
      case 0: return _buildViewHeader("Dashboard", Icons.grid_view_rounded);
      case 1: return _buildViewHeader("Zákazníci", Icons.person_search_rounded);
      case 2: return _buildViewHeader("Analýza", Icons.analytics_outlined);
      case 3: return const SettingsView();
      case 4: return _buildViewHeader("Import dat", Icons.file_upload_outlined);
      default: return const SizedBox();
    }
  }

  Widget _buildViewHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ikona v barvě akcentu
              Icon(icon, color: const Color(0xFF4077D1), size: 24),
              const SizedBox(width: 16),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Subtilní dělící linka místo tlustého kontejneru
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.white.withOpacity(0.05),
          ),
        ],
      ),
    );
  }
}