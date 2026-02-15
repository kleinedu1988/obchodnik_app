import 'package:flutter/material.dart';

// --- LOGIKA ---
import '../../../logic/workflow_controller.dart';

// --- POHLEDY ---
import 'offer_editor_view.dart';
import 'order_editor_view.dart';

/// EDITOR DISPATCHER: Dynamický rozcestník pro editační režimy.
/// Tento widget je aktivní pouze tehdy, když Policista (WorkflowController)
/// odemkne průjezd do fáze editace.
class EditorDispatcher extends StatelessWidget {
  const EditorDispatcher({super.key});

  // Designové konstanty systému BRIDGE
  static const Color _bgHeader = Color(0xFF16181D);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _accentColor = Color(0xFF4077D1);

  @override
  Widget build(BuildContext context) {
    // Používáme singleton instanci controlleru
    final workflow = WorkflowController();

    return ListenableBuilder(
      listenable: workflow,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F1115),
          body: Column(
            children: [
              // --- 1. TECHNICKÁ LIŠTA (Navigace a Přepínání) ---
              _buildModeHeader(context, workflow),

              // --- 2. OBSAHOVÁ OBLAST (Editor s animací přechodu) ---
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  // Klíče jsou kritické pro správné překreslení při změně typu
                  child: workflow.docType == DocType.order
                      ? const OrderEditorView(key: ValueKey("view_order"))
                      : const OfferEditorView(key: ValueKey("view_offer")),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  //  UI KOMPONENTY
  // ===========================================================================

  Widget _buildModeHeader(BuildContext context, WorkflowController state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: _bgHeader,
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // TLAČÍTKO RESET: Vyčistí data a vrátí uživatele do Ingesce
          _buildBackButton(state),
          
          const SizedBox(width: 24),
          const Text(
            "REŽIM EDITORU:", 
            style: TextStyle(
              color: Colors.white24, 
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 1.2
            )
          ),
          const SizedBox(width: 16),

          // PŘEPÍNAČE KONTEXTU
          _modeButton("NABÍDKA", DocType.offer, state),
          const SizedBox(width: 8),
          _modeButton("VÝROBA", DocType.order, state),
          
          const Spacer(),

          // INFORMACE O SOURCE DATA
          _buildAIStatusIndicator(state),
        ],
      ),
    );
  }

  Widget _buildBackButton(WorkflowController state) {
    return Tooltip(
      message: "Zahodit změny a nahrát nové soubory",
      child: InkWell(
        onTap: () => state.reset(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _modeButton(String label, DocType type, WorkflowController state) {
    final bool active = state.docType == type;

    return InkWell(
      onTap: () => state.setDocType(type),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _accentColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? _accentColor : Colors.white10,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white30,
            fontSize: 10,
            fontWeight: active ? FontWeight.w900 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAIStatusIndicator(WorkflowController state) {
    final bool isSmart = state.lastIngestion?.hasExcel ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSmart ? Colors.amberAccent.withOpacity(0.05) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSmart ? Colors.amberAccent.withOpacity(0.2) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSmart ? Icons.auto_awesome : Icons.edit_note_rounded, 
            color: isSmart ? Colors.amberAccent : Colors.white24, 
            size: 14
          ),
          const SizedBox(width: 10),
          Text(
            isSmart ? "AUTO-MAPPED" : "MANUAL ENTRY",
            style: TextStyle(
              color: isSmart ? Colors.amberAccent : Colors.white24, 
              fontSize: 9, 
              fontWeight: FontWeight.bold
            ),
          ),
        ],
      ),
    );
  }
}