import 'dart:io';
import 'dart:ui';

import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';

import 'db_service.dart';

class ImportLogic {
  static Future<void> spustitImport(BuildContext context, File file) async {
    final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);

    // VS/Fluent-lite dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _ImportProgressDialog(progress: progressNotifier);
      },
    );

    try {
      // Načtení Excelu (v paměti)
      final bytes = file.readAsBytesSync();
      final excel = ex.Excel.decodeBytes(bytes);


      final List<Map<String, dynamic>> dataToInsert = [];
      final String nyni = DateTime.now().toIso8601String();

      for (final table in excel.tables.keys) {
        final rows = excel.tables[table]!.rows;
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.length >= 3) {
            dataToInsert.add({
              'externi_id': row[0]?.value?.toString() ?? '',
              'nazev': row[1]?.value?.toString() ?? '',
              'ic': row[2]?.value?.toString() ?? '',
              'folder_path': '',
              'timestamp': nyni,
            });
          }
        }
      }

      // Zápis do DB s aktualizací progress baru
      await DbService().importZakazniku(dataToInsert, (progress) {
        // Ošetření rozsahu (0..1)
        final p = progress.clamp(0.0, 1.0);
        progressNotifier.value = p;
      });

      // Zavření dialogu po dokončení
      if (Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      // Zavřít dialog i v případě chyby
      if (Navigator.canPop(context)) Navigator.pop(context);
      // ignore: avoid_print
      print('Chyba při importu: $e');

      // Volitelně: zobrazit minimalistickou chybu
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chyba při importu: $e'),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
      );
    } finally {
      progressNotifier.dispose();
    }
  }
}

/// VS/Fluent-lite + subtle glass progress dialog
class _ImportProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progress;
  const _ImportProgressDialog({required this.progress});

  static const double _r = 12;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 460,
            decoration: BoxDecoration(
              color: const Color(0xFF151515).withOpacity(0.78),
              borderRadius: BorderRadius.circular(_r),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // HEADER – flat, VS-like
                  Row(
                    children: [
                      Icon(Icons.sync_rounded, size: 18, color: Colors.white.withOpacity(0.75)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Importuji data…',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      // Minimal close/cancel (jen zavře dialog)
                      _FlatAction(
                        label: 'Zavřít',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // SUBTEXT (VS hint)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Načítám Excel a ukládám do databáze…',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.38),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // PROGRESS
                  ValueListenableBuilder<double>(
                    valueListenable: progress,
                    builder: (context, value, child) {
                      final pct = (value * 100).round();

                      return Column(
                        children: [
                          // Flat progress bar frame
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.transparent,
                                color: Colors.blueAccent.withOpacity(0.85),
                                minHeight: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                '$pct%',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                value < 1.0 ? 'Probíhá…' : 'Hotovo',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.28),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plochá VS-like akce (není to button s fill, jen ink + border)
class _FlatAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FlatAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
