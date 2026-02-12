import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  // BARVY: Sjednoceno s main.dart (0xFF111111)
  static const Color _mainBg = Color(0xFF111111);
  // Sidebar uděláme o chloupek světlejší nahoře pro efekt dopadajícího světla
  static const Color _sidebarTop = Color(0xFF161616); 
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _glassBorder = Color(0x1AFFFFFF); // 10% bílá

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        // GRADIENT: Místo černé plochy jemný přechod, který sidebar "vytáhne" ven
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
          const SizedBox(height: 32),

          _buildSectionTitle("HLAVNÍ"),
          _navItem(0, Icons.grid_view_rounded, "Dashboard"),
          _navItem(1, Icons.person_search_rounded, "Zákazníci"),
          _navItem(2, Icons.analytics_outlined, "Analýza"),

          const SizedBox(height: 24),

          _buildSectionTitle("NÁSTROJE"),
          _navItem(4, Icons.file_upload_outlined, "Import dat"),

          const Spacer(),

          _navItem(3, Icons.settings_outlined, "Nastavení"),
          
          const SizedBox(height: 16),
          _buildFooter(),
          const SizedBox(height: 32), 
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.2), // Zvýšena viditelnost nadpisu
          fontSize: 10,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            // HYBRID GLASS: Pokud je vybráno, prvek mírně "svítí" zevnitř
            color: isSelected ? Colors.white.withOpacity(0.04) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // IKONA: Sytější barva, aby se v charcoal barvě neutopila
              Icon(
                icon,
                size: 20,
                color: isSelected ? _accentColor : Colors.white.withOpacity(0.4),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                // Aktivní indikátor s mírným glow
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
            "v1.2.5 • ONLINE",
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