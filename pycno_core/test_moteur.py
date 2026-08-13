"""
Test rapide avec des données plausibles, pour vérifier que le moteur
de calcul tourne correctement avant de brancher l'interface.
"""

from moteur_python.calculs.traction import TractionCalculateur
from moteur_python.modeles.models import (
    ConditionsAmbiantes,
    Echantillon,
    FamilleMateriau,
    Gamme,
    Materiau,
    Norme,
    PointCourbe,
)

materiau = Materiau(
    nom_usage="Plaque composite fibre de verre",
    code_interne="CMP-2026-014",
    famille=FamilleMateriau.COMPOSITE,
)

norme = Norme(
    code="ISO 527-4",
    designation="Traction - composites renforcés fibres",
    seuil_resistance_min_mpa=150.0,
)

conditions = ConditionsAmbiantes(
    temperature_celsius=23.0,
    humidite_pourcent=50.0,
    duree_conditionnement_heures=24.0,
)

# Un échantillon avec courbe complète (pour tester le module d'Young)
ech1 = Echantillon(
    identifiant="ECH-01",
    longueur_initiale_mm=150.0,
    largeur_mm=25.0,
    epaisseur_mm=4.0,
    force_rupture_newton=18000.0,
    deplacement_rupture_mm=3.2,
    points_courbe=[
        PointCourbe(force_newton=2000, deplacement_mm=0.3),
        PointCourbe(force_newton=4000, deplacement_mm=0.6),
        PointCourbe(force_newton=6000, deplacement_mm=0.9),
        PointCourbe(force_newton=8000, deplacement_mm=1.2),
    ],
)

# Un échantillon avec seulement les valeurs de rupture (fiche papier simple)
ech2 = Echantillon(
    identifiant="ECH-02",
    longueur_initiale_mm=150.0,
    largeur_mm=25.0,
    epaisseur_mm=4.0,
    force_rupture_newton=17500.0,
    deplacement_rupture_mm=3.0,
)

gamme = Gamme(
    materiau=materiau,
    norme=norme,
    conditions=conditions,
    echantillons=[ech1, ech2],
)

resultat = TractionCalculateur().calculer(gamme)

print(f"Matériau        : {resultat.gamme.materiau.nom_usage}")
print(f"Norme           : {resultat.gamme.norme.code}")
print(f"Résistance moy. : {resultat.resistance_moyenne_mpa:.2f} MPa")
print(f"Écart-type      : {resultat.ecart_type_mpa:.2f} MPa")
print(f"Module d'Young  : {resultat.module_young_moyen_mpa:.1f} MPa" if resultat.module_young_moyen_mpa else "Module d'Young  : non calculé (pas de courbe)")
print(f"Écart-type Mod  : {resultat.ecart_type_module_young_mpa:.2f} MPa" if resultat.ecart_type_module_young_mpa is not None else "Écart-type Mod  : N/A")
print(f"Déformation moy : {resultat.deformation_moyenne_pourcent:.2f}%" if resultat.deformation_moyenne_pourcent is not None else "Déformation moy : N/A")
print(f"Écart-type Def  : {resultat.ecart_type_deformation_pourcent:.2f}%" if resultat.ecart_type_deformation_pourcent is not None else "Écart-type Def  : N/A")
print(f"Statut          : {resultat.statut.value}")
print()
for r in resultat.resultats_echantillons:
    module_str = f"{r.module_young_mpa:.1f} MPa" if r.module_young_mpa else "N/A"
    print(f"  {r.identifiant} : sigma_rupture={r.contrainte_rupture_mpa:.2f} MPa, "
          f"deformation={r.deformation_rupture_pourcent:.2f}%, module={module_str}")
