import json
import statistics
import math
from typing import Any

from simpleeval import simple_eval

from moteur_python.calculs.base import MoteurCalcul
from moteur_python.calculs.outils.regression import module_depuis_courbe
from moteur_python.calculs.outils.energie import energie_absorbee
from moteur_python.calculs.outils.elasticite import limite_elastique_offset
from moteur_python.calculs.outils.statistiques import moyenne_et_ecart_type
from moteur_python.calculs.outils.extremes import valeur_maximale
from moteur_python.modeles.models import (
    Echantillon,
    Gamme,
    ResultatEchantillon,
    ResultatGamme,
    StatutConformite,
)


class MoteurProtocole(MoteurCalcul):
    """
    Moteur de calcul dynamique qui exécute un protocole personnalisé (JSON)
    sur des données d'essais brutes.
    """
    def __init__(self, protocole_dict: dict[str, Any]):
        self.protocole = protocole_dict
        self.variables = self.protocole.get("variables", [])
        self.calcul = self.protocole.get("calcul", {})
        self.formule_str = self.calcul.get("formule", "")

    def _calculer_echantillon(self, ech: Echantillon, calculs_demandes: list[str]) -> ResultatEchantillon:
        section = ech.section_mm2()

        forces_courbe = [p.force_newton for p in ech.points_courbe]
        if forces_courbe:
            force_max = valeur_maximale(forces_courbe)
        else:
            force_max = ech.force_rupture_newton or 0.0

        force_rupture = ech.force_rupture_newton if ech.force_rupture_newton is not None else force_max
        deplacement = ech.deplacement_rupture_mm or 0.0
        longueur = ech.longueur_initiale_mm

        # 1. Construction du contexte d'évaluation
        context = {
            "pi": math.pi,
            "e": math.e,
        }
        
        # Valeurs par défaut déclarées dans le protocole
        for var in self.variables:
            key = var.get("key")
            if key:
                context[key] = var.get("valeur_defaut", 0.0)

        # Mapping des variables physiques réelles
        mapping = {
            "force_f": force_rupture,
            "force_max": force_max,
            "section_a": section,
            "section": section,
            "l0": longueur,
            "longueur": longueur,
            "deplacement": deplacement,
            "depl": deplacement,
        }
        
        for k, v in mapping.items():
            if k in context:
                context[k] = v

        # 2. Évaluation sandbox de la formule
        try:
            formule_eval = self.formule_str.replace("^", "**")
            functions = {
                "sqrt": math.sqrt,
                "abs": abs,
                "min": min,
                "max": max,
            }
            contrainte_custom = float(simple_eval(formule_eval, names=context, functions=functions))
        except Exception as e:
            raise ValueError(f"Erreur d'évaluation sur {ech.identifiant} ('{self.formule_str}'): {e}")

        # 3. Grandeurs complémentaires
        deformation_rupture = 0.0
        if ech.deplacement_rupture_mm is not None and ech.longueur_initiale_mm > 0:
            deformation_rupture = (ech.deplacement_rupture_mm / ech.longueur_initiale_mm) * 100.0

        module_young = module_depuis_courbe(
            points_courbe=ech.points_courbe,
            section_mm2=section,
            longueur_mm=ech.longueur_initiale_mm,
            contrainte_rupture_mpa=contrainte_custom,
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
                module_young_mpa=module_young,
            )

        return ResultatEchantillon(
            identifiant=ech.identifiant,
            contrainte_rupture_mpa=contrainte_custom,
            deformation_rupture_pourcent=deformation_rupture,
            module_young_mpa=module_young,
            force_max_newton=force_max,
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

        deformations = [r.deformation_rupture_pourcent for r in resultats if r.deformation_rupture_pourcent is not None]
        deformation_moyenne, ecart_type_deformation = moyenne_et_ecart_type(deformations)

        energies = [r.energie_rupture_joules for r in resultats if r.energie_rupture_joules is not None]
        energie_moyenne = statistics.mean(energies) if energies else None
        
        limites = [r.limite_elastique_mpa for r in resultats if r.limite_elastique_mpa is not None]
        limite_moyenne = statistics.mean(limites) if limites else None

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
            energie_rupture_moyenne_joules=energie_moyenne,
            limite_elastique_moyenne_mpa=limite_moyenne,
            statut=statut,
            deformation_moyenne_pourcent=deformation_moyenne,
            ecart_type_deformation_pourcent=ecart_type_deformation,
            ecart_type_module_young_mpa=ecart_type_module_young if modules else None,
        )