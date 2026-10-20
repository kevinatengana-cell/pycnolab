/// Fonctions d'agrégation supportées pour le récapitulatif. Restreint à un
/// ensemble fini connu du moteur de génération (pas une formule libre) —
/// le récapitulatif est toujours écrit par l'app avec de vraies références
/// de cellule au moment de la génération, jamais copié d'un fichier existant.
enum FonctionAgregat { moyenne, ecartType, minimum, maximum }

FonctionAgregat _fonctionFromString(String? value) {
  return FonctionAgregat.values.firstWhere(
    (item) => item.name == value,
    orElse: () => FonctionAgregat.moyenne,
  );
}

class RecapitulatifAgregatModel {
  const RecapitulatifAgregatModel({
    this.id,
    this.essaiId,
    required this.feuilleSource,
    required this.variableSource,
    required this.fonction,
  });

  final int? id;
  final int? essaiId;

  /// Nom de la feuille dont les échantillons sont agrégés (ex. "COROUI").
  final String feuilleSource;

  /// nom_technique de la variable à agréger (ex. "E_MPa").
  final String variableSource;
  final FonctionAgregat fonction;

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'essai_id': essaiId,
      'feuille_source': feuilleSource,
      'variable_source': variableSource,
      'fonction': fonction.name,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  factory RecapitulatifAgregatModel.fromMap(Map<String, Object?> map) {
    return RecapitulatifAgregatModel(
      id: (map['id'] as num?)?.toInt(),
      essaiId: (map['essai_id'] as num?)?.toInt(),
      feuilleSource: map['feuille_source'] as String? ?? '',
      variableSource: map['variable_source'] as String? ?? '',
      fonction: _fonctionFromString(map['fonction'] as String?),
    );
  }

  RecapitulatifAgregatModel copyWith({
    int? id,
    int? essaiId,
    String? feuilleSource,
    String? variableSource,
    FonctionAgregat? fonction,
  }) {
    return RecapitulatifAgregatModel(
      id: id ?? this.id,
      essaiId: essaiId ?? this.essaiId,
      feuilleSource: feuilleSource ?? this.feuilleSource,
      variableSource: variableSource ?? this.variableSource,
      fonction: fonction ?? this.fonction,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'feuille_source': feuilleSource,
      'variable_source': variableSource,
      'fonction': fonction.name,
    };
  }

  factory RecapitulatifAgregatModel.fromJson(Map<String, Object?> json) {
    return RecapitulatifAgregatModel(
      feuilleSource: json['feuille_source'] as String? ?? '',
      variableSource: json['variable_source'] as String? ?? '',
      fonction: _fonctionFromString(json['fonction'] as String?),
    );
  }
}
