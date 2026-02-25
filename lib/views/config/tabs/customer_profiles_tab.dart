import 'package:flutter/material.dart';

/// Dočasný model – bude nahrazen skutečným modelem až se vyřeší persistence.
class _MockCustomer {
  String id;
  String displayName;
  String ico;
  List<String> aliases;
  List<String> keywords;
  String notes;
  Map<String, String> mappings;

  _MockCustomer({
    required this.id,
    required this.displayName,
    this.ico = '',
    this.aliases = const [],
    this.keywords = const [],
    this.notes = '',
    this.mappings = const {},
  });

  int get patternCount =>
      aliases.length + keywords.length + (ico.isNotEmpty ? 1 : 0);
}

class CustomerProfilesTab extends StatefulWidget {
  const CustomerProfilesTab({super.key});

  @override
  State<CustomerProfilesTab> createState() => _CustomerProfilesTabState();
}

class _CustomerProfilesTabState extends State<CustomerProfilesTab> {
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _glassBorder = Color(0x14FFFFFF);
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _borderColor = Color(0xFF2A2D35);

  // ── Systémová pole (stejná jako v ProfilesEditorTab) ───────────────────
  final List<Map<String, String>> _systemFields = [
    {'key': 'pos', 'label': 'POZICE', 'desc': 'Číslo pozice v sestavě'},
    {'key': 'name', 'label': 'NÁZEV DÍLU', 'desc': 'Hlavní identifikátor dílu'},
    {'key': 'qty', 'label': 'MNOŽSTVÍ', 'desc': 'Počet kusů (ks, qty)'},
    {'key': 'material', 'label': 'MATERIÁL', 'desc': 'Kvalita materiálu (S235, 1.4301...)'},
    {'key': 'thickness', 'label': 'TLOUŠŤKA', 'desc': 'Tloušťka plechu v mm'},
    {'key': 'dims', 'label': 'ROZMĚRY', 'desc': 'Formát (1000x2000, atd.)'},
  ];

  // ── Mock data ──────────────────────────────────────────────────────────
  final List<_MockCustomer> _customers = [
    _MockCustomer(
      id: '1',
      displayName: 'Stavebniny Liberec s.r.o.',
      ico: '27345678',
      aliases: ['STAV Liberec', 'Stavebniny LBC'],
      keywords: ['liberec', 'stavba-projekt'],
      notes: 'Hlavní odběratel – kontakt: Jan Novák',
      mappings: {
        'pos': 'Pozice, Pol.',
        'name': 'Název, Popis',
        'qty': 'Ks, Množství',
        'material': 'Materiál',
        'thickness': 'Tl., Tloušťka',
        'dims': 'Rozměr, Formát',
      },
    ),
    _MockCustomer(
      id: '2',
      displayName: 'KOVO Praha a.s.',
      ico: '45123456',
      aliases: ['Kovo-Praha'],
      keywords: ['kovo', 'praha-ocel'],
      mappings: {
        'pos': 'Item',
        'name': 'Description',
        'qty': 'Qty',
        'material': 'Grade',
        'thickness': 'Thk',
        'dims': 'Size',
      },
    ),
    _MockCustomer(
      id: '3',
      displayName: 'Zámečnictví Horák',
      ico: '',
      aliases: ['Horák'],
      keywords: ['horak', 'zamecnictvi'],
      notes: 'Menší zakázky, platba předem',
    ),
  ];

  // ── Controllery ────────────────────────────────────────────────────────
  String? _selectedCustomerId;
  late TextEditingController _displayNameController;
  late TextEditingController _icoController;
  late TextEditingController _aliasesController;
  late TextEditingController _keywordsController;
  late TextEditingController _notesController;
  final Map<String, TextEditingController> _mappingControllers = {};

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _icoController = TextEditingController();
    _aliasesController = TextEditingController();
    _keywordsController = TextEditingController();
    _notesController = TextEditingController();

    for (var field in _systemFields) {
      _mappingControllers[field['key']!] = TextEditingController();
    }

    if (_customers.isNotEmpty) {
      _selectCustomer(_customers.first.id);
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _icoController.dispose();
    _aliasesController.dispose();
    _keywordsController.dispose();
    _notesController.dispose();
    for (var c in _mappingControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Logika (in-memory) ─────────────────────────────────────────────────

  void _loadToControllers(_MockCustomer c) {
    _displayNameController.text = c.displayName;
    _icoController.text = c.ico;
    _aliasesController.text = c.aliases.join(', ');
    _keywordsController.text = c.keywords.join(', ');
    _notesController.text = c.notes;
    for (var field in _systemFields) {
      final key = field['key']!;
      _mappingControllers[key]!.text = c.mappings[key] ?? '';
    }
  }

  void _selectCustomer(String id) {
    setState(() {
      _selectedCustomerId = id;
      _loadToControllers(_customers.firstWhere((c) => c.id == id));
    });
  }

  void _saveCurrentCustomer() {
    final c = _customers.firstWhere((c) => c.id == _selectedCustomerId);
    setState(() {
      c.displayName = _displayNameController.text.trim();
      c.ico = _icoController.text.trim();
      c.aliases = _aliasesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      c.keywords = _keywordsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      c.notes = _notesController.text.trim();
      c.mappings = Map.fromEntries(
        _mappingControllers.entries.map((e) => MapEntry(e.key, e.value.text)),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("ZÁKAZNÍK ULOŽEN"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _createNewCustomer() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _customers.add(_MockCustomer(id: newId, displayName: "Nový zákazník"));
      _selectCustomer(newId);
    });
  }

  void _deleteCurrentCustomer() {
    if (_customers.length <= 1) return;
    setState(() {
      _customers.removeWhere((c) => c.id == _selectedCustomerId);
      _selectCustomer(_customers.first.id);
    });
  }

  // =====================================================================
  //  BUILD
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    if (_customers.isEmpty) return _buildEmptyState();

    if (!_customers.any((c) => c.id == _selectedCustomerId)) {
      _selectedCustomerId = _customers.first.id;
    }

    final active = _customers.firstWhere((c) => c.id == _selectedCustomerId);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 1, child: _buildCustomersPanel()),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            color: _glassBorder,
          ),
          Expanded(flex: 2, child: _buildEditorPanel(active)),
        ],
      ),
    );
  }

  // =====================================================================
  //  LEVÝ PANEL
  // =====================================================================

  Widget _buildCustomersPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _sectionHeader("ZÁKAZNÍCI"),
              const Spacer(),
              InkWell(
                onTap: _createNewCustomer,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 14, color: _accentColor.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        "NOVÝ",
                        style: TextStyle(
                          color: _accentColor.withOpacity(0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Container(
              decoration: BoxDecoration(
                color: _bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _customers.length,
                  itemBuilder: (context, i) => _buildCustomerRow(
                      _customers[i], i == _customers.length - 1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerRow(_MockCustomer customer, bool isLast) {
    final isSelected = customer.id == _selectedCustomerId;

    return InkWell(
      onTap: () => _selectCustomer(customer.id),
      hoverColor: Colors.white.withOpacity(0.02),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor.withOpacity(0.06)
              : Colors.transparent,
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: _borderColor)),
        ),
        child: Row(
          children: [
            // Radio – shodný styl s ProfilesEditorTab
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _accentColor : Colors.white24,
                  width: 2,
                ),
                color: isSelected ? _accentColor : Colors.transparent,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        customer.ico.isNotEmpty
                            ? "IČ: ${customer.ico}  ·  ${customer.patternCount} vzorů"
                            : "${customer.patternCount} vzorů",
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Smazat – shodný styl s ProfilesEditorTab
            IconButton(
              onPressed: () {
                _selectCustomer(customer.id);
                _deleteCurrentCustomer();
              },
              icon: const Icon(Icons.close_rounded, size: 12),
              color: Colors.white12,
              hoverColor: Colors.redAccent.withOpacity(0.1),
              tooltip: "Smazat zákazníka",
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  //  PRAVÝ PANEL
  // =====================================================================

  Widget _buildEditorPanel(_MockCustomer customer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _sectionHeader("PROFIL ZÁKAZNÍKA"),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── TABULKA 1: ROZPOZNÁVACÍ VZORY ─────────────────────
                _tableLabel(Icons.manage_search_rounded, "ROZPOZNÁVACÍ VZORY"),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildFieldRow(
                        icon: Icons.badge_outlined,
                        label: "IČO",
                        desc: "Identifikační číslo firmy",
                        controller: _icoController,
                        hintText: "např. 12345678",
                      ),
                      _buildFieldRow(
                        icon: Icons.text_fields_rounded,
                        label: "ALIASY",
                        desc: "Alternativní názvy, oddělené čárkou",
                        controller: _aliasesController,
                        hintText: "např. Stavebniny s.r.o., STAV Liberec",
                      ),
                      _buildFieldRow(
                        icon: Icons.search_rounded,
                        label: "KLÍČOVÁ SLOVA",
                        desc: "Hledaná v importovaném souboru",
                        controller: _keywordsController,
                        hintText: "např. liberec, stavba-projekt, OBJ-2024",
                      ),
                      _buildFieldRow(
                        icon: Icons.notes_rounded,
                        label: "POZNÁMKY",
                        desc: "Interní poznámka",
                        controller: _notesController,
                        hintText: "např. Hlavní odběratel, kontakt: Jan Novák",
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  "* Systém porovnává IČO, aliasy a klíčová slova s obsahem importovaného souboru.",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.15), fontSize: 11),
                ),

                const SizedBox(height: 28),

                // ─── TABULKA 2: MAPOVÁNÍ SLOUPCŮ ───────────────────────
                _tableLabel(Icons.tune_rounded, "MAPOVÁNÍ SLOUPCŮ"),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    children: _systemFields.asMap().entries.map((entry) {
                      final isLast = entry.key == _systemFields.length - 1;
                      return _buildMappingRow(entry.value, isLast);
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  "* Názvy sloupců v Excelu oddělené čárkou. Systém hledá shodu v tomto pořadí.",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.15), fontSize: 11),
                ),

                const SizedBox(height: 24),

                // ─── FOOTER: Název + uložit ────────────────────────────
                _buildEditorFooter(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================================
  //  ŘÁDKY TABULEK
  // =====================================================================

  /// Řádek pro rozpoznávací vzory (s ikonou vlevo)
  Widget _buildFieldRow({
    required IconData icon,
    required String label,
    required String desc,
    required TextEditingController controller,
    required String hintText,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon,
                        size: 13, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 21),
                  child: Text(
                    desc,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.arrow_right_alt_rounded,
              size: 16, color: Colors.white.withOpacity(0.08)),
          const SizedBox(width: 12),
          Expanded(child: _inputField(controller, hintText)),
        ],
      ),
    );
  }

  /// Řádek pro mapování sloupců (stejný styl jako ProfilesEditorTab)
  Widget _buildMappingRow(Map<String, String> field, bool isLast) {
    final key = field['key']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field['label']!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  field['desc']!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.arrow_right_alt_rounded,
              size: 16, color: Colors.white.withOpacity(0.08)),
          const SizedBox(width: 12),
          Expanded(
            child: _inputField(
              _mappingControllers[key]!,
              "např. $key, column_a...",
            ),
          ),
        ],
      ),
    );
  }

  /// Sdílený styl vstupního pole
  Widget _inputField(TextEditingController controller, String hintText) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.amberAccent,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.08),
            fontStyle: FontStyle.italic,
            fontSize: 11,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // =====================================================================
  //  FOOTER
  // =====================================================================

  Widget _buildEditorFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded,
                    size: 16, color: Colors.white.withOpacity(0.15)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _displayNameController,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: "Název zákazníka",
                      hintStyle:
                          TextStyle(color: Colors.white24, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Material(
            color: _accentColor,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: _saveCurrentCustomer,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Text(
                  "ULOŽIT ZMĚNY",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  //  HELPERS
  // =====================================================================

  Widget _tableLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.white.withOpacity(0.12)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.2),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.2),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined,
              size: 48, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            "Žádní zákazníci",
            style:
                TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            "Zákazníci se vytvoří automaticky analýzou souborů v Drop Zone,\nnebo je můžete přidat ručně.",
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _createNewCustomer,
            child: const Text(
              "PŘIDAT RUČNĚ",
              style: TextStyle(
                  color: _accentColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}