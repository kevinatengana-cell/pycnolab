import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/gamme_request.dart';
import '../models/resultat_gamme.dart';

/// Service qui parle au serveur Python local (FastAPI).
///
/// IMPORTANT : le serveur doit tourner avant de lancer l'app Flutter en
/// dev. Dans un terminal séparé :
///   uvicorn moteur_python.api.main:app --reload --port 8000
///
/// (Plus tard, pour la version livrée au labo, on pourra démarrer ce
/// serveur automatiquement en sous-processus depuis Flutter, ou
/// l'empaqueter en .exe avec PyInstaller — gratuit — pour que le labo
/// n'ait rien à installer manuellement.)
class PythonEngineService {
  // 127.0.0.1 fonctionne pour une app Windows/desktop.
  // Si un jour vous testez sur émulateur Android, il faudra remplacer
  // par 10.0.2.2 (l'émulateur ne voit pas 127.0.0.1 comme la machine hôte).
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

  Future<dynamic> calculerDepuisExcel(String cheminFichier, [GammeRequest? configInitiale]) async {
    final Map<String, dynamic> body = configInitiale?.toJson() ?? {};
    body["chemin_fichier"] = cheminFichier;

    final reponse = await http.post(
      Uri.parse("$_baseUrl/essais/traction/calculer-depuis-excel"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (reponse.statusCode != 200) {
      throw Exception(
        "Erreur du moteur de calcul Excel (${reponse.statusCode}) : ${reponse.body}",
      );
    }

    // Retourne la Map décodée pour préserver les champs bruts ajoutés
    // côté serveur (largeur_mm, epaisseur_mm, force_rupture_newton, ...).
    return jsonDecode(utf8.decode(reponse.bodyBytes));
  }

  /// Télécharge le PV Excel généré et le sauvegarde localement.
  /// Retourne le chemin du fichier enregistré.
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
}
