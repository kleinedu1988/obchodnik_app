import 'package:flutter/material.dart';

// Importy tvých tabů
import 'tabs/db_status_tab.dart';
import 'tabs/general_settings_tab.dart';
import 'tabs/customer_list_tab.dart';
import 'tabs/system_manifest_tab.dart';
import 'package:mrb_obchodnik/views/settings/tabs/operations_list_tab.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _glassBorder = Color(0x14FFFFFF);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6, // ZMĚNA: 6 tabů
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // HLAVIČKA
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  "Konfigurace",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "/  SPRÁVA DATABÁZÍ A ČÍSELNÍKŮ",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.15),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // TAB BAR (SCROLLABLE)
            Stack(
              alignment: Alignment.bottomLeft,
              children: [
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
                  labelPadding: const EdgeInsets.only(right: 32, bottom: 10),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  tabs: const [
                    // 1. OBECNÉ
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 14),
                          SizedBox(width: 8),
                          Text("Obecné"),
                        ],
                      ),
                    ),
                    // 2. ZÁKAZNÍCI
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 14),
                          SizedBox(width: 8),
                          Text("Databáze Zákazníků"),
                        ],
                      ),
                    ),
                    // 3. MATERIÁLY
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.category_outlined, size: 14),
                          SizedBox(width: 8),
                          Text("Materiály"),
                        ],
                      ),
                    ),
                    // 4. OPERACE
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.precision_manufacturing_outlined, size: 14),
                          SizedBox(width: 8),
                          Text("Výrobní Operace"),
                        ],
                      ),
                    ),
                    // 5. DIAGNOSTIKA
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.monitor_heart_outlined, size: 14),
                          SizedBox(width: 8),
                          Text("Status DB"),
                        ],
                      ),
                    ),
                    // 6. O SYSTÉMU (NOVÉ)
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14),
                          SizedBox(width: 8),
                          Text("O Systému"),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // OBSAH
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // 1. Obecné
                  const GeneralSettingsTab(),

                  // 2. Zákazníci
                  const CustomerListTab(),

                  // 3. Materiály (Placeholder)
                  _buildPlaceholderTab(
                    "Číselník materiálů",
                    "Zde se budou párovat názvy z Excelu (např. 'Černý plech')\nna kódy pro CRM (např. 'S235JR').",
                    Icons.dashboard_customize_outlined,
                  ),

                  // 4. Operace (Placeholder)
                  const OperationsListTab(),

                  // 5. Diagnostika
                  const DbStatusTab(),

                  // 6. O SYSTÉMU (NOVÉ)
                  const SystemManifestTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title, String description, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 24),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.15),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
