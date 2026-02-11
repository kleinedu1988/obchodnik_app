import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:mrb_obchodnik/logic/actions.dart';
import 'views/settings_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const double _sidebarWidth = 250;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ===============================
          //  GLASS SIDEBAR (NO RADIUS)
          // ===============================
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: _sidebarWidth,
              decoration: BoxDecoration(
                color: const Color(0xFF151515).withOpacity(0.65),
                border: Border(
                  right: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 50),

                  _menuItem(0, Icons.dashboard_rounded, "Nástěnka"),
                  _menuItem(1, Icons.file_download_rounded, "Import dat"),
                  _menuItem(2, Icons.analytics_rounded, "Analýza"),

                  const Spacer(),

                  _menuItem(3, Icons.settings_rounded, "Nastavení"),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ===============================
          //  CONTENT
          // ===============================
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(40),
              child: _getPageView(_selectedIndex),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================
  //  SIMPLE FLAT BLUE MENU ITEM
  // ===============================
  Widget _menuItem(int index, IconData icon, String title) {
    final bool selected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          zpracujKliknuti(context, title);
        },
        hoverColor: Colors.white.withOpacity(0.05),
        splashColor: Colors.blueAccent.withOpacity(0.10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.blueAccent.withOpacity(0.15)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? Colors.blueAccent
                    : Colors.white.withOpacity(0.45),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white.withOpacity(0.95)
                      : Colors.white.withOpacity(0.60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getPageView(int index) {
    switch (index) {
      case 0:
        return const Center(
          child: Text("Zde bude home_view.dart",
              style: TextStyle(color: Colors.grey)),
        );
      case 1:
        return const Center(
          child: Text("Zde bude import_view.dart",
              style: TextStyle(color: Colors.grey)),
        );
      case 2:
        return const Center(
          child: Text("Sekce Analýza",
              style: TextStyle(color: Colors.grey)),
        );
      case 3:
        return const SettingsView();
      default:
        return const Center(child: Text("Stránka nenalezena"));
    }
  }
}
