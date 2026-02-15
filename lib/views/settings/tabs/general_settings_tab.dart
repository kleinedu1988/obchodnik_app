import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../logic/notifications.dart'; 

class GeneralSettingsTab extends StatefulWidget {
  const GeneralSettingsTab({super.key});

  @override
  State<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<GeneralSettingsTab> with SingleTickerProviderStateMixin {
  // Cesty
  String _techPath = 'Není nastaveno';
  String _offerPath = 'Není nastaveno';
  
  // Stavy existence cest
  bool _techExists = false;
  bool _offerExists = false;
  
  // Preference
  bool _showNotifications = true;
  bool _autoSync = false;
  bool _compactMode = false;
  bool _autoBackup = true;
  String _syncInterval = '1 měsíc';

  // Design Konstanty (v0.4.2 standard)
  static const Color _bgCard = Color(0xFF16181D);
  static const Color _blueColor = Color(0xFF4077D1);
  static const Color _pinkColor = Color(0xFFE056FD);
  static const Color _borderColor = Color(0xFF2A2D35);
  static const Color _textDim = Colors.white54;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1500)
    )..repeat(reverse: true);
    _loadSettings();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final tPath = prefs.getString('tech_path') ?? 'Není nastaveno';
    final oPath = prefs.getString('offer_path') ?? 'Není nastaveno';

    // Okamžitá kontrola existence na disku
    final tExists = tPath != 'Není nastaveno' && await Directory(tPath).exists();
    final oExists = oPath != 'Není nastaveno' && await Directory(oPath).exists();

    setState(() {
      _techPath = tPath;
      _offerPath = oPath;
      _techExists = tExists;
      _offerExists = oExists;
      _showNotifications = prefs.getBool('show_notifications') ?? true;
      _autoSync = prefs.getBool('auto_sync') ?? false;
      _compactMode = prefs.getBool('compact_mode') ?? false;
      _autoBackup = prefs.getBool('auto_backup') ?? true;
      _syncInterval = prefs.getString('sync_interval') ?? '1 měsíc';
    });
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 40, bottom: 60),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopDashboard(),
          const SizedBox(height: 48),

          _headerText("ARCHIVNÍ SYSTÉM (ROOT PATHS)"),
          const SizedBox(height: 12),
          _buildCard(
            children: [
              _buildPathRow(
                icon: Icons.factory_rounded,
                color: _blueColor,
                title: "Výroba / Technická dokumentace",
                path: _techPath,
                isValid: _techExists,
                onTap: () => _pickDirectory('tech_path', (val) => _techPath = val),
              ),
              _divider(),
              _buildPathRow(
                icon: Icons.description_rounded,
                color: _pinkColor,
                title: "Složka pro obchodní nabídky",
                path: _offerPath,
                isValid: _offerExists,
                onTap: () => _pickDirectory('offer_path', (val) => _offerPath = val),
              ),
            ],
          ),

          const SizedBox(height: 32),
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
                subtitle: "Kdy označit data za neaktuální",
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
            ],
          ),

          const SizedBox(height: 32),
          _headerText("ROZHRANÍ"),
          const SizedBox(height: 12),
          _buildCard(
            children: [
              _buildToggleRow(
                icon: Icons.notifications_none_rounded,
                color: Colors.pinkAccent,
                title: "Systémová oznámení",
                subtitle: "Zobrazovat skleněné SnackBar potvrzení",
                value: _showNotifications,
                onChanged: (v) => _saveBool('show_notifications', v, (val) => _showNotifications = val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SPECIALIZOVANÉ WIDGETY ---

  Widget _buildTopDashboard() {
    return Row(
      children: [
        _stat("VERSION", "0.4.2", Colors.greenAccent),
        _vSep(),
        _stat("DB ENGINE", "SQLITE v4", _blueColor),
        _vSep(),
        _stat("UI MODE", _compactMode ? "COMPACT" : "STANDARD", Colors.white24),
      ],
    );
  }

  Widget _buildPathRow({
    required IconData icon,
    required Color color,
    required String title,
    required String path,
    required bool isValid,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Ikona s pulzujícím indikátorem stavu
          Stack(
            children: [
              Container(
                height: 40, width: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Positioned(
                right: 0, top: 0,
                child: _buildSmallPulse(isValid),
              )
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  path, 
                  style: TextStyle(
                    color: isValid ? Colors.white24 : Colors.redAccent.withOpacity(0.5), 
                    fontSize: 11, 
                    fontFamily: 'monospace',
                    decoration: isValid ? null : TextDecoration.lineThrough,
                  )
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text("ZMĚNIT", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallPulse(bool ok) {
    final color = ok ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5 * _pulseController.value),
                blurRadius: 4 * _pulseController.value,
                spreadRadius: 2 * _pulseController.value,
              )
            ],
          ),
        );
      },
    );
  }

  // ... (ponechat stávající pomocné widgety _divider, _buildCard, _stat, _vSep, _headerText atd.) ...

  Widget _divider() => Divider(height: 1, color: _borderColor);

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

  Widget _headerText(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
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
            activeThumbColor: _blueColor,
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
                style: const TextStyle(color: _blueColor, fontSize: 12, fontWeight: FontWeight.bold),
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

  // --- LOGIKA ---

  Future<void> _pickDirectory(String key, Function(String) update) async {
    String? path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, path);
      
      // Re-validace po výběru
      final exists = await Directory(path).exists();
      
      setState(() {
        update(path);
        if (key == 'tech_path') _techExists = exists;
        if (key == 'offer_path') _offerExists = exists;
      });
      
      if (mounted) {
        Notifications.showSuccess(context, "CESTA ULOŽENA");
      }
    }
  }

  Future<void> _saveBool(String key, bool val, Function(bool) update) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    setState(() => update(val));
  }
}