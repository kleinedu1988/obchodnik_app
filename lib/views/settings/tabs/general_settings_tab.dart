import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings_helpers.dart';
import '../../../logic/notifications.dart'; // Pro tvůj skleněný SnackBar

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
  
  // Interval
  String _syncInterval = '1 měsíc';

  // Design Konstanty (Flat & Technical)
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _accentColor = Color(0xFF4077D1);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;

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
      _syncInterval = prefs.getString('sync_interval') ?? '1 měsíc';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 40, bottom: 60),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. DASHBOARD ---
          _buildTopDashboard(),

          const SizedBox(height: 48),

          // --- 2. ARCHIVNÍ SYSTÉM ---
          _headerText("ARCHIVNÍ SYSTÉM"),
          const SizedBox(height: 12),
          _buildCard(
            children: [
              _buildPathRow(
                icon: Icons.factory_rounded,
                color: _accentColor,
                title: "Výroba / Technická dokumentace",
                path: _techPath,
                onTap: () => _pickDirectory('tech_path', (val) => _techPath = val),
              ),
              _divider(),
              _buildPathRow(
                icon: Icons.description_rounded,
                color: Colors.purpleAccent,
                title: "Složka pro obchodní nabídky",
                path: _offerPath,
                onTap: () => _pickDirectory('offer_path', (val) => _offerPath = val),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // --- 3. AUTOMATIZACE ---
          _headerText("AUTOMATIZACE"),
          const SizedBox(height: 12),
          _buildCard(
            children: [
              _buildToggleRow(
                icon: Icons.sync_rounded,
                color: Colors.greenAccent,
                title: "Sledování změn na pozadí",
                subtitle: "Automaticky detekuje úpravy v Excel souborech",
                value: _autoSync,
                onChanged: (v) => _saveBool('auto_sync', v, (val) => _autoSync = val),
              ),
              _divider(),
              _buildDropdownRow(
                icon: Icons.history_toggle_off_rounded,
                color: Colors.amberAccent,
                title: "Interval kontroly dat",
                subtitle: "Po této době bude databáze označena za neaktuální",
                value: _syncInterval,
                items: ['teď', '1 týden', '2 týdny', '1 měsíc'],
                onChanged: (String? newValue) async {
                  if (newValue != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('sync_interval', newValue);
                    setState(() => _syncInterval = newValue);
                  }
                },
              ),
              _divider(),
              _buildToggleRow(
                icon: Icons.cloud_done_rounded,
                color: Colors.blueAccent,
                title: "Automatické zálohování",
                subtitle: "Vytvořit kopii databáze při importu",
                value: _autoBackup,
                onChanged: (v) => _saveBool('auto_backup', v, (val) => _autoBackup = val),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // --- 4. ROZHRANÍ ---
          _headerText("ROZHRANÍ"),
          const SizedBox(height: 12),
          _buildCard(
            children: [
              _buildToggleRow(
                icon: Icons.view_compact_rounded,
                color: Colors.orangeAccent,
                title: "Kompaktní zobrazení",
                subtitle: "Zmenší odsazení v seznamech",
                value: _compactMode,
                onChanged: (v) => _saveBool('compact_mode', v, (val) => _compactMode = val),
              ),
              _divider(),
              _buildToggleRow(
                icon: Icons.notifications_none_rounded,
                color: Colors.pinkAccent,
                title: "Systémová oznámení",
                subtitle: "Zobrazovat potvrzení o akcích",
                value: _showNotifications,
                onChanged: (v) => _saveBool('show_notifications', v, (val) => _showNotifications = val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGETY ---

  Widget _buildTopDashboard() {
    return Row(
      children: [
        _stat("ENGINE", "SQLITE 3", Colors.greenAccent),
        _vSep(),
        _stat("LATENCE", "12ms", _accentColor),
        _vSep(),
        _stat("SESSION", "AKTIVNÍ", Colors.white24),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildPathRow({
    required IconData icon,
    required Color color,
    required String title,
    required String path,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            height: 36, width: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                const SizedBox(height: 4),
                Text(path, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: const Text("ZMĚNIT", style: TextStyle(color: Color(0xFF4077D1), fontWeight: FontWeight.w900, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.5), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                Text(subtitle, style: const TextStyle(color: _textDim, fontSize: 10)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _accentColor,
            activeTrackColor: _accentColor.withOpacity(0.2),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white.withOpacity(0.05),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.5), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                Text(subtitle, style: const TextStyle(color: _textDim, fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white24, size: 16),
                style: const TextStyle(color: _accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                dropdownColor: _bgCard,
                onChanged: onChanged,
                items: items.map<DropdownMenuItem<String>>((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: _borderColor);

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
      
      if (mounted) {
        // OPRAVENO: Použití nové třídy Notifications
        Notifications.showSuccess(context, "CESTA ULOŽENA");
      }
    }
  }

  Future<void> _saveBool(String key, bool val, Function(bool) update) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    setState(() => update(val));
    // Volitelně můžeme přidat toast i sem
  }
}