import 'package:flutter/material.dart';
import '../../logic/smart_mapping_engine.dart';

class MappingReviewDialog extends StatefulWidget {
  final List<MappingMatch> initialMatches;
  final List<String> allExcelHeaders;

  const MappingReviewDialog({
    super.key,
    required this.initialMatches,
    required this.allExcelHeaders,
  });

  @override
  State<MappingReviewDialog> createState() => _MappingReviewDialogState();
}

class _MappingReviewDialogState extends State<MappingReviewDialog> {
  late Map<String, String?> _currentMapping;
  bool _saveAsProfile = false;
  late List<String> _cleanedHeaders;

  // Designové konstanty systému BRIDGE
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _accentColor = Color(0xFF4077D1);

  @override
  void initState() {
    super.initState();
    
    // 1. ČIŠTĚNÍ HLAVIČEK (Dle analýzy): Odstranění prázdných a duplicitních názvů
    // Používáme Set pro unikátnost a trim pro čistotu
    _cleanedHeaders = widget.allExcelHeaders
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toSet() 
        .toList();

    // 2. Inicializace mapování
    _currentMapping = {
      for (var m in widget.initialMatches) m.systemField: m.excelColumn
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _bgCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _borderColor, width: 2),
      ),
      title: _buildHeader(),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGuidanceBox(),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.initialMatches.length,
                itemBuilder: (context, index) => _buildMappingRow(widget.initialMatches[index]),
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileOption(),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.all(20),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ZRUŠIT", style: TextStyle(color: Colors.white24, letterSpacing: 1)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, _currentMapping),
          child: const Text("POTVRDIT A POKRAČOVAT", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // --- KOMPONENTY DIALOGU ---

  Widget _buildMappingRow(MappingMatch match) {
    // Dynamická barva podle úrovně důvěry AI
    Color statusColor = _getConfidenceColor(match.level);
    bool needsAttention = match.level == MappingConfidence.low || match.level == MappingConfidence.none;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: needsAttention ? statusColor.withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Systémové pole
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(match.systemField.replaceAll('_', ' ').toUpperCase(), 
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(needsAttention ? "KONTROLA NUTNÁ" : "NAMAPOVÁNO", 
                  style: TextStyle(color: statusColor.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          const Icon(Icons.arrow_forward_rounded, color: Colors.white10, size: 16),
          const SizedBox(width: 16),

          // Dropdown se sloupci z Excelu
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _cleanedHeaders.contains(_currentMapping[match.systemField]) 
                         ? _currentMapping[match.systemField] 
                         : null, // Ochrana proti neplatným hodnotám
                  dropdownColor: const Color(0xFF1E2127),
                  isExpanded: true,
                  icon: const Icon(Icons.unfold_more_rounded, color: Colors.white24, size: 18),
                  
                  // Položky dropdownu (Včetně možnosti NEMAPOVAT)
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text("NEMAPOVAT", style: TextStyle(color: Colors.white24, fontSize: 12)),
                    ),
                    ..._cleanedHeaders.map((header) => DropdownMenuItem<String?>(
                      value: header,
                      child: Text(header, style: const TextStyle(color: Colors.white70, fontSize: 12, overflow: TextOverflow.ellipsis)),
                    )),
                  ],
                  onChanged: (val) => setState(() => _currentMapping[match.systemField] = val),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- POMOCNÉ UI METODY ---

  Color _getConfidenceColor(MappingConfidence level) {
    switch (level) {
      case MappingConfidence.high: return Colors.greenAccent;
      case MappingConfidence.medium: return Colors.orangeAccent;
      default: return Colors.redAccent;
    }
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        Icon(Icons.auto_awesome_outlined, color: Colors.amberAccent, size: 22),
        SizedBox(width: 12),
        Text("KONTROLA MAPOVÁNÍ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildGuidanceBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        "Zkontrolujte, zda sloupce z Excelu souhlasí se systémovými poli. Duplicitní a prázdné sloupce byly automaticky skryty.",
        style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
      ),
    );
  }

  Widget _buildProfileOption() {
    return Row(
      children: [
        const Icon(Icons.bookmark_outline, color: Colors.white24, size: 18),
        const SizedBox(width: 12),
        const Text("ULOŽIT TENTO FORMÁT JAKO PROFIL", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        const Spacer(),
        Switch(
          value: _saveAsProfile,
          activeThumbColor: _accentColor,
          onChanged: (v) => setState(() => _saveAsProfile = v),
        ),
      ],
    );
  }
}