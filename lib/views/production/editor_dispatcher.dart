// lib/views/production/editor_dispatcher.dart

import 'package:flutter/material.dart';
import '../../logic/workflow_controller.dart';
import 'offer_editor_view.dart';
import 'order_editor_view.dart';

class EditorDispatcher extends StatelessWidget {
  const EditorDispatcher({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WorkflowController(),
      builder: (context, _) {
        final state = WorkflowController();
        
        return Column(
          children: [
            // --- TECHNICKÁ LIŠTA EDITORU ---
            _buildModeHeader(state),
            
            // --- DYNAMICKÝ OBSAH ---
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: state.docType == DocType.order 
                  ? const OrderEditorView(key: ValueKey("order"))
                  : const OfferEditorView(key: ValueKey("offer")),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeHeader(WorkflowController state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF16181D),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2D35))),
      ),
      child: Row(
        children: [
          const Text("TYP DOKUMENTU:", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          _modeButton("NABÍDKA", DocType.offer, state),
          const SizedBox(width: 8),
          _modeButton("OBJEDNÁVKA", DocType.order, state),
          const Spacer(),
          const Icon(Icons.auto_awesome_outlined, color: Colors.amberAccent, size: 14),
          const SizedBox(width: 8),
          const Text("AI ANALÝZA AKTIVNÍ", style: TextStyle(color: Colors.amberAccent, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _modeButton(String label, DocType type, WorkflowController state) {
    final bool active = state.docType == type;
    final Color accent = const Color(0xFF4077D1);

    return InkWell(
      onTap: () => state.setDocType(type),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? accent : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white24,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}