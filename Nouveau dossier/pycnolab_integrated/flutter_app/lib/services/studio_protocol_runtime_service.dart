import 'dart:convert';
import 'dart:io';

import '../database/protocole_dao.dart';
import '../models/protocole_model.dart';

/// Pont entre la source de vérité SQLite du Studio et l'ancien contrat
/// d'exécution Python qui attend encore un chemin vers un fichier JSON.
class StudioProtocolRuntimeService {
  StudioProtocolRuntimeService({ProtocoleDao? dao}) : _dao = dao ?? ProtocoleDao();

  final ProtocoleDao _dao;

  Future<List<ProtocoleModel>> listerProtocolesActifs() {
    return _dao.lister(corbeille: false);
  }

  /// Matérialise un protocole SQLite en JSON dans le dossier temporaire.
  /// Le fichier est destiné au backend local uniquement et ne constitue pas
  /// une seconde base de données utilisateur.
  Future<StudioProtocolFile> materialiser(ProtocoleModel protocole) async {
    final directory = await Directory.systemTemp.createTemp('pycnolab_protocol_');
    final safeName = protocole.codeNorme.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${directory.path}/$safeName.json');

    final variables = protocole.formules
        .map((formule) => <String, Object?>{
              'key': formule.cleVariable,
              'nom': formule.libelle,
              'unite': formule.unite,
              'valeur_defaut': 0.0,
            })
        .toList(growable: false);

    final formulePrincipale = protocole.formules
        .map((formule) => formule.expression.trim())
        .firstWhere((expression) => expression.isNotEmpty, orElse: () => 'force_f / section_a');

    final calculsDemandes = <String>{
      ...protocole.formules.map((formule) => formule.cleVariable),
      if (protocole.criteres.any((critere) => critere.cleVariable == 'energie_rupture')) 'energie_rupture',
      if (protocole.criteres.any((critere) => critere.cleVariable == 'limite_elastique')) 'limite_elastique',
    }.toList(growable: false);

    final payload = <String, Object?>{
      'nom': protocole.titre,
      'nom_protocole': protocole.titre,
      'metadata': {
        'code_norme': protocole.codeNorme,
        'categorie': protocole.categorie,
        'description': protocole.description,
        'version': protocole.version,
      },
      'variables': variables,
      'calcul': {
        'formule': formulePrincipale,
        'calculs_demandes': calculsDemandes,
      },
    };

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    return StudioProtocolFile(file: file, source: protocole);
  }
}

class StudioProtocolFile {
  const StudioProtocolFile({required this.file, required this.source});

  final File file;
  final ProtocoleModel source;

  String get path => file.path;
}
