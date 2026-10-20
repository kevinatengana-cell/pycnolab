import 'variable_excel_model.dart';
import 'relais_excel_model.dart';
import 'brique_algorithme_model.dart';
export 'variable_excel_model.dart';


/// Les 3 gabarits identifiés en pratique dans les fichiers réels de labo —
/// un nombre fini et volontairement limité, pas une mise en page libre.
enum GabaritExcel {
  blocHorizontalRepete,
  lignesEmpilees,
  colonnesParEchantillon,
}

GabaritExcel _gabaritFromString(String? value) {
  return GabaritExcel.values.firstWhere(
    (item) => item.name == value,
    orElse: () => GabaritExcel.blocHorizontalRepete,
  );
}

class FeuilleExcelModel {
  const FeuilleExcelModel({
    this.id,
    this.essaiId,
    required this.ordre,
    required this.nomFeuille,
    required this.gabarit,
    this.nomTableEch0,
    this.variables = const <VariableExcelModel>[],
    this.relais = const <RelaisExcelModel>[],
    this.briques = const <BriqueAlgorithmeModel>[],
  });

  final int? id;
  final int? essaiId;
  final int ordre;

  /// Nom de l'onglet dans le fichier généré, ex. "COROUI".
  final String nomFeuille;
  final GabaritExcel gabarit;

  /// Uniquement pour blocHorizontalRepete/lignesEmpilees : nom exact du
  /// Tableau structuré tel que présent dans le fichier Ech0 validé — la
  /// sous-chaîne que le moteur remplace par le nom du bon Tableau à chaque
  /// échantillon lors de la réplication. Null pour colonnesParEchantillon
  /// (ce gabarit utilise de simples formules relatives glissées).
  final String? nomTableEch0;

  final List<VariableExcelModel> variables;
  final List<RelaisExcelModel> relais;
  final List<BriqueAlgorithmeModel> briques;

  /// Largeur de bloc déduite (gabarits 1 et 3 uniquement) : nombre de
  /// variables déclarées + 1 colonne de séparation. Non stockée — recalculée
  /// à la volée pour ne jamais diverger du contenu réel des variables.
  int get largeurBlocDeduite => variables.length + 1;

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'essai_id': essaiId,
      'ordre': ordre,
      'nom_feuille': nomFeuille,
      'gabarit': gabarit.name,
      'nom_table_ech0': nomTableEch0,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  factory FeuilleExcelModel.fromMap(
    Map<String, Object?> map, {
    List<VariableExcelModel> variables = const <VariableExcelModel>[],
    List<RelaisExcelModel> relais = const <RelaisExcelModel>[],
    List<BriqueAlgorithmeModel> briques = const <BriqueAlgorithmeModel>[],
  }) {
    return FeuilleExcelModel(
      id: (map['id'] as num?)?.toInt(),
      essaiId: (map['essai_id'] as num?)?.toInt(),
      ordre: (map['ordre'] as num?)?.toInt() ?? 0,
      nomFeuille: map['nom_feuille'] as String? ?? '',
      gabarit: _gabaritFromString(map['gabarit'] as String?),
      nomTableEch0: map['nom_table_ech0'] as String?,
      variables: List.unmodifiable(variables),
      relais: List.unmodifiable(relais),
      briques: List.unmodifiable(briques),
    );
  }

  FeuilleExcelModel copyWith({
    int? id,
    int? essaiId,
    int? ordre,
    String? nomFeuille,
    GabaritExcel? gabarit,
    String? nomTableEch0,
    List<VariableExcelModel>? variables,
    List<RelaisExcelModel>? relais,
    List<BriqueAlgorithmeModel>? briques,
    bool clearNomTableEch0 = false,
  }) {
    return FeuilleExcelModel(
      id: id ?? this.id,
      essaiId: essaiId ?? this.essaiId,
      ordre: ordre ?? this.ordre,
      nomFeuille: nomFeuille ?? this.nomFeuille,
      gabarit: gabarit ?? this.gabarit,
      nomTableEch0: clearNomTableEch0 ? null : (nomTableEch0 ?? this.nomTableEch0),
      variables: List.unmodifiable(variables ?? this.variables),
      relais: List.unmodifiable(relais ?? this.relais),
      briques: List.unmodifiable(briques ?? this.briques),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'nom_feuille': nomFeuille,
      'gabarit': gabarit.name,
      'nom_table_ech0': nomTableEch0,
      'variables': variables.map((item) => item.toJson()).toList(),
      'relais': relais.map((item) => item.toJson()).toList(),
      'briques': briques.map((item) => item.toJson()).toList(),
    };
  }

  factory FeuilleExcelModel.fromJson(Map<String, Object?> json, {int ordre = 0}) {
    final variablesJson = (json['variables'] as List?) ?? const [];
    final relaisJson = (json['relais'] as List?) ?? const [];
    final briquesJson = (json['briques'] as List?) ?? const [];
    return FeuilleExcelModel(
      ordre: ordre,
      nomFeuille: json['nom_feuille'] as String? ?? '',
      gabarit: _gabaritFromString(json['gabarit'] as String?),
      nomTableEch0: json['nom_table_ech0'] as String?,
      variables: variablesJson
          .asMap()
          .entries
          .map((entry) => VariableExcelModel.fromJson(Map<String, Object?>.from(entry.value as Map)))
          .toList(growable: false),
      relais: relaisJson.map((item) => RelaisExcelModel.fromJson(Map<String, Object?>.from(item as Map))).toList(growable: false),
      briques: briquesJson.map((item) => BriqueAlgorithmeModel.fromJson(Map<String, Object?>.from(item as Map))).toList(growable: false),
    );
  }
}
