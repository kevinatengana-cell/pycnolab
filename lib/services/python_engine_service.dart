// lib/services/python_engine_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/gamme_request.dart';
import '../models/resultat_gamme.dart';

/// Service qui parle au serveur Python local (FastAPI).
class PythonEngineService {
  // Port 8123 (utilisé par le backend)
  static const String _baseUrl = "http://127.0.0.1:8123";

  Future<ResultatGamme> calculerTraction(GammeRequest gamme) async {
    final reponse = await http.post(
      Uri.parse("$_baseUrl/essais/traction/calculer"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(gamme.toJson()),
    );

    if (reponse.statusCode != 200) {
      throw Exception(
        "Erreur du moteur de calcul (${reponse.statusCode}) : ${reponse.body}",
      );
    }

    return ResultatGamme.fromJson(jsonDecode(utf8.decode(reponse.bodyBytes)));
  }

  /// Format COMPLET (diamètres + courbe) - correspond aux vraies
  /// données du labo (fibres végétales). Voir reader.py côté backend.
  Future<dynamic> calculerDepuisExcel(String cheminFichier, [GammeRequest? configInitiale]) async {
    final Map<String, dynamic> body = configInitiale?.toJson() ?? {};
    body["chemin_fichier"] = cheminFichier;

    final reponse = await http.post(
      Uri.parse("$_baseUrl/essais/traction/calculer-depuis-excel-complet"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (reponse.statusCode != 200) {
      throw Exception(
        "Erreur du moteur de calcul Excel (${reponse.statusCode}) : ${reponse.body}",
      );
    }

    // Retourne la Map décodée pour préserver les champs bruts
    return jsonDecode(utf8.decode(reponse.bodyBytes));
  }

  Future<String> exporterExcel(
    GammeRequest gamme, {
    required String dossierDestination,
    String typeGraphique = "barres",
  }) async {
    final reponse = await http.post(
      Uri.parse("$_baseUrl/essais/traction/export-excel?type_graphique=$typeGraphique"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(gamme.toJson()),
    );

    if (reponse.statusCode != 200) {
      throw Exception(
        "Erreur de génération Excel (${reponse.statusCode}) : ${reponse.body}",
      );
    }

    final nomFichier = "PV_${gamme.materiau.codeInterne}.xlsx";
    final chemin = "$dossierDestination${Platform.pathSeparator}$nomFichier";
    final fichier = File(chemin);
    await fichier.writeAsBytes(reponse.bodyBytes);
    return chemin;
  }

  Future<String> genererRapportLabo(
    List<String> cheminsFichiers, {
    required String dossierDestination,
    String nomFichier = "rapport_labo.xlsx",
  }) async {
    final reponse = await http.post(
      Uri.parse("$_baseUrl/essais/traction/rapport-labo"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(cheminsFichiers),
    );

    if (reponse.statusCode != 200) {
      throw Exception(
        "Erreur de génération du rapport (${reponse.statusCode}) : ${reponse.body}",
      );
    }

    final chemin = "$dossierDestination${Platform.pathSeparator}$nomFichier";
    final fichier = File(chemin);
    await fichier.writeAsBytes(reponse.bodyBytes);
    return chemin;
  }
}
