/// Portée d'une variable : une valeur par point mesuré, ou une valeur
/// unique par échantillon. Détermine si elle vit dans une colonne de
/// Tableau structuré (point) ou une cellule/colonne répétée (echantillon).
enum PorteeVariable { point, echantillon }

/// Origine d'une variable : mesurée directement (colonne vide à l'import)
/// ou calculée (formule capturée telle quelle depuis l'Échantillon Zéro).
enum OrigineVariable { brute, calculee }

PorteeVariable _porteeFromString(String? value) {
  return PorteeVariable.values.firstWhere(
    (item) => item.name == value,
    orElse: () => PorteeVariable.point,
  );
}

OrigineVariable _origineFromString(String? value) {
  return OrigineVariable.values.firstWhere(
    (item) => item.name == value,
    orElse: () => OrigineVariable.brute,
  );
}

class VariableExcelModel {
  const VariableExcelModel({
    this.id,
    this.feuilleId,
    required this.offsetLigne,
    required this.offsetColonne,
    required this.nomTechnique,
    required this.portee,
    required this.origine,
    this.formule,
  });

  final int? id;
  final int? feuilleId;

  /// Position de la cellule d'en-tête/formule de cette variable, RELATIVE
  /// au coin supérieur gauche du rectangle bloc-type dessiné par le
  /// technicien dans la grille libre. Remplace l'ancien `ordre` (position
  /// 1D dont le sens dépendait implicitement du gabarit) — ici la position
  /// est explicite et vaut pour n'importe quelle disposition interne du
  /// bloc, pas seulement une répétition sur un seul axe.
  final int offsetLigne;
  final int offsetColonne;

  /// Identifiant stable utilisé dans les Tableaux structurés Excel
  /// (ex. "Elong_mm", "Section_mm2") — jamais une adresse de cellule.
  final String nomTechnique;
  final PorteeVariable portee;
  final OrigineVariable origine;

  /// Texte exact de la formule Excel tel que tapé par le technicien dans
  /// le fichier Échantillon Zéro (ex. "=[@Elong_mm]/[@L0_mm]"). Jamais
  /// traduit, jamais réinterprété — null si origine == brute.
  final String? formule;

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'feuille_id': feuilleId,
      'offset_ligne': offsetLigne,
      'offset_colonne': offsetColonne,
      'nom_technique': nomTechnique,
      'portee': portee.name,
      'origine': origine.name,
      'formule': formule,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  factory VariableExcelModel.fromMap(Map<String, Object?> map) {
    return VariableExcelModel(
      id: (map['id'] as num?)?.toInt(),
      feuilleId: (map['feuille_id'] as num?)?.toInt(),
      offsetLigne: (map['offset_ligne'] as num?)?.toInt() ?? 0,
      offsetColonne: (map['offset_colonne'] as num?)?.toInt() ?? 0,
      nomTechnique: map['nom_technique'] as String? ?? '',
      portee: _porteeFromString(map['portee'] as String?),
      origine: _origineFromString(map['origine'] as String?),
      formule: map['formule'] as String?,
    );
  }

  VariableExcelModel copyWith({
    int? id,
    int? feuilleId,
    int? offsetLigne,
    int? offsetColonne,
    String? nomTechnique,
    PorteeVariable? portee,
    OrigineVariable? origine,
    String? formule,
    bool clearFormule = false,
  }) {
    return VariableExcelModel(
      id: id ?? this.id,
      feuilleId: feuilleId ?? this.feuilleId,
      offsetLigne: offsetLigne ?? this.offsetLigne,
      offsetColonne: offsetColonne ?? this.offsetColonne,
      nomTechnique: nomTechnique ?? this.nomTechnique,
      portee: portee ?? this.portee,
      origine: origine ?? this.origine,
      formule: clearFormule ? null : (formule ?? this.formule),
    );
  }

  /// Contrat sémantique envoyé au moteur Python — pas d'id ni de clé
  /// étrangère SQL, uniquement ce qui définit la variable.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'offset_ligne': offsetLigne,
      'offset_colonne': offsetColonne,
      'nom_technique': nomTechnique,
      'portee': portee.name,
      'origine': origine.name,
      'formule': formule,
    };
  }

  factory VariableExcelModel.fromJson(Map<String, Object?> json) {
    return VariableExcelModel(
      offsetLigne: (json['offset_ligne'] as num?)?.toInt() ?? 0,
      offsetColonne: (json['offset_colonne'] as num?)?.toInt() ?? 0,
      nomTechnique: json['nom_technique'] as String? ?? '',
      portee: _porteeFromString(json['portee'] as String?),
      origine: _origineFromString(json['origine'] as String?),
      formule: json['formule'] as String?,
    );
  }
}
