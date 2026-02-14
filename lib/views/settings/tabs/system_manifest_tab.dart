import 'package:flutter/material.dart';

// =============================================================
//  MODEL: MANIFEST MODULU
// =============================================================
class ModuleManifest {
  final String id;
  final String name;
  final String version;
  final String status;
  final double completion;

  const ModuleManifest({
    required this.id, required this.name, required this.version,
    required this.status, required this.completion,
  });
}

// =============================================================
//  DATA: REGISTR VERZÍ (Aktualizováno pro v0.4.2)
// =============================================================
const List<ModuleManifest> systemModules = [
  ModuleManifest(id: "CORE", name: "Jádro Aplikace (Shell)", version: "0.4.4", status: "Beta", completion: 0.46),
  ModuleManifest(id: "NAV", name: "Sidebar & Navigace", version: "0.8.0", status: "Stable", completion: 0.95),
  ModuleManifest(id: "ING", name: "Ingestion Engine (Drop)", version: "0.3.0", status: "Alpha", completion: 0.40),
  ModuleManifest(id: "DB", name: "Zákaznická Databáze", version: "0.4.0", status: "Stable", completion: 0.90),
  ModuleManifest(id: "OPS", name: "Výrobní Operace", version: "1.0.0", status: "Stable", completion: 1.0),
  ModuleManifest(id: "MAT", name: "Katalog Materiálů", version: "1.0.0", status: "Stable", completion: 1.0), // NOVÝ MODUL
  ModuleManifest(id: "AI", name: "Inteligentní Mapování", version: "0.0.1", status: "Planning", completion: 0.05),
  ModuleManifest(id: "OUT", name: "Export & Tisk", version: "0.0.0", status: "Pending", completion: 0.00),
];

// =============================================================
//  VIEW: SYSTÉMOVÝ PŘEHLED
// =============================================================
class SystemManifestTab extends StatelessWidget {
  const SystemManifestTab({super.key});

  static const Color _cardBg = Color(0xFF16181D);
  static const Color _borderColor = Color(0xFF2A2D35);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // INFORMAČNÍ LIŠTA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 12),
                const Text("Build: 2024.05.22-release  |  Environment: Production  |  SQLite: 3.40",
                  style: TextStyle(color: Colors.blueAccent, fontFamily: 'monospace', fontSize: 12)),
                const Spacer(),
                Text("MRB BRIDGE APP", style: TextStyle(color: Colors.white.withOpacity(0.2), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 2)),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // HLAVIČKA TABULKY
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _headerCell("ID", 60),
                _headerCell("NÁZEV MODULU", 200, flex: 2),
                _headerCell("VERZE", 100),
                _headerCell("STAV VÝVOJE", 120),
                _headerCell("KOMPLETNOST", 150),
              ],
            ),
          ),
          Divider(color: _borderColor, height: 1),

          // SEZNAM
          Expanded(
            child: ListView.separated(
              itemCount: systemModules.length,
              separatorBuilder: (ctx, i) => Divider(color: _borderColor, height: 1),
              itemBuilder: (ctx, index) => _buildListRow(systemModules[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListRow(ModuleManifest module) {
    return Container(
      color: _cardBg.withOpacity(0.3), // Zebra efekt volitelný
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(module.id, style: const TextStyle(color: Colors.white30, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text(module.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
          SizedBox(width: 100, child: Text("v${module.version}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'))),
          SizedBox(width: 120, child: Align(alignment: Alignment.centerLeft, child: _buildStatusChip(module.status))),
          SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: module.completion, backgroundColor: Colors.white.withOpacity(0.05), color: _getColorForStatus(module.status), minHeight: 4)),
            const SizedBox(height: 4),
            Text("${(module.completion * 100).toInt()}%", style: const TextStyle(color: Colors.white24, fontSize: 9)),
          ])),
        ],
      ),
    );
  }

  Widget _headerCell(String label, double width, {int flex = 0}) {
    final text = Text(label, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1));
    return flex > 0 ? Expanded(flex: flex, child: text) : SizedBox(width: width, child: text);
  }

  Widget _buildStatusChip(String status) {
    Color c = _getColorForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), border: Border.all(color: c.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Color _getColorForStatus(String status) {
    switch (status) {
      case 'Stable': return Colors.greenAccent;
      case 'Beta': return Colors.blueAccent;
      case 'Alpha': return Colors.orangeAccent;
      case 'Planning': return Colors.purpleAccent;
      default: return Colors.grey;
    }
  }
}