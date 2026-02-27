import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mrb_obchodnik/logic/customer_profile.dart';
import 'package:mrb_obchodnik/logic/db_service.dart';

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

  final DbService _dbService = DbService();

  final List<Map<String, String>> _systemFields = const [
    {'key': 'pos', 'label': 'POZICE', 'desc': 'Číslo pozice v sestavě'},
    {'key': 'name', 'label': 'NÁZEV DÍLU', 'desc': 'Hlavní identifikátor dílu'},
    {'key': 'qty', 'label': 'MNOŽSTVÍ', 'desc': 'Počet kusů (ks, qty)'},
    {'key': 'material', 'label': 'MATERIÁL', 'desc': 'Kvalita materiálu (S235, 1.4301...)'},
    {'key': 'thickness', 'label': 'TLOUŠŤKA', 'desc': 'Tloušťka plechu v mm'},
    {'key': 'dims', 'label': 'ROZMĚRY', 'desc': 'Formát (1000x2000, atd.)'},
  ];

  final List<CustomerProfile> _profiles = [];
  final Map<int, Map<String, dynamic>> _customerCache = {};
  final List<Map<String, dynamic>> _customerSearchResults = [];

  int? _selectedProfileId;
  int? _linkedCustomerId;
  Map<String, dynamic>? _selectedCustomer;
  bool _isLoading = false;
  bool _isCustomerSearchLoading = false;
  bool _hasMoreCustomerResults = false;

  static const int _customerSearchPageSize = 20;
  int _customerSearchOffset = 0;
  String _customerSearchQuery = '';
  Timer? _customerSearchDebounce;

  late TextEditingController _displayNameController;
  late TextEditingController _icoController;
  late TextEditingController _aliasesController;
  late TextEditingController _keywordsController;
  late TextEditingController _notesController;
  late TextEditingController _customerSearchController; // Pro filtraci navázaného zákazníka
  
  final Map<String, TextEditingController> _mappingControllers = {};

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _icoController = TextEditingController();
    _aliasesController = TextEditingController();
    _keywordsController = TextEditingController();
    _notesController = TextEditingController();
    _customerSearchController = TextEditingController();

    for (final field in _systemFields) {
      _mappingControllers[field['key']!] = TextEditingController();
    }

    _loadData();
  }

  @override
  void dispose() {
    _customerSearchDebounce?.cancel();
    _displayNameController.dispose();
    _icoController.dispose();
    _aliasesController.dispose();
    _keywordsController.dispose();
    _notesController.dispose();
    _customerSearchController.dispose();
    for (final c in _mappingControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Načtení dat s ochranou proti zamrznutí UI
  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final profiles = await _dbService.getCustomerProfiles();

      if (!mounted) return;
      setState(() {
        _profiles.clear();
        _profiles.addAll(profiles);
        if (_profiles.isNotEmpty) {
          _selectedProfileId = _profiles.first.id;
        }
        _isLoading = false;
      });

      if (_profiles.isNotEmpty) {
        await _loadToControllers(_profiles.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMsg('CHYBA NAČTENÍ: $e', isError: true);
    }
  }

  Future<void> _loadToControllers(CustomerProfile profile) async {
    _displayNameController.text = profile.displayName;
    _icoController.text = profile.ico;
    _aliasesController.text = profile.aliases.join(', ');
    _keywordsController.text = profile.keywords.join(', ');
    _notesController.text = profile.notes;
    _linkedCustomerId = profile.customerId;

    // Reset vyhledávání při změně profilu.
    _customerSearchController.clear();
    _customerSearchQuery = '';
    _customerSearchOffset = 0;
    _customerSearchResults.clear();
    _hasMoreCustomerResults = false;
    _isCustomerSearchLoading = false;

    await _loadSelectedCustomer(profile.customerId);

    for (final field in _systemFields) {
      final key = field['key']!;
      _mappingControllers[key]!.text = profile.mappings[key] ?? '';
    }
  }

  Future<void> _loadSelectedCustomer(int? customerId) async {
    if (customerId == null) {
      if (!mounted) return;
      setState(() => _selectedCustomer = null);
      return;
    }

    final cached = _customerCache[customerId];
    if (cached != null) {
      if (!mounted) return;
      setState(() => _selectedCustomer = cached);
      return;
    }

    final customer = await _dbService.getZakaznikById(customerId);
    if (customer == null || !mounted) return;

    setState(() {
      _customerCache[customerId] = customer;
      _selectedCustomer = customer;
    });
  }

  void _onCustomerSearchChanged(String query) {
    _customerSearchDebounce?.cancel();
    _customerSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchCustomers(query, reset: true);
    });
  }

  Future<void> _searchCustomers(String query, {required bool reset}) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      if (!mounted) return;
      setState(() {
        _customerSearchQuery = '';
        _customerSearchOffset = 0;
        _customerSearchResults.clear();
        _hasMoreCustomerResults = false;
        _isCustomerSearchLoading = false;
      });
      return;
    }

    final nextOffset = reset ? 0 : _customerSearchOffset;

    setState(() {
      _customerSearchQuery = normalizedQuery;
      _isCustomerSearchLoading = true;
      if (reset) {
        _customerSearchResults.clear();
        _hasMoreCustomerResults = false;
      }
    });

    final results = await _dbService.getZakaznici(
      query: normalizedQuery,
      limit: _customerSearchPageSize,
      offset: nextOffset,
    );

    if (!mounted || _customerSearchQuery != normalizedQuery) return;

    setState(() {
      if (reset) {
        _customerSearchResults
          ..clear()
          ..addAll(results);
      } else {
        _customerSearchResults.addAll(results);
      }
      for (final customer in results) {
        final id = customer['id'];
        if (id is int) {
          _customerCache[id] = customer;
        }
      }
      _customerSearchOffset = nextOffset + results.length;
      _hasMoreCustomerResults = results.length == _customerSearchPageSize;
      _isCustomerSearchLoading = false;
    });
  }

  void _selectProfile(int id) {
    final profile = _profiles.firstWhere((p) => p.id == id);
    setState(() {
      _selectedProfileId = id;
    });
    _loadToControllers(profile);
  }

  List<String> _splitCommaValues(String value) {
    return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  Future<void> _saveCurrentCustomer() async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      _showMsg('Název profilu je povinný.', isError: true);
      return;
    }
    if (_linkedCustomerId == null) {
      _showMsg('Navázaný zákazník je povinný.', isError: true);
      return;
    }

    final selected = _findSelectedProfile();

    final profile = CustomerProfile(
      id: selected?.id,
      customerId: _linkedCustomerId!,
      profileUid: selected?.profileUid ?? 'cp_${DateTime.now().millisecondsSinceEpoch}',
      displayName: displayName,
      ico: _icoController.text.trim(),
      aliases: _splitCommaValues(_aliasesController.text),
      keywords: _splitCommaValues(_keywordsController.text),
      notes: _notesController.text.trim(),
      mappings: Map.fromEntries(
        _mappingControllers.entries
            .map((e) => MapEntry(e.key, e.value.text.trim()))
            .where((e) => e.value.isNotEmpty),
      ),
    );

    try {
      final saved = await _dbService.saveCustomerProfile(profile);
      await _dbService.updateCustomerProfileUid(_linkedCustomerId!, saved.profileUid);

      final idx = _profiles.indexWhere((p) => p.id == saved.id);
      setState(() {
        if (idx == -1) {
          _profiles.add(saved);
        } else {
          _profiles[idx] = saved;
        }
        _profiles.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        _selectedProfileId = saved.id;
      });
      
      if (!mounted) return;
      _showMsg('PROFIL ULOŽEN');
    } catch (e) {
      if (!mounted) return;
      _showMsg('CHYBA ULOŽENÍ: $e', isError: true);
    }
  }

  void _createNewCustomer() {
    setState(() {
      _selectedProfileId = null;
      _linkedCustomerId = null;
      _displayNameController.clear();
      _icoController.clear();
      _aliasesController.clear();
      _keywordsController.clear();
      _notesController.clear();
      _customerSearchController.clear();
      _selectedCustomer = null;
      _customerSearchQuery = '';
      _customerSearchOffset = 0;
      _hasMoreCustomerResults = false;
      _customerSearchResults.clear();
      for (final c in _mappingControllers.values) {
        c.clear();
      }
    });
  }

  Future<void> _deleteCurrentCustomer() async {
    if (_selectedProfileId == null) return;
    
    final active = _findSelectedProfile();
    if (active == null) return;

    try {
      await _dbService.deleteCustomerProfile(active.profileUid);
      await _dbService.updateCustomerProfileUid(active.customerId, null);

      final hadMoreProfiles = _profiles.length > 1;
      setState(() {
        _profiles.removeWhere((p) => p.id == _selectedProfileId);
        if (_profiles.isEmpty) {
          _selectedProfileId = null;
        } else {
          _selectedProfileId = _profiles.first.id;
        }
      });

      if (hadMoreProfiles) {
        await _loadToControllers(_profiles.first);
      } else {
        _createNewCustomer();
      }

      _showMsg('PROFIL SMAZÁN');
    } catch (e) {
      if (!mounted) return;
      _showMsg('CHYBA MAZÁNÍ: $e', isError: true);
    }
  }

  String _customerNameById(int? id) {
    if (id == null) return 'Bez navázaného zákazníka';
    final customer = _customerCache[id];
    if (customer != null) {
      return customer['nazev']?.toString() ?? 'Neznámý zákazník';
    }
    if (_selectedCustomer?['id'] == id) {
      return _selectedCustomer?['nazev']?.toString() ?? 'Neznámý zákazník';
    }
    return 'Zákazník #$id';
  }

  CustomerProfile? _findSelectedProfile() {
    for (final profile in _profiles) {
      if (profile.id == _selectedProfileId) return profile;
    }
    return null;
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : null,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor));
    }

    if (_profiles.isEmpty && _selectedProfileId == null) return _buildEmptyState();

    final active = _findSelectedProfile();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 1, child: _buildProfilesPanel()),
          Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 24), color: _glassBorder),
          Expanded(flex: 2, child: _buildEditorPanel(active)),
        ],
      ),
    );
  }

  Widget _buildProfilesPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _sectionHeader('PROFILY'),
              const Spacer(),
              InkWell(
                onTap: _createNewCustomer,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: _accentColor.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'NOVÝ',
                        style: TextStyle(color: _accentColor.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
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
              decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _profiles.length,
                  itemBuilder: (context, i) => _buildProfileRow(_profiles[i], i == _profiles.length - 1),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileRow(CustomerProfile profile, bool isLast) {
    final isSelected = profile.id == _selectedProfileId;

    return InkWell(
      onTap: () => _selectProfile(profile.id!),
      hoverColor: Colors.white.withOpacity(0.02),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _accentColor.withOpacity(0.06) : Colors.transparent,
          border: isLast ? null : const Border(bottom: BorderSide(color: _borderColor)),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? _accentColor : Colors.white24, width: 2),
                color: isSelected ? _accentColor : Colors.transparent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_customerNameById(profile.customerId)}  ·  ${profile.patternCount} vzorů',
                    style: const TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'monospace'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                _selectedProfileId = profile.id;
                _deleteCurrentCustomer();
              },
              icon: const Icon(Icons.close_rounded, size: 12),
              color: Colors.white12,
              hoverColor: Colors.redAccent.withOpacity(0.1),
              tooltip: 'Smazat profil',
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorPanel(CustomerProfile? active) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 24, child: Row(children: [_sectionHeader('PROFIL ZÁKAZNÍKA')])),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tableLabel(Icons.manage_search_rounded, 'ROZPOZNÁVACÍ VZORY'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
                  child: Column(
                    children: [
                      _buildFieldRow(icon: Icons.badge_outlined, label: 'IČO', desc: 'Identifikační číslo firmy', controller: _icoController, hintText: 'např. 12345678'),
                      _buildFieldRow(icon: Icons.text_fields_rounded, label: 'ALIASY', desc: 'Alternativní názvy, oddělené čárkou', controller: _aliasesController, hintText: 'např. Stavebniny s.r.o., STAV Liberec'),
                      _buildFieldRow(icon: Icons.search_rounded, label: 'KLÍČOVÁ SLOVA', desc: 'Hledaná v importovaném souboru', controller: _keywordsController, hintText: 'např. liberec, stavba-projekt, OBJ-2024'),
                      _buildFieldRow(icon: Icons.notes_rounded, label: 'POZNÁMKY', desc: 'Interní poznámka', controller: _notesController, hintText: 'např. Hlavní odběratel, kontakt: Jan Novák', isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _tableLabel(Icons.tune_rounded, 'MAPOVÁNÍ SLOUPCŮ'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
                  child: Column(
                    children: _systemFields.asMap().entries.map((entry) => _buildMappingRow(entry.value, entry.key == _systemFields.length - 1)).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                _buildEditorFooter(active),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: _borderColor))),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 13, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(width: 8),
                    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 21),
                  child: Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.arrow_right_alt_rounded, size: 16, color: Colors.white.withOpacity(0.08)),
          const SizedBox(width: 12),
          Expanded(child: _inputField(controller, hintText)),
        ],
      ),
    );
  }

  Widget _buildMappingRow(Map<String, String> field, bool isLast) {
    final key = field['key']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: _borderColor))),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field['label']!, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(field['desc']!, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.arrow_right_alt_rounded, size: 16, color: Colors.white.withOpacity(0.08)),
          const SizedBox(width: 12),
          Expanded(child: _inputField(_mappingControllers[key]!, 'např. $key, column_a...')),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hintText) {
    return Container(
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white.withOpacity(0.04))),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.amberAccent, fontFamily: 'monospace', fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.08), fontStyle: FontStyle.italic, fontSize: 11),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildEditorFooter(CustomerProfile? active) {
    final dropdownItems = _customerSearchResults.toList();
    if (_selectedCustomer != null && !dropdownItems.any((c) => c['id'] == _selectedCustomer!['id'])) {
      dropdownItems.insert(0, _selectedCustomer!);
    }
    final hasSelectedInItems = dropdownItems.any((c) => c['id'] == _linkedCustomerId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("PROPOJENÍ SE ZÁKAZNÍKEM", style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.search, size: 16, color: Colors.white.withOpacity(0.15)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _customerSearchController,
                  onChanged: _onCustomerSearchChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: "Začněte psát pro hledání zákazníka...",
                    hintStyle: TextStyle(color: Colors.white10, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: _borderColor, height: 20),
          Row(
            children: [
              Icon(Icons.person_pin_circle_outlined, size: 16, color: Colors.white.withOpacity(0.15)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: hasSelectedInItems ? _linkedCustomerId : null,
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  dropdownColor: _bgCard,
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  hint: const Text('Vyberte zákazníka ze seznamu *', style: TextStyle(color: Colors.white24)),
                  items: dropdownItems
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text(c['nazev']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _linkedCustomerId = value;
                      _selectedCustomer = _customerCache[value] ?? _selectedCustomer;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_isCustomerSearchLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2, color: _accentColor),
          ],
          if (_customerSearchQuery.isNotEmpty && _hasMoreCustomerResults) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isCustomerSearchLoading
                    ? null
                    : () => _searchCustomers(_customerSearchQuery, reset: false),
                icon: const Icon(Icons.expand_more_rounded, size: 14),
                label: const Text('Načíst další výsledky', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 16, color: Colors.white.withOpacity(0.15)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _displayNameController,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Název profilu *',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                  ),
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
                    child: Text('ULOŽIT ZMĚNY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                ),
              ),
            ],
          ),
          if (active != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('UID: ${active.profileUid}', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.white.withOpacity(0.12)),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _sectionHeader(String text) {
    return Text(text, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 48, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text('Žádné profily', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
          const SizedBox(height: 8),
          Text('Vytvořte první zákaznický profil.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 12)),
          const SizedBox(height: 16),
          TextButton(onPressed: _createNewCustomer, child: const Text('PŘIDAT RUČNĚ', style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}