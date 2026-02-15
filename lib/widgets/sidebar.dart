// lib/ui/widgets/sidebar.dart

import 'package:flutter/material.dart';
import '../../logic/workflow_controller.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int, String) onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  // Barvy designu BRIDGE
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _errorColor = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WorkflowController(),
      builder: (context, _) {
        final state = WorkflowController();

        return Container(
          width: 260,
          decoration: const BoxDecoration(
            color: Color(0xFF16181D),
            border: Border(right: BorderSide(color: Colors.white10, width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),

              _buildSection("VSTUP DAT"),
              _buildMenuItem(0, Icons.move_to_inbox_rounded, "Drop Zone", state),

              _buildSection("EDITOR"),
              _buildMenuItem(1, 
                state.docType == DocType.offer ? Icons.description_outlined : Icons.shopping_cart_outlined, 
                state.docType == DocType.offer ? "Příprava nabídky" : "Příprava objednávky", 
                state),

              _buildSection("ZPRACOVÁNÍ"),
              _buildMenuItem(2, Icons.link_rounded, "Párování výkresů", state),
              _buildMenuItem(3, Icons.verified_user_outlined, "Validace dat", state),
              _buildMenuItem(4, Icons.output_rounded, "Export do CRM", state),

              const Spacer(),
              _buildSection("SYSTÉM"),
              _buildMenuItem(5, Icons.tune_rounded, "Mapovací profily", state),
              _buildMenuItem(6, Icons.settings_outlined, "Nastavení", state),
              
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  //  STAVOVÝ RENDERER POLOŽKY
  // ===========================================================================

  Widget _buildMenuItem(int index, IconData icon, String label, WorkflowController workflow) {
    // Načteme stav konkrétní položky z matrixu v controlleru
    final itemState = workflow.sidebarStates[index] ?? const SidebarItemState();
    
    final bool isSelected = selectedIndex == index;
    final bool isEnabled = itemState.isEnabled;
    
    // Určení barvy podle stavu (Neutral / Success / Error)
    Color statusColor;
    IconData? statusIcon;

    switch (itemState.status) {
      case ItemStatus.success:
        statusColor = _successColor;
        statusIcon = Icons.check_circle_rounded;
        break;
      case ItemStatus.error:
        statusColor = _errorColor;
        statusIcon = Icons.error_rounded;
        break;
      case ItemStatus.neutral:
        statusColor = isSelected ? _accentColor : Colors.white24;
        statusIcon = null;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Opacity(
        // Vizuální znázornění disabled stavu
        opacity: isEnabled ? 1.0 : 0.3,
        child: InkWell(
          // Pokud je disabled, kliknutí nedělá nic
          onTap: isEnabled ? () => onItemSelected(index, label) : null,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _accentColor.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? _accentColor.withOpacity(0.2) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                // IKONA POLOŽKY
                Icon(icon, size: 18, color: isSelected ? _accentColor : Colors.white54),
                const SizedBox(width: 14),
                
                // TEXT POLOŽKY
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.white60,
                    ),
                  ),
                ),

                // STAVOVÉ INDIKÁTORY (Vpravo)
                if (itemState.isProcessing)
                  const _PulsingIndicator(color: _accentColor)
                else if (statusIcon != null)
                  Icon(statusIcon, size: 14, color: statusColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- POMOCNÉ PRVKY ---

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Text(title, style: const TextStyle(color: Colors.white10, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Row(
        children: [
          Icon(Icons.hub_rounded, color: _accentColor, size: 24),
          SizedBox(width: 12),
          Text("BRIDGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        ],
      ),
    );
  }
}

// --- ANIMOVANÁ TEČKA ---
class _PulsingIndicator extends StatefulWidget {
  final Color color;
  const _PulsingIndicator({required this.color});

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.7, end: 1.2).animate(_c),
      child: Container(
        width: 8, height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color, boxShadow: [BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 4)]),
      ),
    );
  }
}