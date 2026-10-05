import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/feuille_excel_model.dart';
import '../models/gamme_request.dart';
import '../models/resultat_gamme.dart';

class PythonEngineService {
  static const String _baseUrl = 'http://127.0.0.1:8123';

  Future<Map<String, dynamic>> analyserTraction(TractionPayload payload) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/calculs/traction'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur du calcul de traction (${response.statusCode}) : ${response.body}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> analyserGammeSerie({
    required String nomGamme,
    required List<TractionPayload> echantillons,
  }) async {
    final body = {
      'nom_gamme': nomGamme,
      'echantillons': echantillons
          .map((e) => (e as TractionPayload).toJson())
          .toList(),
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/api/calculs/gamme'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur du calcul de gamme (${response.statusCode}) : ${response.body}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> exporterExcelDynamique({
    required TractionPayload payload,
    required Map<String, String> mappingCellules,
    String templatePath = 'MODELE_TRACTION.xlsx',
  }) async {
    final body = {
      'donnees_traction': payload.toJson(),
      'mapping_cellules': mappingCellules,
      'chemin_template': templatePath,
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/api/export/excel'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur lors de la génération Excel (${response.statusCode}) : ${response.body}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<ResultatGamme> calculerTraction(GammeRequest gamme) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/essais/traction/calculer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(gamme.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur du moteur de calcul (${response.statusCode}) : ${response.body}',
      );
    }
    return ResultatGamme.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<dynamic> calculerDepuisExcel(
    String cheminFichier, [
    GammeRequest? configInitiale,
  ]) async {
    final body = configInitiale?.toJson() ?? <String, dynamic>{};
    body['chemin_fichier'] = cheminFichier;
    final response = await http.post(
      Uri.parse('$_baseUrl/essais/traction/calculer-depuis-excel'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur du moteur de calcul Excel (${response.statusCode}) : ${response.body}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<String> exporterClasseurTraction({
    required String cheminFichier,
    required String cheminDestination,
    double l0Mm = 20.0,
  }) async {
    final destination = cheminDestination.trim();
    if (destination.isEmpty) {
      throw ArgumentError('Le chemin de destination est obligatoire.');
    }

    final outputFile = File(destination);
    if (outputFile.parent.path.isNotEmpty && !outputFile.parent.existsSync()) {
      await outputFile.parent.create(recursive: true);
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/essais/traction/exporter-excel'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'chemin_fichier': cheminFichier, 'l0_mm': l0Mm}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur de génération du rapport Excel (${response.statusCode}) : ${response.body}',
      );
    }

    await outputFile.writeAsBytes(response.bodyBytes, flush: true);
    return outputFile.path;
  }

  Future<String> exporterExcel(
    GammeRequest gamme, {
    required String cheminDestination,
    String typeGraphique = 'barres',
  }) async {
    final response = await http.post(
      Uri.parse(
        '$_baseUrl/essais/traction/export-excel?type_graphique=$typeGraphique',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(gamme.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur de génération Excel (${response.statusCode}) : ${response.body}',
      );
    }
    final outputFile = File(cheminDestination.trim());
    await outputFile.writeAsBytes(response.bodyBytes, flush: true);
    return outputFile.path;
  }

  Future<dynamic> executerProtocole({
    required Map<String, Object?> protocole,
    required String cheminFichier,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/protocoles/executer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'protocole': protocole,
        'chemin_fichier': cheminFichier,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur d’exécution du protocole (${response.statusCode}) : ${response.body}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<List<FeuilleExcelModel>> analyserEchantillonZero(
    String cheminFichier,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/protocoles/analyser-echantillon-zero'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'chemin_fichier': cheminFichier}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur d’analyse du fichier Échantillon Zéro (${response.statusCode}) : ${response.body}',
      );
    }
    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
    final feuillesJson = (decoded['feuilles'] as List?) ?? const [];
    return feuillesJson
        .asMap()
        .entries
        .map(
          (entry) => FeuilleExcelModel.fromJson(
            Map<String, Object?>.from(entry.value as Map),
            ordre: entry.key + 1,
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, Object?>> testerFormule({
    required String formule,
    required String cheminFichier,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/protocoles/tester-formule'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'formule': formule, 'chemin_fichier': cheminFichier}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur d’évaluation de la formule (${response.statusCode}) : ${response.body}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
  }

  // ---------------------------------------------------------------------
  // v1 — routes génériques par essai (traction / compression / flexion),
  // branchées sur /essais/{typeEssai}/... côté moteur Python. N'affecte pas
  // les méthodes ci-dessus, laissées telles quelles pour ne rien casser.
  // ---------------------------------------------------------------------

  /// Liste les gammes/échantillons d'un fichier brut sans exiger de
  /// géométrie — sert à construire l'écran de saisie des dimensions par
  /// échantillon (compression) avant de lancer le calcul.
  Future<Map<String, dynamic>> listerEchantillons({
    required String typeEssai,
    required String cheminFichier,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/essais/$typeEssai/lister-echantillons'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'chemin_fichier': cheminFichier}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur de lecture des échantillons (${response.statusCode}) : ${response.body}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Calcule un aperçu des résultats (Cont(max)/Def rupt/E par échantillon
  /// et par gamme) sans produire de fichier Excel.
  Future<Map<String, dynamic>> calculerEssaiDepuisExcel({
    required String typeEssai,
    required String cheminFichier,
    double? l0Mm,
    Map<String, dynamic>? geometrieCompression,
    Map<String, dynamic>? geometrieFlexion,
  }) async {
    final body = <String, dynamic>{
      'chemin_fichier': cheminFichier,
      if (l0Mm != null) 'l0_mm': l0Mm,
      if (geometrieCompression != null) 'geometrie_compression': geometrieCompression,
      if (geometrieFlexion != null) 'geometrie_flexion': geometrieFlexion,
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/essais/$typeEssai/calculer-depuis-excel'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur du calcul (${response.statusCode}) : ${response.body}',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Calcule et produit le fichier Excel intégralement rempli, sauvegardé
  /// à `cheminDestination`.
  Future<String> exporterEssaiExcel({
    required String typeEssai,
    required String cheminFichier,
    required String cheminDestination,
    double? l0Mm,
    Map<String, dynamic>? geometrieCompression,
    Map<String, dynamic>? geometrieFlexion,
    String? cheminModele,
  }) async {
    final body = <String, dynamic>{
      'chemin_fichier': cheminFichier,
      if (l0Mm != null) 'l0_mm': l0Mm,
      if (geometrieCompression != null) 'geometrie_compression': geometrieCompression,
      if (geometrieFlexion != null) 'geometrie_flexion': geometrieFlexion,
      if (cheminModele != null) 'chemin_modele': cheminModele,
    };
    final response = await http.post(
      Uri.parse('$_baseUrl/essais/$typeEssai/exporter-excel'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Erreur de génération du rapport (${response.statusCode}) : ${response.body}',
      );
    }
    final outputFile = File(cheminDestination);
    if (outputFile.parent.path.isNotEmpty && !outputFile.parent.existsSync()) {
      await outputFile.parent.create(recursive: true);
    }
    await outputFile.writeAsBytes(response.bodyBytes, flush: true);
    return outputFile.path;
  }
}