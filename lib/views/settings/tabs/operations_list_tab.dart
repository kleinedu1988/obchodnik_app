import 'package:flutter/material.dart';
import 'dart:async';

// Importy logiky a UI
import 'package:mrb_obchodnik/logic/db_service.dart';
import 'package:mrb_obchodnik/logic/notifications.dart';

class OperationsListTab extends StatefulWidget {
  const OperationsListTab({super.key});

  @override
  State<OperationsListTab> createState() => _OperationsListTabState();
}

class _OperationsListTabState extends State<OperationsListTab> {
  // Data
  final List<Map<String, dynamic>> _seznamOperaci = [];

  // Stav vyhledávání
  Timer? _debounce;
  String _query = '';
  bool _isLoading = false;

  // Design Konstanty (Flat & Technical)
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _opColor = Color(0xFFE056FD); // Fialová pro odlišení operací
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // --- LOGIKA DAT ---

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _query = val;
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final rawData = await DbService().getOperace(query: _query);

      // Mutable copy
      final mutableData = rawData.map((e) => Map<String, dynamic>.from(e)).toList();

      if (!mounted) return;
      setState(() {
        _seznamOperaci
          ..clear()
          ..addAll(mutableData);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Notifications.showError(context, "CHYBA NAČÍTÁNÍ: $e");
    }
  }

  Future<void> _smazatOperaci(int id) async {
    try {
      await DbService().deleteOperace(id);
      if (!mounted) return;
      Notifications.showSuccess(context, "OPERACE SMAZÁNA");
      _loadData();
    } catch (e) {
      if (!mounted) return;
      Notifications.showError(context, "CHYBA MAZÁNÍ: $e");
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildControls(),
        const SizedBox(height: 24),
        _buildTableHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              : (_seznamOperaci.isEmpty ? _buildEmptyState() : _buildList()),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      itemCount: _seznamOperaci.length,
      padding: const EdgeInsets.only(bottom: 80),
      separatorBuilder: (context, index) => const Divider(color: _borderColor, height: 1),
      itemBuilder: (context, index) => _buildOperationRow(_seznamOperaci[index]),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        // SEARCH BAR
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _borderColor),
            ),
            child: TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              cursorColor: _opColor,
              decoration: InputDecoration(
                hintText: "Hledat (Kód, Název, Poznámka)...",
                hintStyle: const TextStyle(color: _textDim, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _textDim),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // PŘIDAT
        ElevatedButton.icon(
          onPressed: () => _showEditDialog(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _opColor.withOpacity(0.10),
            foregroundColor: _opColor,
            elevation: 0,
            side: BorderSide(color: _opColor.withOpacity(0.50)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            "NOVÁ OPERACE",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor, width: 2)),
      ),
      child: Row(
        children: [
          _headerText("KÓD", flex: 2),
          _headerText("NÁZEV OPERACE", flex: 4),
          _headerText("POZNÁMKA", flex: 5),
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildOperationRow(Map<String, dynamic> item) {
    final String kod = (item['kod'] ?? '').toString();
    final String nazev = (item['nazev'] ?? '').toString();
    final String poznamka = (item['poznamka'] ?? '').toString();

    return InkWell(
      onTap: () => _showEditDialog(item: item),
      hoverColor: Colors.white.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 1) KÓD
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _opColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _opColor.withOpacity(0.30)),
                  ),
                  child: Text(
                    kod,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _opColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),

            // 2) NÁZEV
            Expanded(
              flex: 4,
              child: Text(
                nazev,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),

            // 3) POZNÁMKA
            Expanded(
              flex: 5,
              child: Text(
                poznamka.isEmpty ? "—" : poznamka,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: poznamka.isEmpty ? Colors.white24 : Colors.white60,
                ),
              ),
            ),

            // 4) AKCE
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _showEditDialog(item: item),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    color: Colors.white24,
                    hoverColor: Colors.white10,
                    tooltip: "Upravit",
                  ),
                  IconButton(
                    onPressed: () => _smazatOperaci(item['id'] as int),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    color: Colors.redAccent.withOpacity(0.55),
                    hoverColor: Colors.redAccent.withOpacity(0.10),
                    tooltip: "Smazat",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DIALOG PRO PŘIDÁNÍ/EDITACI ---

  void _showEditDialog({Map<String, dynamic>? item}) {
    final isNew = item == null;

    final kodCtrl = TextEditingController(text: (item?['kod'] ?? '').toString());
    final nazevCtrl = TextEditingController(text: (item?['nazev'] ?? '').toString());
    final poznamkaCtrl = TextEditingController(text: (item?['poznamka'] ?? '').toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _borderColor),
        ),
        title: Text(
          isNew ? "Nová operace" : "Upravit operaci",
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogInput(kodCtrl, "Kód (např. LASER_2D)", isCode: true),
              const SizedBox(height: 12),
              _buildDialogInput(nazevCtrl, "Název operace"),
              const SizedBox(height: 12),
              _buildDialogInput(poznamkaCtrl, "Poznámka (volitelné)", isMultiline: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Zrušit", style: TextStyle(color: Colors.white30)),
          ),
          ElevatedButton(
            onPressed: () async {
              final kod = kodCtrl.text.trim();
              final nazev = nazevCtrl.text.trim();
              final poznamka = poznamkaCtrl.text.trim();

              if (kod.isEmpty || nazev.isEmpty) return;

              try {
                await DbService().saveOperace(
                  id: item?['id'] as int?,
                  kod: kod,
                  nazev: nazev,
                  poznamka: poznamka,
                );

                if (!mounted) return;
                Navigator.pop(ctx);
                _loadData();
                Notifications.showSuccess(context, isNew ? "OPERACE VYTVOŘENA" : "ZMĚNY ULOŽENY");
              } catch (e) {
                if (!mounted) return;
                Notifications.showError(context, "CHYBA ULOŽENÍ: $e");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _opColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Uložit"),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInput(
    TextEditingController ctrl,
    String hint, {
    bool isCode = false,
    bool isMultiline = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        maxLines: isMultiline ? 4 : 1,
        minLines: isMultiline ? 3 : 1,
        style: TextStyle(
          color: Colors.white,
          fontFamily: isCode ? 'monospace' : null,
          fontWeight: isCode ? FontWeight.bold : FontWeight.normal,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        ),
      ),
    );
  }

  // --- POMOCNÉ WIDGETY ---

  Widget _headerText(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          color: Colors.white30,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.precision_manufacturing_outlined, size: 48, color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            "Žádné výrobní operace",
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _showEditDialog(),
            child: Text(
              "VYTVOŘIT PRVNÍ",
              style: TextStyle(color: _opColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
