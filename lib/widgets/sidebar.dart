import 'package:flutter/material.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const Color _mainBg = Color(0xFF111111);
  static const Color _sidebarTop = Color(0xFF161616); 
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _glassBorder = Color(0x1AFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_sidebarTop, _mainBg],
        ),
        border: const Border(
          right: BorderSide(color: _glassBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAppHeader(),
          const SizedBox(height: 20),

          _buildSectionTitle("VSTUP"),
          _navItem(0, Icons.move_to_inbox_rounded, "Drop Zone (Ingesce)"),

          const SizedBox(height: 16),

          _buildSectionTitle("ZPRACOVÁNÍ"),
          _navItem(1, Icons.description_outlined, "Nabídky / Poptávky"),
          _navItem(2, Icons.shopping_cart_outlined, "Výrobní Objednávky"),

          const SizedBox(height: 16),

          _buildSectionTitle("NÁSTROJE"),
          _navItem(3, Icons.link_rounded, "Párování příloh"),
          _navItem(4, Icons.rule_folder_outlined, "Validator dat"),
          _navItem(5, Icons.output_rounded, "Export do CRM"),

          const Spacer(),

          _buildSectionTitle("SYSTÉM"),
          _navItem(6, Icons.tune_rounded, "Mapovací profily"),
          _navItem(7, Icons.settings_outlined, "Nastavení"),
          
          const SizedBox(height: 16),
          _buildFooter(),
          const SizedBox(height: 24), 
        ],
      ),
    );
  }

  Widget _buildAppHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 10),
      child: Row(
        children: [
          Container(
            height: 28, width: 28,
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: _accentColor.withOpacity(0.4), blurRadius: 8)
              ]
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("MRB BRIDGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
              Text("ETL Tool v0.4.0", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final bool isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: () => onItemSelected(index, label),
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.white.withOpacity(0.03),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.04) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? _accentColor : Colors.white.withOpacity(0.4),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
              if (isSelected) ...[
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.5),
                        blurRadius: 6,
                      )
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "SYSTEM READY",
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}