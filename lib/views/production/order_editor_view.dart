import 'package:flutter/material.dart';
import '../../logic/workflow_controller.dart';
import '../../logic/notifications.dart';
import 'package:path/path.dart' as p;

class OrderEditorView extends StatefulWidget {
  const OrderEditorView({super.key});

  @override
  State<OrderEditorView> createState() => _OrderEditorViewState();
}

class _OrderEditorViewState extends State<OrderEditorView> {
  // --- DESIGN KONSTANTY (v0.4.2) ---
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;
  static const Color _orderColor = Color(0xFF10B981); // Zelený akcent pro objednávky

  // --- STAV EDITORU ---
  final TextEditingController _orderIdCtrl = TextEditingController(text: "OBJ-2026-0452");
  final TextEditingController _refOfferCtrl = TextEditingController(text: "NAB-2026-0001");
  final String _priority = "STANDARD";

  // Simulace dat z Ingesce
  final List<String> _attachedFiles = ["sestava_final.pdf", "dil_01.step", "dil_02.step", "balici_predpis.txt"];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopActions(),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEVÝ SLOUPEC: Produkční data
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSectionCard("PRODUKČNÍ ÚDAJE", _buildOrderForm()),
                        const SizedBox(height: 20),
                        _buildSectionCard("POLOŽKY K VÝROBĚ", _buildProductionTable()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // PRAVÝ SLOUPEC: Přílohy a logistika
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildSectionCard("VÝROBNÍ DOKUMENTACE", _buildFilesList()),
                      const SizedBox(height: 20),
                      _buildSummaryCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("REDAKCE OBJEDNÁVKY", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            Row(
              children: [
                const Text("STATUS: ", style: TextStyle(color: _textDim, fontSize: 10)),
                Text("ČEKÁ NA POTVRZENÍ TERMÍNU", style: TextStyle(color: _orderColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _actionBtn("ZRUŠIT", Icons.close, Colors.white24, () {}),
            const SizedBox(width: 12),
            _actionBtn("ODESLAT DO VÝROBY", Icons.send_rounded, _orderColor, () {
              Notifications.showSuccess(context, "OBJEDNÁVKA BYLA PŘEDÁNA DO PRODUKCE");
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(title, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _inputField("ČÍSLO OBJEDNÁVKY", _orderIdCtrl, icon: Icons.numbers)),
            const SizedBox(width: 16),
            Expanded(child: _inputField("VAZBA NA NABÍDKU", _refOfferCtrl, icon: Icons.link)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _inputField("POTVRZENÝ TERMÍN", TextEditingController(text: "24.02.2026"), icon: Icons.event_available)),
            const SizedBox(width: 16),
            Expanded(child: _inputField("PRIORITA VÝROBY", TextEditingController(text: "VYSOKÁ"), icon: Icons.priority_high, textColor: Colors.orangeAccent)),
          ],
        ),
      ],
    );
  }

  Widget _buildProductionTable() {
    return Column(
      children: [
        _tableHeader(),
        _buildOrderRow("Sestava rámu X-Y", "Ocel 11 373", "2", "20.02."),
        _buildOrderRow("Čep kalený 20mm", "16MnCr5", "50", "18.02."),
        _buildOrderRow("Kryt plechový", "DX51D+Z", "10", "22.02."),
      ],
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor))),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text("POLOŽKA", style: TextStyle(color: _textDim, fontSize: 9))),
          Expanded(flex: 1, child: Text("MATERIÁL", style: TextStyle(color: _textDim, fontSize: 9))),
          Expanded(flex: 1, child: Text("MNOŽSTVÍ", style: TextStyle(color: _textDim, fontSize: 9))),
          Expanded(flex: 1, child: Text("DEADLINE", style: TextStyle(color: _textDim, fontSize: 9))),
        ],
      ),
    );
  }

  Widget _buildOrderRow(String name, String mat, String qty, String date) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor, width: 0.5))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text(mat, style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontFamily: 'monospace'))),
          Expanded(flex: 1, child: Text("$qty ks", style: const TextStyle(color: Colors.white70, fontSize: 11))),
          Expanded(flex: 1, child: Text(date, style: const TextStyle(color: _orderColor, fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    return Column(
      children: _attachedFiles.map((file) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(_getIconForExt(file), size: 14, color: _accentColor),
            const SizedBox(width: 10),
            Expanded(child: Text(file, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _orderColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _orderColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: _orderColor, size: 16),
              SizedBox(width: 10),
              Text("KONTROLA DAT", style: TextStyle(color: _orderColor, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow("Počet položek", "3"),
          _summaryRow("Kapacitní shoda", "ANO"),
          _summaryRow("Materiál skladem", "80 %"),
        ],
      ),
    );
  }

  // --- POMOCNÉ PRVKY ---

  IconData _getIconForExt(String file) {
    String ext = p.extension(file).toLowerCase();
    if (ext == '.pdf') return Icons.picture_as_pdf_rounded;
    if (ext == '.step' || ext == '.stp') return Icons.view_in_ar_rounded;
    return Icons.insert_drive_file_outlined;
  }

  Widget _inputField(String label, TextEditingController ctrl, {IconData? icon, Color? textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _textDim, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          height: 40,
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6), border: Border.all(color: _borderColor)),
          child: TextField(
            controller: ctrl,
            style: TextStyle(color: textColor ?? Colors.white, fontSize: 12, fontWeight: textColor != null ? FontWeight.bold : FontWeight.normal),
            decoration: InputDecoration(
              prefixIcon: icon != null ? Icon(icon, size: 16, color: Colors.white10) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String l, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(color: Colors.white24, fontSize: 11)),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }
}