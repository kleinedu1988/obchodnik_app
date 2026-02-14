import 'package:flutter/material.dart';

// =============================================================
//  MODEL NAVIGACE
// =============================================================

enum StepStatus { locked, waiting, processing, error, done }

// typ dokumentu z rozpoznání (nabídka/objednávka)
enum DocType { unknown, offer, order }

abstract class NavItem {
  final int index;
  final IconData icon;
  final String label;

  const NavItem({
    required this.index,
    required this.icon,
    required this.label,
  });
}

class WorkflowStep extends NavItem {
  final StepStatus status;

  const WorkflowStep({
    required super.index,
    required super.icon,
    required super.label,
    required this.status,
  });
}

class SystemItem extends NavItem {
  const SystemItem({
    required super.index,
    required super.icon,
    required super.label,
  });
}

// =============================================================
//  SIDEBAR
// =============================================================

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;

  const Sidebar({
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
    // =========================================================
    // DEMO: sem později napojíš reálný stav aplikace
    // =========================================================

    // Simulace: systém rozpoznal dokument (změň na offer/order/unknown pro test)
    const DocType docType = DocType.offer; // unknown | offer | order

    // Status pro editor krok podle docType:
    // - unknown: čeká na volbu uživatele (neukazujeme ikonku)
    // - offer/order: může běžet nebo být hotový
    const StepStatus editorStatus = StepStatus.processing;

    // Pokud typ není určen, downstream kroky zamkni
    final StepStatus downstreamStatus = (docType == DocType.unknown) ? StepStatus.locked : StepStatus.waiting;

    // Dynamický label a ikonka pro editor krok
    final String editorLabel = switch (docType) {
      DocType.offer => "Příprava nabídky",
      DocType.order => "Příprava objednávky",
      DocType.unknown => "Příprava dokumentu",
    };

    final IconData editorIcon = switch (docType) {
      DocType.offer => Icons.description_outlined,
      DocType.order => Icons.shopping_cart_outlined,
      DocType.unknown => Icons.description_outlined,
    };

    // =========================================================
    // NAV ITEMS
    // =========================================================

    const itemsInput = <NavItem>[
      WorkflowStep(
        index: 0,
        icon: Icons.move_to_inbox_rounded,
        label: "Drop Zone (Ingesce)",
        status: StepStatus.done,
      ),
    ];

    final itemsEditor = <NavItem>[
      WorkflowStep(
        index: 1,
        icon: editorIcon,
        label: editorLabel,
        // Pokud docType == unknown, dávám waiting (ticho v UI) – krok existuje, ale čeká na rozhodnutí
        status: (docType == DocType.unknown) ? StepStatus.waiting : editorStatus,
      ),
    ];

    final itemsProcessing = <NavItem>[
      WorkflowStep(
        index: 3,
        icon: Icons.link_rounded,
        label: "Párování výkresů",
        status: downstreamStatus,
      ),
      WorkflowStep(
        index: 4,
        icon: Icons.playlist_add_check_rounded,
        label: "Validace Operací",
        status: downstreamStatus,
      ),
      WorkflowStep(
        index: 5,
        icon: Icons.output_rounded,
        label: "Export do CRM",
        status: downstreamStatus,
      ),
    ];

    const itemsSystem = <NavItem>[
      SystemItem(
        index: 6,
        icon: Icons.tune_rounded,
        label: "Mapovací profily",
      ),
      SystemItem(
        index: 7,
        icon: Icons.settings_outlined,
        label: "Nastavení",
      ),
    ];

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

          _buildSectionTitle("VSTUP DAT"),
          ...itemsInput.map(_navItemFromModel),

          const SizedBox(height: 16),

          _buildSectionTitle("EDITOR"),
          ...itemsEditor.map(_navItemFromModel),

          const SizedBox(height: 16),

          _buildSectionTitle("ZPRACOVÁNÍ"),
          ...itemsProcessing.map(_navItemFromModel),

          const Spacer(),

          _buildSectionTitle("SYSTÉM"),
          ...itemsSystem.map(_navItemFromModel),

          const SizedBox(height: 16),
          _buildFooter(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // =============================================================
  //  RENDERER PRO NAVITEM (WorkflowStep vs SystemItem)
  // =============================================================

  Widget _navItemFromModel(NavItem item) {
    if (item is WorkflowStep) {
      return _navItem(
        item.index,
        item.icon,
        item.label,
        status: item.status,
      );
    }

    return _navItem(
      item.index,
      item.icon,
      item.label,
      status: null,
    );
  }

  // =============================================================
  //  NAV ITEM + (OPTIONAL) STATUS
  //  UX pravidlo: status ukazujeme jen když (processing || error).
  // =============================================================

  Widget _navItem(int index, IconData icon, String label, {StepStatus? status}) {
    final bool isSelected = selectedIndex == index;
    final bool isLocked = status == StepStatus.locked; // když není status => false

    // Přehlednost: ukazuj pouze „běží“ nebo „chyba“
    final bool showStatus = status == StepStatus.processing || status == StepStatus.error;

    final tile = AnimatedContainer(
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

          if (showStatus && status != null) _buildStatusIcon(status),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Opacity(
        opacity: isLocked ? 0.2 : 1.0,
        child: InkWell(
          onTap: isLocked ? null : () => onItemSelected(index, label),
          borderRadius: BorderRadius.circular(8),
          hoverColor: isLocked ? Colors.transparent : Colors.white.withOpacity(0.03),
          highlightColor: Colors.transparent,
          splashColor: isLocked ? Colors.transparent : _accentColor.withOpacity(0.10),
          child: tile,
        ),
      ),
    );
  }

  Widget _buildStatusIcon(StepStatus status) {
    switch (status) {
      case StepStatus.error:
        return const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14);
      case StepStatus.processing:
        return _buildPulsingDot();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPulsingDot() => const _PulsingDot(color: _accentColor, size: 10);

  // --- UI KOMPONENTY (Stejné jako předtím) ---

  Widget _buildAppHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 10),
      child: Row(
        children: [
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: _accentColor.withOpacity(0.4), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "MRB BRIDGE APP",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "CRM Pre-processor v0.4.0",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
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

// =============================================================
//  PULSING DOT
// =============================================================
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulsingDot({required this.color, this.size = 10});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_c.value);
        final glow = 2 + (6 * t);
        final alpha = 0.10 + (0.30 * t);

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(alpha),
                blurRadius: glow,
                spreadRadius: 0.5 + (0.8 * t),
              ),
            ],
          ),
        );
      },
    );
  }
}
