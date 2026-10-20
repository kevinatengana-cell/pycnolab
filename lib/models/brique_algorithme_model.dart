import 'dart:convert';

/// Une grandeur dont la fenêtre de calcul varie selon la forme réelle de
/// chaque courbe (ex. module d'Young) n'est jamais une formule tapée par
/// le technicien — c'est un algorithme Python paramétrable, appelé par
/// son identifiant, avec ses propres seuils.
class BriqueAlgorithmeModel {
  const BriqueAlgorithmeModel({
    this.id,
    this.feuilleId,
    required this.nomTechnique,
    required this.brique,
    this.parametres = const <String, Object?>{},
    this.variableX,
    this.variableY,
  });

  final int? id;
  final int? feuilleId;

  /// ex. "E_MPa"
  final String nomTechnique;

  /// Identifiant de l'algorithme Python à appeler, ex.
  /// "detection_fenetre_elastique" (correspond à detecter_pente_ascendante
  /// côté moteur_python/calculs/outils/regression.py).
  final String brique;

  /// ex. { "contrainte_min_pct": 20, "contrainte_max_pct": 70, "r2_min": 0.98 }
  final Map<String, Object?> parametres;

  /// Quelles variables déjà calculées servent d'axes à la détection
  /// (ex. variableX = "Def", variableY = "Cont").
  final String? variableX;
  final String? variableY;

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'feuille_id': feuilleId,
      'nom_technique': nomTechnique,
      'brique': brique,
      'parametres_json': jsonEncode(parametres),
      'variable_x': variableX,
      'variable_y': variableY,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  factory BriqueAlgorithmeModel.fromMap(Map<String, Object?> map) {
    final rawJson = map['parametres_json'] as String?;
    Map<String, Object?> parametres = const <String, Object?>{};
    if (rawJson != null && rawJson.isNotEmpty) {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, Object?>) parametres = decoded;
    }
    return BriqueAlgorithmeModel(
      id: (map['id'] as num?)?.toInt(),
      feuilleId: (map['feuille_id'] as num?)?.toInt(),
      nomTechnique: map['nom_technique'] as String? ?? '',
      brique: map['brique'] as String? ?? '',
      parametres: parametres,
      variableX: map['variable_x'] as String?,
      variableY: map['variable_y'] as String?,
    );
  }

  BriqueAlgorithmeModel copyWith({
    int? id,
    int? feuilleId,
    String? nomTechnique,
    String? brique,
    Map<String, Object?>? parametres,
    String? variableX,
    String? variableY,
  }) {
    return BriqueAlgorithmeModel(
      id: id ?? this.id,
      feuilleId: feuilleId ?? this.feuilleId,
      nomTechnique: nomTechnique ?? this.nomTechnique,
      brique: brique ?? this.brique,
      parametres: parametres ?? this.parametres,
      variableX: variableX ?? this.variableX,
      variableY: variableY ?? this.variableY,
    );
  }

  /// Contrat réseau : parametres reste une vraie Map JSON ici (contrairement
  /// à toMap() qui l'encode en texte pour la colonne SQLite).
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'nom_technique': nomTechnique,
      'brique': brique,
      'parametres': parametres,
      'variable_x': variableX,
      'variable_y': variableY,
    };
  }

  factory BriqueAlgorithmeModel.fromJson(Map<String, Object?> json) {
    final rawParams = json['parametres'];
    return BriqueAlgorithmeModel(
      nomTechnique: json['nom_technique'] as String? ?? '',
      brique: json['brique'] as String? ?? '',
      parametres: rawParams is Map<String, Object?> ? rawParams : const <String, Object?>{},
      variableX: json['variable_x'] as String?,
      variableY: json['variable_y'] as String?,
    );
  }
}
