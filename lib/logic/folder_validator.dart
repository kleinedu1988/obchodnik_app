import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class FolderValidator {
  /// Ověří, zda existuje zákaznická složka v kořeni TECH a OFFER.
  /// relativePath typicky něco jako: "C204_STAVEBNINY_LIBEREC"
  /// Vrací mapu: {'tech': true/false, 'offer': true/false}
  static Future<Map<String, bool>> checkCustomerFolders(String relativePath) async {
    final rel = relativePath.trim();
    if (rel.isEmpty) return {'tech': false, 'offer': false};

    final prefs = await SharedPreferences.getInstance();
    final String techRoot = (prefs.getString('tech_path') ?? '').trim();
    final String offerRoot = (prefs.getString('offer_path') ?? '').trim();

    bool techExists = false;
    bool offerExists = false;

    if (techRoot.isNotEmpty) {
      final techPath = p.join(techRoot, rel);
      techExists = await Directory(techPath).exists();
    }

    if (offerRoot.isNotEmpty) {
      final offerPath = p.join(offerRoot, rel);
      offerExists = await Directory(offerPath).exists();
    }

    return {'tech': techExists, 'offer': offerExists};
  }
}
