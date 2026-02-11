import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../logic/db_service.dart';
import '../logic/import_logic.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  Future<void> _spustitImportProces(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      await ImportLogic.spustitImport(context, file);
      setState(() {});
    }
  }

  Widget _thinDivider() {
  return Container(height: 1, color: Colors.white.withOpacity(0.06));
}

Widget _statusChip(Color color, int rowCount) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(_rChip),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(
      rowCount <= 0 ? 'EMPTY' : 'OK',
      style: TextStyle(
        color: color.withOpacity(0.95),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    ),
  );
}

Widget _primaryButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(_rChip),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(_rChip),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blueAccent.withOpacity(0.95)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    ),
  );
}


  // =============================================================
  //  VS/FLUENT-LITE GRID CONSTANTS
  // =============================================================
  static const double _padX = 16;
  static const double _colStatus = 56;
  static const double _colId = 84;
  static const double _colTrailing = 34;

  // Jemné radiusy (VS/Fluent-lite)
  static const double _rPanel = 12;
  static const double _rChip = 10;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nastavení systému',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.blueAccent,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Stav databáze'),
              Tab(text: 'Databáze zákazníků'),
              Tab(text: 'Obecná nastavení'),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: TabBarView(
              children: [
                _buildStavDatabaze(),
                _buildZakaznici(context),
                _buildObecne(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStavDatabaze() {
  return FutureBuilder<List<dynamic>>(
    future: Future.wait([
      DbService().getLastEntry(),
      DbService().getRowCount(),
    ]),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      final lastEntry = snapshot.data?[0] as Map<String, dynamic>?;
      final rowCount = snapshot.data?[1] as int? ?? 0;

      // --- LOGIKA STAVU (tvoje, jen vizuálně jemnější) ---
      Color stavBarva = Colors.redAccent;
      String stavNadpis = 'Databáze je prázdná';
      String stavPopis = 'V systému nejsou žádná data. Proveďte první import.';
      IconData stavIkona = Icons.storage_rounded;

      if (rowCount > 0 && lastEntry != null) {
        final ts = (lastEntry['timestamp'] ?? '').toString();
        final datumDb = DateTime.tryParse(ts);
        final rozdilDni = datumDb == null ? 999 : DateTime.now().difference(datumDb).inDays;

        if (rozdilDni > 7) {
          stavBarva = Colors.orangeAccent;
          stavNadpis = 'Data jsou neaktuální';
          stavPopis = 'Databáze obsahuje $rowCount záznamů (stáří $rozdilDni dní).';
          stavIkona = Icons.history_rounded;
        } else {
          stavBarva = Colors.greenAccent;
          stavNadpis = 'Systém je v pořádku';
          stavPopis = 'V databázi je připraveno $rowCount záznamů k práci.';
          stavIkona = Icons.check_circle_outline;
        }
      }

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HLAVNÍ STATUS PANEL – glass jako zbytek
            _glassPanel(
              radiusTop: true,
              radiusBottom: true,
              child: Stack(
                children: [
                  // Jemná “VS” linka vlevo (status)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      color: stavBarva.withOpacity(0.55),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(_padX, 14, _padX, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Horní řádek: ikonka + title + status chip
                        Row(
                          children: [
                            Icon(stavIkona, color: stavBarva.withOpacity(0.85), size: 20),
                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                stavNadpis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.92),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),

                            _statusChip(stavBarva, rowCount),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Text(
                          stavPopis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 14),
                        _thinDivider(),

                        const SizedBox(height: 12),

                        // Spodní řádek: zdroj + tlačítko
                        Row(
                          children: [
                            Text(
                              'Zdroj: Excel (.xlsx)',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.28),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),

                            _primaryButton(
                              icon: Icons.sync_rounded,
                              label: 'AKTUALIZOVAT DATA',
                              onTap: () => _spustitImportProces(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}



  // =============================================================
  //  ZÁKAZNÍCI – VS/FLUENT-LITE + SUBTLE GLASS
  // =============================================================

  Widget _buildZakaznici(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1) Search + filtry (ploché)
        Row(
          children: [
            Expanded(child: _searchFieldStub()),
            const SizedBox(width: 10),
            _buildFlatChip('Vše', true),
            const SizedBox(width: 8),
            _buildFlatChip('Bez složky', false),
          ],
        ),
        const SizedBox(height: 14),

        // 2) Panel header (flat + jemné glass)
        _glassPanel(
          radiusTop: true,
          radiusBottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _padX, vertical: 10),
            child: Row(
              children: [
                SizedBox(width: _colStatus, child: _headerText('STAV')),
                SizedBox(width: _colId, child: _headerText('ID')),
                Expanded(child: _headerText('NÁZEV ZÁKAZNÍKA')),
                Expanded(child: _headerText('SLOŽKA / CESTA')),
                const SizedBox(width: _colTrailing),
              ],
            ),
          ),
        ),

        // 3) List (flat řádky, jemné oddělovače)
        Expanded(
          child: _glassPanel(
            radiusTop: false,
            radiusBottom: false,
            child: ListView.builder(
              itemCount: 15,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final bool ok = index % 4 != 0;
                final bool selected = index == 2;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    // VS-like selection (jemná modrá)
                    color: selected
                        ? Colors.blueAccent.withOpacity(0.10)
                        : (index.isEven ? Colors.white.withOpacity(0.015) : Colors.transparent),
                    border: Border(
                      left: BorderSide(
                        color: selected ? Colors.blueAccent.withOpacity(0.9) : Colors.transparent,
                        width: 3,
                      ),
                      bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _padX, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _colStatus,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _StatusIndicator(isActive: ok),
                          ),
                        ),
                        SizedBox(
                          width: _colId,
                          child: Text(
                            '#${1045 + index}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.30),
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        // Customer typography (víc VS, méně “heavy”)
                        Expanded(
                          child: Text(
                            'STAVEBNINY LIBEREC s.r.o.',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.2,
                              height: 1.15,
                              letterSpacing: -0.10,
                              color: selected ? Colors.white : Colors.white.withOpacity(0.84),
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),

                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildFolderTag(ok),
                          ),
                        ),

                        SizedBox(
                          width: _colTrailing,
                          child: ok
                              ? Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                  color: Colors.white.withOpacity(0.22),
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // 4) Footer
        _glassPanel(
          radiusTop: false,
          radiusBottom: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _padX, vertical: 10),
            child: Row(
              children: [
                Text(
                  'CELKEM: 15 240',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.24),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Text(
                  'ZOBRAZENO: 15',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.16),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =============================================================
  //  SUBTLE GLASS PANEL (flat + thin lines)
  // =============================================================
  Widget _glassPanel({
    required Widget child,
    required bool radiusTop,
    required bool radiusBottom,
  }) {
    final BorderRadius radius = BorderRadius.only(
      topLeft: Radius.circular(radiusTop ? _rPanel : 0),
      topRight: Radius.circular(radiusTop ? _rPanel : 0),
      bottomLeft: Radius.circular(radiusBottom ? _rPanel : 0),
      bottomRight: Radius.circular(radiusBottom ? _rPanel : 0),
    );

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            // Ploché: žádné velké stíny, jen translucent vrstva + linky
            color: const Color(0xFF151515).withOpacity(0.65),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: child,
        ),
      ),
    );
  }

  // =============================================================
  //  SEARCH (VS-like) – plochý, jemný glass
  // =============================================================
  Widget _searchFieldStub() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_rPanel),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(_rPanel),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.35), size: 18),
              const SizedBox(width: 10),
              Text(
                'Hledat v databázi…',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.20),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(_rChip),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Text(
                  'CTRL + K',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.18),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================
  //  FLAT CHIP (VS-like)
  // =============================================================
  Widget _buildFlatChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.blueAccent.withOpacity(0.12) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(_rChip),
        border: Border.all(
          color: active ? Colors.blueAccent.withOpacity(0.55) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: active ? Colors.blueAccent.withOpacity(0.95) : Colors.white.withOpacity(0.35),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // =============================================================
  //  FOLDER TAG (ikony modré, flat)
  // =============================================================
  Widget _buildFolderTag(bool hasFolder) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasFolder ? Colors.blueAccent.withOpacity(0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(_rChip),
        border: Border.all(
          color: hasFolder ? Colors.blueAccent.withOpacity(0.22) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFolder ? Icons.folder_rounded : Icons.folder_off_rounded,
            size: 14,
            color: hasFolder ? Colors.blueAccent.withOpacity(0.90) : Colors.white.withOpacity(0.16),
          ),
          const SizedBox(width: 8),
          Text(
            hasFolder ? 'Zakaznik_C204_Final' : 'Bez složky',
            style: TextStyle(
              color: hasFolder ? Colors.white.withOpacity(0.62) : Colors.white.withOpacity(0.24),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withOpacity(0.22),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildObecne() {
    return const Center(child: Text('Obecná nastavení'));
  }
}

// =============================================================
//  ANIMOVANÝ INDIKÁTOR STAVU (subtle pulsing)
// =============================================================

class _StatusIndicator extends StatefulWidget {
  final bool isActive;
  const _StatusIndicator({required this.isActive});

  @override
  State<_StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<_StatusIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.isActive ? Colors.greenAccent : Colors.redAccent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = Curves.easeInOut.transform(_controller.value);
        final double glow = 3 + (7 * t);
        final double alpha = 0.10 + (0.28 * t);

        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor,
            boxShadow: [
              BoxShadow(
                color: baseColor.withOpacity(alpha),
                blurRadius: glow,
                spreadRadius: 0.3 + (0.9 * t),
              ),
            ],
          ),
        );
      },
    );
  }
}
