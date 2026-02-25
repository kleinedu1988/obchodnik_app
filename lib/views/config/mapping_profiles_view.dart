import 'package:flutter/material.dart';

import 'tabs/profiles_editor_tab.dart';
import 'tabs/customer_profiles_tab.dart';
import 'tabs/import_test_tab.dart';

class MappingProfilesView extends StatelessWidget {
  const MappingProfilesView({super.key});

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
            const SizedBox(height: 24),

            // HLAVIČKA
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  "Mapovací profily",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "/  SPRÁVA ŠABLON PRO ROZPOZNÁVÁNÍ",
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

            // TAB BAR
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
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 14),
                          SizedBox(width: 8),
                          Text("Mapování sloupců"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.business_outlined, size: 14),
                          SizedBox(width: 8),
                          Text("Rozpoznávání zákazníků"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Icon(Icons.science_outlined, size: 14),
                          SizedBox(width: 8),
                          Text("Test importu"),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // OBSAH
            const Expanded(
              child: TabBarView(
                physics: NeverScrollableScrollPhysics(),
                children: [
                  ProfilesEditorTab(),
                  CustomerProfilesTab(),
                  ImportTestTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}