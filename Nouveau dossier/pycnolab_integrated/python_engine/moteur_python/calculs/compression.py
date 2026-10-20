"""
Moteur de calcul pour l'essai de compression.

Note physique importante : les formules de contrainte/déformation en
compression sont IDENTIQUES à celles en traction (sigma = F/A,
epsilon = dL/L0) - seule la convention de signe change habituellement
(compression = valeurs négatives dans certaines normes), mais pour un
usage labo pratique où on mesure des valeurs absolues, la structure de
calcul est la même. C'est précisément pour ça que ce fichier est presque
identique à traction.py : la preuve que les briques (outils/) sont bien
réutilisables d'un essai à l'autre, comme prévu dès le départ.
"""

import statistics

from moteur_python.calculs.base import MoteurCalcul
from moteur_python.calculs.outils.regression import module_depuis_courbe
from moteur_python.calculs.outils.energie import energie_absorbee
from moteur_python.calculs.outils.statistiques import moyenne_et_ecart_type
from moteur_python.calculs.outils.extremes import valeur_maximale
from moteur_python.modeles.models import (
    Echantillon,
    Gamme,
    ResultatEchantillon,
    ResultatGamme,
    StatutConformite,
)


class CompressionCalculateur(MoteurCalcul):

    def _calculer_echantillon(self, ech: Echantillon, calculs_demandes: list[str]) -> ResultatEchantillon:
        section = ech.section_mm2()

        if ech.force_rupture_newton is None and not ech.points_courbe:
            raise ValueError(
                f"Échantillon {ech.identifiant} : force à rupture ou points de courbe obligatoires."
            )

        forces_courbe = [p.force_newton for p in ech.points_courbe]
        force_max = valeur_maximale(forces_courbe) if forces_courbe else ech.force_rupture_newton
        force_rupture = ech.force_rupture_newton if ech.force_rupture_newton is not None else force_max
        contrainte_rupture = force_rupture / section

        deformation_rupture = 0.0
        if ech.deplacement_rupture_mm is not None:
            deformation_rupture = (ech.deplacement_rupture_mm / ech.longueur_initiale_mm) * 100

        module_compression = module_depuis_courbe(
            points_courbe=ech.points_courbe,
            section_mm2=section,
            longueur_mm=ech.longueur_initiale_mm,
            contrainte_rupture_mpa=contrainte_rupture,
        )

        energie = None
        if "energie_rupture" in calculs_demandes and ech.points_courbe:
            points_bruts = [(p.force_newton, p.deplacement_mm) for p in ech.points_courbe]
            energie = energie_absorbee(points_bruts) / 1000.0

        return ResultatEchantillon(
            identifiant=ech.identifiant,
            contrainte_rupture_mpa=contrainte_rupture,
            deformation_rupture_pourcent=deformation_rupture,
            module_young_mpa=module_compression,
            force_max_newton=force_max,
            energie_rupture_joules=energie,
        )

    def calculer(self, gamme: Gamme) -> ResultatGamme:
        if not gamme.echantillons:
            raise ValueError("La gamme ne contient aucun échantillon.")

        resultats = [self._calculer_echantillon(e, gamme.calculs_demandes) for e in gamme.echantillons]

        contraintes = [r.contrainte_rupture_mpa for r in resultats]
        resistance_moyenne = statistics.mean(contraintes)
        ecart_type = statistics.stdev(contraintes) if len(contraintes) > 1 else 0.0

        modules = [r.module_young_mpa for r in resultats if r.module_young_mpa is not None]
        module_moyen, ecart_type_module = moyenne_et_ecart_type(modules)

        deformations = [r.deformation_rupture_pourcent for r in resultats]
        deformation_moyenne, ecart_type_deformation = moyenne_et_ecart_type(deformations)

        seuil_resistance = gamme.norme.seuil_resistance_min_mpa
        seuil_allongement = gamme.norme.seuil_allongement_min_pourcent
        if seuil_resistance is None and seuil_allongement is None:
            statut = StatutConformite.NON_EVALUE
        elif (
            (seuil_resistance is None or resistance_moyenne >= seuil_resistance)
            and (
                seuil_allongement is None
                or (deformation_moyenne is not None and deformation_moyenne >= seuil_allongement)
            )
        ):
            statut = StatutConformite.CONFORME
        else:
            statut = StatutConformite.NON_CONFORME

        return ResultatGamme(
            gamme=gamme,
            resultats_echantillons=resultats,
            resistance_moyenne_mpa=resistance_moyenne,
            ecart_type_mpa=ecart_type,
            module_young_moyen_mpa=module_moyen if modules else None,
            statut=statut,
            deformation_moyenne_pourcent=deformation_moyenne,
            ecart_type_deformation_pourcent=ecart_type_deformation,
            ecart_type_module_young_mpa=ecart_type_module if modules else None,
        )
