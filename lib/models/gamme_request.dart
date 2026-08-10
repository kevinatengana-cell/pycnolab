// Modèles Dart pour CE QU'ON ENVOIE à l'API Python.
// Les noms de champs doivent correspondre exactement à schemas.py côté
// Python (FastAPI/Pydantic lit le JSON par nom de clé).

class MateriauRequest {
  final String nomUsage;
  final String codeInterne;
  final String famille; // "textile" | "bois" | "composite" | "plastique" | "biomasse" | "metal" | "autre"

  MateriauRequest({
    required this.nomUsage,
    required this.codeInterne,
    this.famille = "autre",
  });

  Map<String, dynamic> toJson() => {
        "nom_usage": nomUsage,
        "code_interne": codeInterne,
        "famille": famille,
      };
}

class NormeRequest {
  final String code;
  final String designation;
  final double? seuilResistanceMinMpa;
  final double? seuilAllongementMinPourcent;

  NormeRequest({
    required this.code,
    required this.designation,
    this.seuilResistanceMinMpa,
    this.seuilAllongementMinPourcent,
  });

  Map<String, dynamic> toJson() => {
        "code": code,
        "designation": designation,
        "seuil_resistance_min_mpa": seuilResistanceMinMpa,
        "seuil_allongement_min_pourcent": seuilAllongementMinPourcent,
      };
}

class ConditionsRequest {
  final double? temperatureCelsius;
  final double? humiditePourcent;
  final double? dureeConditionnementHeures;

  ConditionsRequest({
    this.temperatureCelsius,
    this.humiditePourcent,
    this.dureeConditionnementHeures,
  });

  Map<String, dynamic> toJson() => {
        "temperature_celsius": temperatureCelsius,
        "humidite_pourcent": humiditePourcent,
        "duree_conditionnement_heures": dureeConditionnementHeures,
      };
}

class PointCourbeRequest {
  final double forceNewton;
  final double deplacementMm;

  PointCourbeRequest({required this.forceNewton, required this.deplacementMm});

  Map<String, dynamic> toJson() => {
        "force_newton": forceNewton,
        "deplacement_mm": deplacementMm,
      };
}

class EchantillonRequest {
  final String identifiant;
  final double longueurInitialeMm;
  final double? largeurMm;
  final double? epaisseurMm;
  final double? diametreMm;
  final double? forceRuptureNewton;
  final double? deplacementRuptureMm;
  final List<PointCourbeRequest> pointsCourbe;

  EchantillonRequest({
    required this.identifiant,
    required this.longueurInitialeMm,
    this.largeurMm,
    this.epaisseurMm,
    this.diametreMm,
    this.forceRuptureNewton,
    this.deplacementRuptureMm,
    this.pointsCourbe = const [],
  });

  Map<String, dynamic> toJson() => {
        "identifiant": identifiant,
        "longueur_initiale_mm": longueurInitialeMm,
        "largeur_mm": largeurMm,
        "epaisseur_mm": epaisseurMm,
        "diametre_mm": diametreMm,
        "force_rupture_newton": forceRuptureNewton,
        "deplacement_rupture_mm": deplacementRuptureMm,
        "points_courbe": pointsCourbe.map((p) => p.toJson()).toList(),
        "parametres_extra": <String, double>{},
      };
}

class GammeRequest {
  final MateriauRequest materiau;
  final NormeRequest norme;
  final ConditionsRequest conditions;
  final List<EchantillonRequest> echantillons;
  final List<String> calculsDemandes;

  GammeRequest({
    required this.materiau,
    required this.norme,
    required this.conditions,
    required this.echantillons,
    this.calculsDemandes = const [],
  });

  Map<String, dynamic> toJson() => {
        "materiau": materiau.toJson(),
        "norme": norme.toJson(),
        "conditions": conditions.toJson(),
        "echantillons": echantillons.map((e) => e.toJson()).toList(),
        "calculs_demandes": calculsDemandes,
      };
}
