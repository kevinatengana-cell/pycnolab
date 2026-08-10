// Modèles Dart pour CE QU'ON REÇOIT de l'API Python.
// fromJson() lit les clés renvoyées par ResultatGammeSchema avec gestion du null-safety.

class ResultatEchantillon {
  final String identifiant;
  final double contrainteRuptureMpa;
  final double deformationRupturePourcent;
  final double? moduleYoungMpa;

  ResultatEchantillon({
    required this.identifiant,
    required this.contrainteRuptureMpa,
    required this.deformationRupturePourcent,
    this.moduleYoungMpa,
  });

  factory ResultatEchantillon.fromJson(Map<String, dynamic> json) {
    return ResultatEchantillon(
      identifiant: (json["identifiant"] as String?) ?? 'Inconnu',
      contrainteRuptureMpa: (json["contrainte_rupture_mpa"] as num?)?.toDouble() ?? 0.0,
      deformationRupturePourcent: (json["deformation_rupture_pourcent"] as num?)?.toDouble() ?? 0.0,
      moduleYoungMpa: (json["module_young_mpa"] as num?)?.toDouble(),
    );
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

  ResultatGamme({
    required this.materiauNom,
    required this.normeCode,
    required this.horodatage,
    required this.resultatsEchantillons,
    required this.resistanceMoyenneMpa,
    required this.ecartTypeMpa,
    this.moduleYoungMoyenMpa,
    required this.statut,
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
    );
  }
}