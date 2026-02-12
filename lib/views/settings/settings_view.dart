import 'package:flutter/material.dart';

// Importy tvých tabů
import 'tabs/db_status_tab.dart';
import 'tabs/customer_list_tab.dart';
import 'tabs/general_settings_tab.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  // Barvy sjednocené s tvým "Hybrid Glass" systémem
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _glassBorder = Color(0x14FFFFFF);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 24px horní padding (Slim UI)
            const SizedBox(height: 24),

            // SLIM DOUBLE HEADING (Nastavení / Konfigurace)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  "Nastavení",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "/  KONFIGURACE SYSTÉMU v2.026",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.15),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16), // 16px mezera k tabům

            // ULTRA-SLIM TABBAR S IKONAMI (Inspirace React)
            Stack(
              alignment: Alignment.bottomLeft,
              children: [
                // Skleněná linka přes celou šířku (0x14FFFFFF)
                Container(
                  height: 1,
                  width: double.infinity,
                  color: _glassBorder,
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: _accentColor,
                  indicatorWeight: 2,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.15),
                  // Větší pravý padding (32) pro vzdušnost mezi taby
                  labelPadding: const EdgeInsets.only(right: 32, bottom: 10),
                  labelStyle: const TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.bold,
                  ),
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  tabs: const [
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.terminal_rounded, size: 14), // Ikona pro databázi
                          SizedBox(width: 8),
                          Text("Stav databáze"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 14), // Ikona pro zákazníky
                          SizedBox(width: 8),
                          Text("Databáze zákazníků"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.settings_input_component_rounded, size: 14), // Obecné
                          SizedBox(width: 8),
                          Text("Obecná nastavení"),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // OBSAH - Bez zbytečného horního paddingu (React styl)
            const Expanded(
              child: TabBarView(
                physics: NeverScrollableScrollPhysics(),
                children: [
                  DbStatusTab(),
                  CustomerListTab(),
                  GeneralSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}