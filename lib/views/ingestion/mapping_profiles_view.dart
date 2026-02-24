import 'package:flutter/material.dart';
import 'package:mrb_obchodnik/logic/notifications.dart';
import 'package:mrb_obchodnik/views/settings/settings_helpers.dart';

/// Model pro jeden mapovací profil
class MappingProfile {
  String id;
  String name;
  bool isDefault;
  Map<String, String> mappings; // Key: SystemField, Value: ExcelHeaderKeywords

  MappingProfile({
    required this.id,
    required this.name,
    this.isDefault = false,
    required this.mappings,
  });
}

class MappingProfilesView extends StatefulWidget {
  const MappingProfilesView({super.key});

  @override
  State<MappingProfilesView> createState() => _MappingProfilesViewState();
}

class _MappingProfilesViewState extends State<MappingProfilesView> {
  // --- KONSTANTY DESIGNU ---
  static const Color _bgSidebar = Color(0xFF121418);
  static const Color _bgEditor = Color(0xFF0F1115);
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _borderColor = Color(0xFF2A2D35);

  // --- SYSTÉMOVÁ POLE (Cílová data) ---
  final List<Map<String, String>> _systemFields = [
    {'key': 'pos', 'label': 'POZICE', 'desc': 'Číslo pozice v sestavě'},
    {'key': 'name', 'label': 'NÁZEV DÍLU', 'desc': 'Hlavní identifikátor dílu'},
    {'key': 'qty', 'label': 'MNOŽSTVÍ', 'desc': 'Počet kusů (ks, qty)'},
    {'key': 'material', 'label': 'MATERIÁL', 'desc': 'Kvalita materiálu (S235, 1.4301...)'},
    {'key': 'thickness', 'label': 'TLOUŠŤKA', 'desc': 'Tloušťka plechu v mm'},
    {'key': 'dims', 'label': 'ROZMĚRY', 'desc': 'Formát (1000x2000, atd.)'},
  ];

  // --- STAV ---
  // Mock data - v reálu by se načítala z DB/SharedPreferences
  final List<MappingProfile> _profiles = [
    MappingProfile(
      id: '1',
      name: 'Standardní Import (Default)',
      isDefault: true,
      mappings: {
        'pos': 'poz, pozice, č.',
        'name': 'název, popis, description',
        'qty': 'ks, počet, mn., qty',
        'material': 'materiál, mat, jakost',
        'thickness': 'tl, tl., tloušťka',
      },
    ),
    MappingProfile(
      id: '2',
      name: 'Export SAP (Německo)',
      isDefault: false,
      mappings: {
        'pos': 'pos, position',
        'name': 'benennung, name',
        'qty': 'menge, anzahl',
        'material': 'werkstoff',
        'thickness': 'dicke',
      },
    ),
  ];

  String? _selectedProfileId;
  late TextEditingController _nameController;
  final Map<String, TextEditingController> _mappingControllers = {};

  @override
  void initState() {
    super.initState();
    _selectedProfileId = _profiles.first.id;
    _nameController = TextEditingController();
    _loadProfileToControllers(_profiles.first);
  }

  void _loadProfileToControllers(MappingProfile profile) {
    _nameController.text = profile.name;
    
    // Vyčistit a naplnit controllery pro mapování
    for (var field in _systemFields) {
      final key = field['key']!;
      final val = profile.mappings[key] ?? "";
      
      if (!_mappingControllers.containsKey(key)) {
        _mappingControllers[key] = TextEditingController();
      }
      _mappingControllers[key]!.text = val;
    }
  }

  void _selectProfile(String id) {
    setState(() {
      _selectedProfileId = id;
      final profile = _profiles.firstWhere((p) => p.id == id);
      _loadProfileToControllers(profile);
    });
  }

  void _saveCurrentProfile() {
    final profileIndex = _profiles.indexWhere((p) => p.id == _selectedProfileId);
    if (profileIndex != -1) {
      setState(() {
        _profiles[profileIndex].name = _nameController.text;
        for (var entry in _mappingControllers.entries) {
          _profiles[profileIndex].mappings[entry.key] = entry.value.text;
        }
      });
      Notifications.showSuccess(context, "PROFIL ULOŽEN");
    }
  }

  void _createNewProfile() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newProfile = MappingProfile(
      id: newId,
      name: "Nový Profil",
      mappings: {},
    );
    setState(() {
      _profiles.add(newProfile);
      _selectProfile(newId);
    });
  }

  void _deleteCurrentProfile() {
    if (_profiles.length <= 1) {
      Notifications.showError(context, "NEMOHU SMAZAT POSLEDNÍ PROFIL");
      return;
    }
    setState(() {
      _profiles.removeWhere((p) => p.id == _selectedProfileId);
      _selectProfile(_profiles.first.id);
    });
    Notifications.showWarning(context, "PROFIL ODSTRANĚN");
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = _profiles.firstWhere((p) => p.id == _selectedProfileId);

    return Scaffold(
      backgroundColor: _bgEditor,
      body: Row(
        children: [
          // --- LEVÝ PANEL (SEZNAM) ---
          Container(
            width: 280,
            color: _bgSidebar,
            child: Column(
              children: [
                _buildSidebarHeader(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _profiles.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      final p = _profiles[index];
                      final isSelected = p.id == _selectedProfileId;
                      return _buildProfileTile(p, isSelected);
                    },
                  ),
                ),
                _buildAddButton(),
              ],
            ),
          ),

          // --- PRAVÝ PANEL (EDITOR) ---
          Expanded(
            child: Column(
              children: [
                _buildEditorHeader(activeProfile),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SettingsHelpers.headerText("DEFINICE MAPOVÁNÍ SLOUPCŮ"),
                        const SizedBox(height: 10),
                        SettingsHelpers.buildGlassPanel(
                          child: Column(
                            children: _systemFields.map((field) {
                              final isLast = field == _systemFields.last;
                              return _buildMappingRow(field, isLast);
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "* Zadejte názvy sloupců v Excelu oddělené čárkou. Systém bude hledat shodu v tomto pořadí.",
                          style: TextStyle(color: Colors.white24, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETY: SIDEBAR ---

  Widget _buildSidebarHeader() {
    return Container(
      height: 60,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: const Text(
        "PROFILY",
        style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildProfileTile(MappingProfile p, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? _accentColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? _accentColor.withOpacity(0.5) : Colors.transparent,
        ),
      ),
      child: ListTile(
        onTap: () => _selectProfile(p.id),
        dense: true,
        title: Text(
          p.name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        trailing: p.isDefault 
            ? const Icon(Icons.star_rounded, size: 14, color: Colors.amber) 
            : null,
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _createNewProfile,
          icon: const Icon(Icons.add, size: 16),
          label: const Text("NOVÝ PROFIL"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white12),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  // --- WIDGETY: EDITOR ---

  Widget _buildEditorHeader(MappingProfile profile) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: _bgSidebar,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Název profilu",
                hintStyle: TextStyle(color: Colors.white24),
              ),
            ),
          ),
          IconButton(
            onPressed: _saveCurrentProfile,
            icon: const Icon(Icons.save_rounded, color: _accentColor),
            tooltip: "Uložit změny",
          ),
          if (!profile.isDefault)
            IconButton(
              onPressed: _deleteCurrentProfile,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: "Smazat profil",
            ),
        ],
      ),
    );
  }

  Widget _buildMappingRow(Map<String, String> field, bool isLast) {
    final key = field['key']!;
    return SettingsHelpers.buildDataRow(
      field['label']!, // Label (vlevo)
      "", // Value (nepoužíváme standardní text, ale input)
      isLast: isLast,
    ).copyWith(
      // Hack: Přepíšeme child buildDataRow, abychom vložili TextField
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  field['label']!,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  field['desc']!,
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          const Icon(Icons.arrow_right_alt_rounded, color: Colors.white12),
          const SizedBox(width: 20),
          Expanded(
            child: TextField(
              controller: _mappingControllers[key],
              style: const TextStyle(color: Colors.amberAccent, fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                hintText: "např. ${field['key']}, column_a...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.1), fontStyle: FontStyle.italic),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.black12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension pro úpravu child v buildDataRow (pokud by SettingsHelpers vracel Container)
// V tomto případě jsem raději zkopíroval logiku layoutu přímo do _buildMappingRow, 
// protože SettingsHelpers.buildDataRow je příliš specifický pro read-only text.
extension WidgetModifier on Widget {
  Widget copyWith({required Widget child}) {
    if (this is Container) {
      final c = this as Container;
      return Container(
        padding: c.padding,
        decoration: c.decoration,
        child: child,
      );
    }
    return child;
  }
}