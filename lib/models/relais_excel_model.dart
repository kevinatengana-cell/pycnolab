/// Représente une "cellule relais" : une variable qui vit comme colonne
/// répétée dans le Tableau structuré de sa feuille, mais dont la valeur
/// vient réellement d'une autre feuille (ex. Section_mm2 depuis
/// 'DIAMETRE (CR,CS)'). La première ligne de cette colonne est une vraie
/// formule de cellule vers la source — jamais une constante recopiée.
class RelaisExcelModel {
  const RelaisExcelModel({
    this.id,
    this.feuilleId,
    required this.nomTechnique,
    required this.feuilleSource,
    required this.variableSource,
  });

  final int? id;
  final int? feuilleId;
  final String nomTechnique;
  final String feuilleSource;
  final String variableSource;

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'feuille_id': feuilleId,
      'nom_technique': nomTechnique,
      'feuille_source': feuilleSource,
      'variable_source': variableSource,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  factory RelaisExcelModel.fromMap(Map<String, Object?> map) {
    return RelaisExcelModel(
      id: (map['id'] as num?)?.toInt(),
      feuilleId: (map['feuille_id'] as num?)?.toInt(),
      nomTechnique: map['nom_technique'] as String? ?? '',
      feuilleSource: map['feuille_source'] as String? ?? '',
      variableSource: map['variable_source'] as String? ?? '',
    );
  }

  RelaisExcelModel copyWith({
    int? id,
    int? feuilleId,
    String? nomTechnique,
    String? feuilleSource,
    String? variableSource,
  }) {
    return RelaisExcelModel(
      id: id ?? this.id,
      feuilleId: feuilleId ?? this.feuilleId,
      nomTechnique: nomTechnique ?? this.nomTechnique,
      feuilleSource: feuilleSource ?? this.feuilleSource,
      variableSource: variableSource ?? this.variableSource,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'nom_technique': nomTechnique,
      'feuille_source': feuilleSource,
      'variable_source': variableSource,
    };
  }

  factory RelaisExcelModel.fromJson(Map<String, Object?> json) {
    return RelaisExcelModel(
      nomTechnique: json['nom_technique'] as String? ?? '',
      feuilleSource: json['feuille_source'] as String? ?? '',
      variableSource: json['variable_source'] as String? ?? '',
    );
  }
}
