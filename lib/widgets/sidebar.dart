import 'package:flutter/material.dart';
import '../../logic/workflow_controller.dart'; // Ujisti se, že cesta sedí

// =============================================================
//  MODELY NAVIGACE
// =============================================================

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
//  SIDEBAR WIDGET
// =============================================================

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  // Design Konstanty
  static const Color _mainBg = Color(0xFF111111);
  static const Color _sidebarTop = Color(0xFF161616);
  static const Color _accentColor = Color(0xFF4077D1); // Tvá modrá
  static const Color _glassBorder = Color(0x1AFFFFFF);

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder sleduje jedinou instanci WorkflowControlleru
    return ListenableBuilder(
      listenable: WorkflowController(),
      builder: (context, _) {
        final state = WorkflowController();

        // 1. Logika downstream zámků (odemkne se po ingesci)
        final StepStatus downstreamStatus =
            state.isIngestionDone ? StepStatus.waiting : StepStatus.locked;

        // 2. Dynamické popisky Editoru
        final String editorLabel = switch (state.docType) {
          DocType.offer => "Příprava nabídky",
          DocType.order => "Příprava objednávky",
          DocType.unknown => "Příprava dokumentu",
        };

        final IconData editorIcon = switch (state.docType) {
          DocType.offer => Icons.description_outlined,
          DocType.order => Icons.shopping_cart_outlined,
          DocType.unknown => Icons.description_outlined,
        };

        // --- DEFINICE POLOŽEK ---
        final itemsInput = [
          WorkflowStep(
            index: 0,
            icon: Icons.move_to_inbox_rounded,
            label: "Drop Zone (Ingesce)",
            status: state.isIngestionDone ? StepStatus.done : StepStatus.processing,
          ),
        ];

        final itemsEditor = [
          WorkflowStep(
            index: 1,
            icon: editorIcon,
            label: editorLabel,
            status: state.isIngestionDone ? StepStatus.processing : StepStatus.locked,
          ),
        ];

        final itemsProcessing = [
          WorkflowStep(index: 2, icon: Icons.link_rounded, label: "Párování výkresů", status: downstreamStatus),
          WorkflowStep(index: 3, icon: Icons.playlist_add_check_rounded, label: "Validace Operací", status: downstreamStatus),
          WorkflowStep(index: 4, icon: Icons.output_rounded, label: "Export do CRM", status: downstreamStatus),
        ];

        final itemsSystem = [
          const SystemItem(index: 5, icon: Icons.tune_rounded, label: "Mapovací profily"),
          const SystemItem(index: 6, icon: Icons.settings_outlined, label: "Nastavení"),
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
      },
    );
  }

  // =============================================================
  //  POMOCNÉ RENDERERY
  // =============================================================

  Widget _navItemFromModel(NavItem item) {
    return _navItem(
      item.index,
      item.icon,
      item.label,
      status: (item is WorkflowStep) ? item.status : null,
    );
  }

  Widget _navItem(int index, IconData icon, String label, {StepStatus? status}) {
    final bool isSelected = selectedIndex == index;
    final bool isLocked = status == StepStatus.locked;
    final bool isDone = status == StepStatus.done;
    final bool isDisabled = isLocked || isDone;

    final bool showStatus = status == StepStatus.processing || status == StepStatus.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Opacity(
        // Pokud je hotovo, necháme barvu o něco výraznější než u zamčeného (0.5 vs 0.2)
        opacity: isLocked ? 0.2 : (isDone ? 0.6 : 1.0),
        child: InkWell(
          // Pokud je zamčeno NEBO hotovo, klikání je vypnuté
          onTap: isDisabled ? null : () => onItemSelected(index, label),
          borderRadius: BorderRadius.circular(8),
          hoverColor: isDisabled ? Colors.transparent : Colors.white.withOpacity(0.03),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  // Změna barvy ikony pro hotový krok
                  color: isDone ? Colors.greenAccent.withOpacity(0.7) : (isSelected ? _accentColor : Colors.white.withOpacity(0.4)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                      // Pokud je hotovo, text může být mírně zešedlý
                    ),
                  ),
                ),
                
                // Pulzující bod pro probíhající krok
                if (showStatus && status != null) _buildStatusIcon(status),
                
                // ZELENÝ CHECK pro hotový krok
                if (isDone)
                   const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(StepStatus status) {
    if (status == StepStatus.error) {
      return const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14);
    }
    return const _PulsingDot(color: _accentColor, size: 8);
  }

  // --- UI KOMPONENTY ---

  Widget _buildAppHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 10),
      child: Row(
        children: [
          Container(
            height: 30, width: 30,
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: _accentColor.withOpacity(0.3), blurRadius: 10)],
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("MRB BRIDGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
              Text("DATA PROCESSOR", style: TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Text(title, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text("ENGINE v0.4.2 READY", style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// =============================================================
//  ANIMOVANÝ PULZUJÍCÍ BOD
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
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
        return Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.2 + (0.4 * _c.value)),
                blurRadius: 4 + (4 * _c.value),
                spreadRadius: 1 * _c.value,
              ),
            ],
          ),
        );
      },
    );
  }
}