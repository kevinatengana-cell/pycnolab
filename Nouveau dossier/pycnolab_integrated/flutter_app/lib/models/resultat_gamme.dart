// Modèles Dart pour CE QU'ON REÇOIT de l'API Python.
// fromJson() lit les clés renvoyées par ResultatGammeSchema avec gestion du null-safety.

class ResultatEchantillon {
  final String identifiant;
  final double contrainteRuptureMpa;
  final double deformationRupturePourcent;
  final double? moduleYoungMpa;
  final double? sectionMm2;
  final double? forceMaxNewton;
  final double? energieRuptureJoule;
  final double? limiteElastiqueMpa;

  ResultatEchantillon({
    required this.identifiant,
    required this.contrainteRuptureMpa,
    required this.deformationRupturePourcent,
    this.moduleYoungMpa,
    this.sectionMm2,
    this.forceMaxNewton,
    this.energieRuptureJoule,
    this.limiteElastiqueMpa,
  });

  factory ResultatEchantillon.fromJson(Map<String, dynamic> json) {
    return ResultatEchantillon(
      identifiant: (json["identifiant"] as String?) ?? 'Inconnu',
      contrainteRuptureMpa: (json["contrainte_rupture_mpa"] as num?)?.toDouble() ?? 0.0,
      deformationRupturePourcent: (json["deformation_rupture_pourcent"] as num?)?.toDouble() ?? 0.0,
      moduleYoungMpa: (json["module_young_mpa"] as num?)?.toDouble(),
      sectionMm2: (json["section_mm2"] as num?)?.toDouble(),
      forceMaxNewton: (json["force_max_newton"] as num?)?.toDouble(),
      energieRuptureJoule: (json["energie_rupture_joule"] as num?)?.toDouble(),
      limiteElastiqueMpa: (json["limite_elastique_mpa"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identifiant': identifiant,
      'contrainte_rupture_mpa': contrainteRuptureMpa,
      'deformation_rupture_pourcent': deformationRupturePourcent,
      'module_young_mpa': moduleYoungMpa,
      'section_mm2': sectionMm2,
      'force_max_newton': forceMaxNewton,
      'energie_rupture_joule': energieRuptureJoule,
      'limite_elastique_mpa': limiteElastiqueMpa,
    };
  }
}

class ResultatGamme {
  final String materiauNom;
  final String normeCode;
  final DateTime horodatage;
  final List<ResultatEchantillon> resultatsEchantillons;
  final double resistanceMoyenneMpa;
  final double ecartTypeMpa;
  final double? moduleYoungMoyenMpa;
  final String statut; // "conforme" | "non_conforme" | "non_evalue"
  final double? deformationMoyennePourcent;
  final double? ecartTypeDeformationPourcent;
  final double? ecartTypeModuleYoungMpa;

  ResultatGamme({
    required this.materiauNom,
    required this.normeCode,
    required this.horodatage,
    required this.resultatsEchantillons,
    required this.resistanceMoyenneMpa,
    required this.ecartTypeMpa,
    this.moduleYoungMoyenMpa,
    required this.statut,
    this.deformationMoyennePourcent,
    this.ecartTypeDeformationPourcent,
    this.ecartTypeModuleYoungMpa,
  });

  factory ResultatGamme.fromJson(Map<String, dynamic> json) {
    return ResultatGamme(
      materiauNom: (json["materiau_nom"] as String?) ?? 'Inconnu',
      normeCode: (json["norme_code"] as String?) ?? 'Non spécifiée',
      horodatage: json["horodatage"] != null
          ? DateTime.tryParse(json["horodatage"].toString()) ?? DateTime.now()
          : DateTime.now(),
      resultatsEchantillons: (json["resultats_echantillons"] as List<dynamic>?)
              ?.map((e) => ResultatEchantillon.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      resistanceMoyenneMpa: (json["resistance_moyenne_mpa"] as num?)?.toDouble() ?? 0.0,
      ecartTypeMpa: (json["ecart_type_mpa"] as num?)?.toDouble() ?? 0.0,
      moduleYoungMoyenMpa: (json["module_young_moyen_mpa"] as num?)?.toDouble(),
      statut: (json["statut"] as String?) ?? 'non_evalue',
      deformationMoyennePourcent: (json["deformation_moyenne_pourcent"] as num?)?.toDouble(),
      ecartTypeDeformationPourcent: (json["ecart_type_deformation_pourcent"] as num?)?.toDouble(),
      ecartTypeModuleYoungMpa: (json["ecart_type_module_young_mpa"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'materiau_nom': materiauNom,
      'norme_code': normeCode,
      'horodatage': horodatage.toIso8601String(),
      'statut': statut,
      'resistance_moyenne_mpa': resistanceMoyenneMpa,
      'ecart_type_mpa': ecartTypeMpa,
      'module_young_moyen_mpa': moduleYoungMoyenMpa,
      'deformation_moyenne_pourcent': deformationMoyennePourcent,
      'ecart_type_deformation_pourcent': ecartTypeDeformationPourcent,
      'ecart_type_module_young_mpa': ecartTypeModuleYoungMpa,
      'statistiques': {
        'sigma_moyenne': resistanceMoyenneMpa,
        'sigma_ecart_type': ecartTypeMpa,
        'deformation_moyenne': deformationMoyennePourcent,
      },
      'resultats_echantillons': resultatsEchantillons.map((e) => e.toJson()).toList(),
    };
  }
}