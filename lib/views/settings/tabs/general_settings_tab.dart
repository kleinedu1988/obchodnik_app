import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings_helpers.dart';
import '../../../logic/actions.dart'; // Pro tvůj skleněný SnackBar

class GeneralSettingsTab extends StatefulWidget {
  const GeneralSettingsTab({super.key});

  @override
  State<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<GeneralSettingsTab> {
  // Cesty k souborům
  String _techPath = 'Není nastaveno';
  String _offerPath = 'Není nastaveno';
  
  // Preference
  bool _showNotifications = true;
  bool _autoSync = false;
  bool _compactMode = false;
  bool _autoBackup = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _techPath = prefs.getString('tech_path') ?? 'Není nastaveno';
      _offerPath = prefs.getString('offer_path') ?? 'Není nastaveno';
      _showNotifications = prefs.getBool('show_notifications') ?? true;
      _autoSync = prefs.getBool('auto_sync') ?? false;
      _compactMode = prefs.getBool('compact_mode') ?? false;
      _autoBackup = prefs.getBool('auto_backup') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Přidáno větší horní odsazení, aby linka nebyla nalepená na tabs
      padding: const EdgeInsets.only(top: 40, bottom: 60),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. MINIMAL STATUS BAR (Diagnostika) ---
          _buildTopDashboard(),

          const SizedBox(height: 48),

          // --- 2. ARCHIVNÍ SYSTÉM (Cesty k souborům) ---
          SettingsHelpers.headerText("ARCHIVNÍ SYSTÉM"),
          SettingsHelpers.buildGlassPanel(
            child: Column(
              children: [
                _buildPathRow(
                  icon: Icons.factory_rounded,
                  color: const Color(0xFF4077D1),
                  title: "Výroba / Technická dokumentace",
                  path: _techPath,
                  onTap: () => _pickDirectory('tech_path', (val) => _techPath = val),
                ),
                _buildPathRow(
                  icon: Icons.description_rounded,
                  color: Colors.purpleAccent,
                  title: "Složka pro obchodní nabídky",
                  path: _offerPath,
                  onTap: () => _pickDirectory('offer_path', (val) => _offerPath = val),
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // --- 3. AUTOMATIZACE ---
          SettingsHelpers.headerText("AUTOMATIZACE"),
          SettingsHelpers.buildGlassPanel(
            child: Column(
              children: [
                _buildToggleRow(
                  icon: Icons.sync_rounded,
                  color: Colors.greenAccent,
                  title: "Sledování změn na pozadí",
                  subtitle: "Automaticky detekuje úpravy v připojených Excel souborech",
                  value: _autoSync,
                  onChanged: (v) => _saveBool('auto_sync', v, (val) => _autoSync = val),
                ),
                _buildToggleRow(
                  icon: Icons.cloud_done_rounded,
                  color: Colors.blueAccent,
                  title: "Automatické zálohování",
                  subtitle: "Vytvořit kopii databáze při každém úspěšném importu",
                  value: _autoBackup,
                  onChanged: (v) => _saveBool('auto_backup', v, (val) => _autoBackup = val),
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // --- 4. ROZHRANÍ ---
          SettingsHelpers.headerText("ROZHRANÍ"),
          SettingsHelpers.buildGlassPanel(
            child: Column(
              children: [
                _buildToggleRow(
                  icon: Icons.view_compact_rounded,
                  color: Colors.orangeAccent,
                  title: "Kompaktní zobrazení",
                  subtitle: "Zmenší odsazení v seznamech pro zobrazení více dat",
                  value: _compactMode,
                  onChanged: (v) => _saveBool('compact_mode', v, (val) => _compactMode = val),
                ),
                _buildToggleRow(
                  icon: Icons.notifications_none_rounded,
                  color: Colors.pinkAccent,
                  title: "Systémová oznámení",
                  subtitle: "Zobrazovat potvrzení o provedených akcích dole na liště",
                  value: _showNotifications,
                  onChanged: (v) => _saveBool('show_notifications', v, (val) => _showNotifications = val),
                  isLast: true,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- MODERNÍ UI ENGINE ---

  Widget _buildTopDashboard() {
    return Row(
      children: [
        _stat("ENGINE", "SQLITE 3", Colors.greenAccent),
        _vSep(),
        _stat("LATENCE", "12ms", const Color(0xFF4077D1)),
        _vSep(),
        _stat("SESSION", "AKTIVNÍ", Colors.white24),
      ],
    );
  }

  Widget _buildPathRow({
    required IconData icon,
    required Color color,
    required String title,
    required String path,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                height: 36, width: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(path, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
              TextButton(
                onPressed: onTap,
                child: const Text("ZMĚNIT", style: TextStyle(color: Color(0xFF4077D1), fontWeight: FontWeight.w900, fontSize: 10)),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.white.withOpacity(0.03)),
      ],
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: color.withOpacity(0.4), size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF4077D1),
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                thumbColor: const WidgetStatePropertyAll(Colors.white),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.white.withOpacity(0.03)),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white10, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _vSep() => Container(margin: const EdgeInsets.symmetric(horizontal: 24), height: 20, width: 1, color: Colors.white.withOpacity(0.03));

  // --- LOGIKA UKLÁDÁNÍ ---

  Future<void> _pickDirectory(String key, Function(String) update) async {
    String? path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, path);
      setState(() => update(path));
      if (mounted) zpracujKliknuti(context, "CESTA ULOŽENA");
    }
  }

  Future<void> _saveBool(String key, bool val, Function(bool) update) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    setState(() => update(val));
  }
}