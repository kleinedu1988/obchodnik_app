import 'package:flutter/material.dart';
import '../../logic/notifications.dart';
import 'package:path/path.dart' as p;

class OfferEditorView extends StatefulWidget {
  const OfferEditorView({super.key});

  @override
  State<OfferEditorView> createState() => _OfferEditorViewState();
}

class _OfferEditorViewState extends State<OfferEditorView> {
  // --- DESIGN KONSTANTY ---
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;

  // --- STAV EDITORU ---
  final TextEditingController _customerCtrl = TextEditingController();
  final TextEditingController _offerIdCtrl = TextEditingController(text: "NAB-2026-0001");
  final DateTime _selectedDate = DateTime.now();
  
  // Simulace dat z Ingesce (v reálu přijdou přes WorkflowController nebo Service)
  final List<String> _attachedDrawings = ["vykres_hridel_v1.pdf", "prizma_base.step", "schema_zapojeni.pdf"];

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
                // LEVÝ SLOUPEC: Hlavní formulář
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSectionCard("OBCHODNÍ ÚDAJE", _buildBusinessForm()),
                        const SizedBox(height: 20),
                        _buildSectionCard("POLOŽKY NABÍDKY (VÝROBA)", _buildPositionsTable()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // PRAVÝ SLOUPEC: Dokumentace & Meta
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildSectionCard("DOKUMENTACE Z INGESCE", _buildFilesList()),
                      const SizedBox(height: 20),
                      _buildStatusCard(),
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

  // --- UI KOMPONENTY ---

  Widget _buildTopActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("REDAKCE NABÍDKY", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            Text("PRACOVNÍ REŽIM: RUČNÍ ZPRACOVÁNÍ", style: TextStyle(color: _accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        Row(
          children: [
            _actionBtn("ULOŽIT KONCEPT", Icons.save_outlined, Colors.white24, () {}),
            const SizedBox(width: 12),
            _actionBtn("VALIDOVAT DATA", Icons.analytics_outlined, _accentColor, () {
              Notifications.showSuccess(context, "DATA JSOU KONZISTENTNÍ");
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

  Widget _buildBusinessForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _inputField("IDENTIFIKÁTOR NABÍDKY", _offerIdCtrl, icon: Icons.tag)),
            const SizedBox(width: 16),
            Expanded(child: _inputField("ZÁKAZNÍK (Hledat v DB)", _customerCtrl, icon: Icons.business_center)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _inputField("TERMÍN DODÁNÍ", TextEditingController(text: "14 dní"), icon: Icons.calendar_today)),
            const SizedBox(width: 16),
            Expanded(child: _inputField("ZODPOVĚDNÁ OSOBA", TextEditingController(text: "Ing. Petr Novák"), icon: Icons.person_outline)),
          ],
        ),
      ],
    );
  }

  Widget _buildPositionsTable() {
    return Column(
      children: [
        // Hlavička tabulky
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor))),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text("NÁZEV / VÝKRES", style: TextStyle(color: _textDim, fontSize: 9))),
              Expanded(flex: 1, child: Text("MATERIÁL", style: TextStyle(color: _textDim, fontSize: 9))),
              Expanded(flex: 1, child: Text("KS", style: TextStyle(color: _textDim, fontSize: 9))),
              Expanded(flex: 1, child: Text("OPERACE", style: TextStyle(color: _textDim, fontSize: 9))),
            ],
          ),
        ),
        // Simulace řádků
        _buildPositionRow("Hřídel motoru L-200", "S235JR", "12", "Soustružení"),
        _buildPositionRow("Příruba ventilu", "Nerez A4", "5", "Frézování, Laser"),
      ],
    );
  }

  Widget _buildPositionRow(String name, String mat, String ks, String ops) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor, width: 0.5))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text(mat, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontFamily: 'monospace'))),
          Expanded(flex: 1, child: Text(ks, style: const TextStyle(color: Colors.white, fontSize: 11))),
          Expanded(flex: 1, child: Text(ops, style: const TextStyle(color: Colors.purpleAccent, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    return Column(
      children: _attachedDrawings.map((file) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(p.extension(file) == '.pdf' ? Icons.picture_as_pdf : Icons.view_in_ar, size: 14, color: _accentColor),
            const SizedBox(width: 10),
            Expanded(child: Text(file, style: const TextStyle(color: Colors.white70, fontSize: 11))),
            const Icon(Icons.link_rounded, size: 14, color: Colors.white10),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: _accentColor, size: 16),
              SizedBox(width: 10),
              Text("STAV NABÍDKY", style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          _statusInfoRow("Rozpracovanost", "45 %"),
          _statusInfoRow("Validace příloh", "OK"),
        ],
      ),
    );
  }

  // --- POMOCNÉ PRVKY ---

  Widget _inputField(String label, TextEditingController ctrl, {IconData? icon}) {
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
            style: const TextStyle(color: Colors.white, fontSize: 12),
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

  Widget _statusInfoRow(String l, String v) {
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