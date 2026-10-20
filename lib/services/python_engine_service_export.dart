import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'python_engine_service.dart';

extension PythonEngineExcelExport on PythonEngineService {
  /// Génère le rapport basé sur TRACTIONFIBREVEGETALE.xlsx.
  ///
  /// Pour obtenir les feuilles COROUI et COSOU, fournir les deux chemins.
  /// Retourne le chemin du fichier sauvegardé localement.
  Future<String> exporterRapportModele({
    required List<String> cheminsFichiers,
    required String dossierDestination,
    String? cheminModele,
  }) async {
    if (cheminsFichiers.isEmpty) {
      throw Exception('Aucun fichier de mesures sélectionné.');
    }

    final body = <String, dynamic>{
      'chemins_fichiers': cheminsFichiers,
    };
    if (cheminModele != null && cheminModele.trim().isNotEmpty) {
      body['chemin_modele'] = cheminModele;
    }

    final response = await http.post(
      Uri.parse(
        '${PythonEngineService.baseUrl}/essais/traction/rapport-modele',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur de génération du rapport (${response.statusCode}) : ${utf8.decode(response.bodyBytes)}',
      );
    }

    final outputPath = '$dossierDestination${Platform.pathSeparator}'
        'TRACTIONFIBREVEGETALE_resultats.xlsx';
    await File(outputPath).writeAsBytes(response.bodyBytes, flush: true);
    return outputPath;
  }
}
