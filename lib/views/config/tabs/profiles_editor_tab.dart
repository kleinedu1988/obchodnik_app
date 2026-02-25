import 'package:flutter/material.dart';
import 'package:mrb_obchodnik/logic/notifications.dart';
import 'package:mrb_obchodnik/logic/workflow_controller.dart';

class ProfilesEditorTab extends StatefulWidget {
  const ProfilesEditorTab({super.key});

  @override
  State<ProfilesEditorTab> createState() => _ProfilesEditorTabState();
}

class _ProfilesEditorTabState extends State<ProfilesEditorTab> {
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _glassBorder = Color(0x14FFFFFF);
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _borderColor = Color(0xFF2A2D35);

  final List<Map<String, String>> _systemFields = [
    {'key': 'pos', 'label': 'POZICE', 'desc': 'Číslo pozice v sestavě'},
    {'key': 'name', 'label': 'NÁZEV DÍLU', 'desc': 'Hlavní identifikátor dílu'},
    {'key': 'qty', 'label': 'MNOŽSTVÍ', 'desc': 'Počet kusů (ks, qty)'},
    {'key': 'material', 'label': 'MATERIÁL', 'desc': 'Kvalita materiálu (S235, 1.4301...)'},
    {'key': 'thickness', 'label': 'TLOUŠŤKA', 'desc': 'Tloušťka plechu v mm'},
    {'key': 'dims', 'label': 'ROZMĚRY', 'desc': 'Formát (1000x2000, atd.)'},
  ];

  String? _selectedProfileId;
  late TextEditingController _nameController;
  final Map<String, TextEditingController> _mappingControllers = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    final profiles = WorkflowController().profiles;
    if (profiles.isNotEmpty) {
      _selectProfile(
        profiles.firstWhere((p) => p.isDefault, orElse: () => profiles.first).id,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var c in _mappingControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // --- LOGIKA ---

  void _loadProfileToControllers(MappingProfile profile) {
    _nameController.text = profile.name;
    for (var field in _systemFields) {
      final key = field['key']!;
      final val = profile.mappings[key] ?? '';
      if (!_mappingControllers.containsKey(key)) {
        _mappingControllers[key] = TextEditingController();
      }
      _mappingControllers[key]!.text = val;
    }
  }

  void _selectProfile(String id) {
    setState(() {
      _selectedProfileId = id;
      final profile = WorkflowController().profiles.firstWhere((p) => p.id == id);
      _loadProfileToControllers(profile);
    });
  }

  void _saveCurrentProfile() {
    final profiles = WorkflowController().profiles;
    final originalProfile = profiles.firstWhere((p) => p.id == _selectedProfileId);
    final updatedProfile = MappingProfile(
      id: originalProfile.id,
      name: _nameController.text,
      isDefault: originalProfile.isDefault,
      mappings: Map.fromEntries(
        _mappingControllers.entries.map((e) => MapEntry(e.key, e.value.text)),
      ),
    );
    WorkflowController().saveProfile(updatedProfile);
    setState(() {});
    Notifications.showSuccess(context, "PROFIL ULOŽEN");
  }

  void _createNewProfile() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newProfile = MappingProfile(
      id: newId,
      name: "Nový Profil",
      mappings: {},
    );
    setState(() {
      WorkflowController().addProfile(newProfile);
      _selectProfile(newId);
    });
  }

  void _deleteCurrentProfile() {
    final profiles = WorkflowController().profiles;
    if (profiles.length <= 1) {
      Notifications.showError(context, "NEMOHU SMAZAT POSLEDNÍ PROFIL");
      return;
    }
    setState(() {
      WorkflowController().deleteProfile(_selectedProfileId!);
      _selectProfile(WorkflowController().profiles.first.id);
    });
    Notifications.showWarning(context, "PROFIL ODSTRANĚN");
  }

  void _setAsDefault(MappingProfile profile) {
    profile.isDefault = true;
    WorkflowController().saveProfile(profile);
    setState(() {});
    Notifications.showSuccess(context, "NASTAVENO JAKO VÝCHOZÍ");
  }

  // =========================================================================
  //  BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final profiles = WorkflowController().profiles;

    if (profiles.isEmpty) return _buildEmptyState();
    if (!profiles.any((p) => p.id == _selectedProfileId)) {
      _selectedProfileId = profiles.first.id;
    }

    final activeProfile = profiles.firstWhere((p) => p.id == _selectedProfileId);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEVÝ SLOUPEC (1/3)
          Expanded(
            flex: 1,
            child: _buildProfilesPanel(profiles),
          ),

          // ODDĚLOVACÍ ČÁRA
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            color: _glassBorder,
          ),

          // PRAVÝ SLOUPEC (2/3)
          Expanded(
            flex: 2,
            child: _buildEditorPanel(activeProfile),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  //  LEVÝ PANEL: PROFILY
  // =========================================================================

  Widget _buildProfilesPanel(List<MappingProfile> profiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hlavička
        SizedBox(
          height: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _sectionHeader("DOSTUPNÉ PROFILY"),
              const Spacer(),
              InkWell(
                onTap: _createNewProfile,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: _accentColor.withOpacity(0.7)),
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

        // Seznam
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
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final isLast = index == profiles.length - 1;
                    return _buildProfileRow(profiles[index], isLast);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileRow(MappingProfile profile, bool isLast) {
    final isSelected = profile.id == _selectedProfileId;
    final keywordCount = profile.allKeywords.length;

    return InkWell(
      onTap: () => _selectProfile(profile.id),
      hoverColor: Colors.white.withOpacity(0.02),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _accentColor.withOpacity(0.06) : Colors.transparent,
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: _borderColor)),
        ),
        child: Row(
          children: [
            // Radio
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

            // Název + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        "$keywordCount slov",
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (profile.isDefault) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded, size: 10, color: Colors.amber),
                        const SizedBox(width: 3),
                        const Text(
                          "VÝCHOZÍ",
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Smazat
            if (!profile.isDefault)
              IconButton(
                onPressed: () {
                  _selectProfile(profile.id);
                  _deleteCurrentProfile();
                },
                icon: const Icon(Icons.close_rounded, size: 12),
                color: Colors.white12,
                hoverColor: Colors.redAccent.withOpacity(0.1),
                tooltip: "Smazat profil",
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  //  PRAVÝ PANEL: EDITOR
  // =========================================================================

  Widget _buildEditorPanel(MappingProfile activeProfile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hlavička – stejná výška jako levý panel
        SizedBox(
          height: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _sectionHeader("DEFINICE MAPOVÁNÍ SLOUPCŮ"),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tabulka mapování
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                const SizedBox(height: 12),
                Text(
                  "* Zadejte názvy sloupců v Excelu oddělené čárkou. Systém bude hledat shodu v tomto pořadí.",
                  style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 11),
                ),

                const SizedBox(height: 24),

                // FOOTER: Název profilu + akce (POD tabulkou)
                _buildEditorFooter(activeProfile),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorFooter(MappingProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          // Název profilu (editovatelný)
          Expanded(
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded, size: 16, color: Colors.white.withOpacity(0.15)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: "Název profilu",
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Nastavit jako výchozí
          if (!profile.isDefault)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () => _setAsDefault(profile),
                icon: const Icon(Icons.star_outline_rounded, color: Colors.amber, size: 18),
                tooltip: "Nastavit jako výchozí",
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),

          // Uložit
          Material(
            color: _accentColor,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: _saveCurrentProfile,
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
          Icon(
            Icons.arrow_right_alt_rounded,
            size: 16,
            color: Colors.white.withOpacity(0.08),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: TextField(
                controller: _mappingControllers[key],
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  hintText: "např. ${field['key']}, column_a...",
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.08),
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  //  HELPERS
  // =========================================================================

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
          Icon(Icons.tune_rounded, size: 48, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            "Žádné mapovací profily",
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _createNewProfile,
            child: const Text(
              "VYTVOŘIT PRVNÍ",
              style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}