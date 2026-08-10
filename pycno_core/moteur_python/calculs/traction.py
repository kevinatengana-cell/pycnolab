"""
Moteur de calcul pour l'essai de traction.

Formules :
- Contrainte (MPa)   : sigma = F / A        (Force en N, Section en mm² -> MPa directement)
- Déformation (%)    : epsilon = (dL / L0) * 100
- Module d'Young     : voir moteur_python.calculs.tools.regression
                       (brique partagée, réutilisable par compression,
                       flexion, etc. - même méthode de calcul).
"""

import statistics

from moteur_python.calculs.base import MoteurCalcul
from moteur_python.calculs.outils.regression import module_depuis_courbe
from moteur_python.calculs.outils.energie import energie_absorbee
from moteur_python.calculs.outils.elasticite import limite_elastique_offset
from moteur_python.calculs.outils.statistiques import moyenne_et_ecart_type
from moteur_python.modeles.models import (
    Echantillon,
    Gamme,
    ResultatEchantillon,
    ResultatGamme,
    StatutConformite,
)


class TractionCalculateur(MoteurCalcul):

    def _calculer_echantillon(self, ech: Echantillon, calculs_demandes: list[str]) -> ResultatEchantillon:
        section = ech.section_mm2()

        if ech.force_rupture_newton is None or ech.deplacement_rupture_mm is None:
            raise ValueError(
                f"Échantillon {ech.identifiant} : force et déplacement à "
                "rupture obligatoires."
            )

        contrainte_rupture = ech.force_rupture_newton / section
        deformation_rupture = (ech.deplacement_rupture_mm / ech.longueur_initiale_mm) * 100

        module_young = module_depuis_courbe(
            points_courbe=ech.points_courbe,
            section_mm2=section,
            longueur_mm=ech.longueur_initiale_mm,
            contrainte_rupture_mpa=contrainte_rupture,
        )

        energie_rupture = None
        if "energie_rupture" in calculs_demandes:
            points_bruts = [(p.force_newton, p.deplacement_mm) for p in ech.points_courbe]
            energie_rupture = energie_absorbee(points_bruts) / 1000.0 if points_bruts else None

        limite_elastique = None
        if "limite_elastique" in calculs_demandes and module_young is not None:
            limite_elastique = limite_elastique_offset(
                points_courbe=ech.points_courbe,
                section_mm2=section,
                longueur_mm=ech.longueur_initiale_mm,
                module_young_mpa=module_young
            )

        return ResultatEchantillon(
            identifiant=ech.identifiant,
            contrainte_rupture_mpa=contrainte_rupture,
            deformation_rupture_pourcent=deformation_rupture,
            module_young_mpa=module_young,
            energie_rupture_joules=energie_rupture,
            limite_elastique_mpa=limite_elastique,
        )

    def calculer(self, gamme: Gamme) -> ResultatGamme:
        if not gamme.echantillons:
            raise ValueError("La gamme ne contient aucun échantillon.")

        resultats = [self._calculer_echantillon(e, gamme.calculs_demandes) for e in gamme.echantillons]

        contraintes = [r.contrainte_rupture_mpa for r in resultats]
        resistance_moyenne = statistics.mean(contraintes)
        ecart_type = statistics.stdev(contraintes) if len(contraintes) > 1 else 0.0

        modules = [r.module_young_mpa for r in resultats if r.module_young_mpa is not None]
        module_moyen, ecart_type_module_young = moyenne_et_ecart_type(modules)
        if not modules:
            module_moyen = None
            ecart_type_module_young = None
        
        deformations = [r.deformation_rupture_pourcent for r in resultats if r.deformation_rupture_pourcent is not None]
        deformation_moyenne, ecart_type_deformation = moyenne_et_ecart_type(deformations)

        energies = [r.energie_rupture_joules for r in resultats if r.energie_rupture_joules is not None]
        energie_moyenne = statistics.mean(energies) if energies else None
        
        limites = [r.limite_elastique_mpa for r in resultats if r.limite_elastique_mpa is not None]
        limite_moyenne = statistics.mean(limites) if limites else None

        seuil = gamme.norme.seuil_resistance_min_mpa
        if seuil is None:
            statut = StatutConformite.NON_EVALUE
        elif resistance_moyenne >= seuil:
            statut = StatutConformite.CONFORME
        else:
            statut = StatutConformite.NON_CONFORME

        return ResultatGamme(
            gamme=gamme,
            resultats_echantillons=resultats,
            resistance_moyenne_mpa=resistance_moyenne,
            ecart_type_mpa=ecart_type,
            module_young_moyen_mpa=module_moyen,
            energie_rupture_moyenne_joules=energie_moyenne,
            limite_elastique_moyenne_mpa=limite_moyenne,
            statut=statut,
        )