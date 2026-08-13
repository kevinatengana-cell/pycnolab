"""
Modèles de données du domaine métier.
Architecture pensée pour la modularité : ajouter un nouvel essai (compression,
flexion...) ne nécessite pas de modifier ces classes, seulement d'ajouter
un nouveau moteur de calcul (voir calculs/).
"""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class FamilleMateriau(str, Enum):
    TEXTILE = "textile"
    BOIS = "bois"
    COMPOSITE = "composite"
    PLASTIQUE = "plastique"
    BIOMASSE = "biomasse"
    METAL = "metal"
    AUTRE = "autre"


class StatutConformite(str, Enum):
    CONFORME = "conforme"
    NON_CONFORME = "non_conforme"
    NON_EVALUE = "non_evalue"  # ex: seuil non défini pour cette norme


@dataclass
class ConditionsAmbiantes:
    """Conditionnement de l'essai."""
    temperature_celsius: Optional[float] = None
    humidite_pourcent: Optional[float] = None
    duree_conditionnement_heures: Optional[float] = None


@dataclass
class Materiau:
    nom_usage: str
    code_interne: str
    famille: FamilleMateriau = FamilleMateriau.AUTRE


@dataclass
class PointCourbe:
    """Un point mesuré force/déplacement, si la fiche papier en fournit plusieurs.
    Optionnel : certaines fiches ne donnent que les valeurs à rupture."""
    force_newton: float
    deplacement_mm: float


@dataclass
class Echantillon:
    """
    Un échantillon individuel au sein d'une gamme.
    Dimensions génériques pour couvrir les différentes familles de matériaux
    (section rectangulaire ou circulaire selon le matériau testé).
    """
    identifiant: str
    longueur_initiale_mm: float

    # Section rectangulaire (textile, bois, composite, plastique...)
    largeur_mm: Optional[float] = None
    epaisseur_mm: Optional[float] = None

    # Section circulaire (métaux, certains composites, fibres naturelles).
    diametres_mm: list[float] = field(default_factory=list)

    # Données de rupture (toujours disponibles, même sans courbe complète)
    force_rupture_newton: Optional[float] = None
    deplacement_rupture_mm: Optional[float] = None

    # Courbe complète si disponible sur la fiche (pour calcul du module)
    points_courbe: list[PointCourbe] = field(default_factory=list)

    def section_mm2(self) -> float:
        """Calcule la section selon les dimensions renseignées."""
        if self.diametres_mm:
            from moteur_python.calculs.outils.geometrie import (
                diametre_moyen,
                section_circulaire,
            )
            return section_circulaire(diametre_moyen(self.diametres_mm))
        if self.largeur_mm and self.epaisseur_mm:
            from moteur_python.calculs.outils.geometrie import section_rectangulaire
            return section_rectangulaire(self.largeur_mm, self.epaisseur_mm)
        raise ValueError(
            f"Échantillon {self.identifiant} : dimensions insuffisantes "
            "pour calculer la section (fournir un ou plusieurs diamètres, "
            "OU largeur+épaisseur)."
        )


@dataclass
class Norme:
    code: str
    designation: str
    seuil_resistance_min_mpa: Optional[float] = None
    seuil_allongement_min_pourcent: Optional[float] = None


@dataclass
class Gamme:
    materiau: Materiau
    norme: Norme
    conditions: ConditionsAmbiantes
    echantillons: list[Echantillon] = field(default_factory=list)
    calculs_demandes: list[str] = field(default_factory=list)
    horodatage: datetime = field(default_factory=datetime.now)


@dataclass
class ResultatEchantillon:
    identifiant: str
    contrainte_rupture_mpa: float
    deformation_rupture_pourcent: float
    module_young_mpa: Optional[float]  # None si pas de courbe fournie
    force_max_newton: Optional[float] = None  # AJOUT : Force maximale en Newton
    energie_rupture_joules: Optional[float] = None
    limite_elastique_mpa: Optional[float] = None


@dataclass
class ResultatGamme:
    gamme: Gamme
    resultats_echantillons: list[ResultatEchantillon]
    resistance_moyenne_mpa: float
    ecart_type_mpa: float
    module_young_moyen_mpa: Optional[float]
    statut: StatutConformite
    energie_rupture_moyenne_joules: Optional[float] = None
    limite_elastique_moyenne_mpa: Optional[float] = None
    deformation_moyenne_pourcent: Optional[float] = None
    ecart_type_deformation_pourcent: Optional[float] = None
    ecart_type_module_young_mpa: Optional[float] = None