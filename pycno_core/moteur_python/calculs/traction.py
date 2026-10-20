from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional, Tuple
import numpy as np

@dataclass
class TractionConfig:
    """Paramètres d'analyse ajustables dynamiquement sans toucher au code."""
    seuil_r2_min: float = 0.98         # Qualité minimale du fit linéaire (R²)
    offset_elasticite: float = 0.002    # Décalage conventionnel (0.2% par défaut)
    taille_fenetre_glissante: int = 15  # Nombre de points par segment de régression
    filtre_bruit_initial: float = 0.01  # Ignore le premier 1% de déformation (mise en charge)

@dataclass
class TractionResultats:
    """Structure de sortie pure, directement sérialisable en JSON/Dict."""
    module_young_E_MPa: Optional[float]
    resistance_mecanique_Rm_MPa: Optional[float]
    limite_elasticite_Rp02_MPa: Optional[float]
    allongement_rupture_A_pct: Optional[float]
    metadonnees: Dict[str, Any] = field(default_factory=dict)

class TractionCalculateur:
    """Moteur de calcul pur, agnostique à l'interface et à la provenance des données."""

    def __init__(self, config: Optional[TractionConfig] = None):
        self.config = config or TractionConfig()

    def analyser(
        self, 
        deplacement_mm: List[float], 
        force_N: List[float], 
        section_mm2: float, 
        longueur_initiale_mm: float
    ) -> TractionResultats:
        
        dep = np.array(deplacement_mm, dtype=float)
        frc = np.array(force_N, dtype=float)

        if len(dep) < self.config.taille_fenetre_glissante:
            raise ValueError("Jeu de données insuffisant pour le calcul.")

        # Conversion en contrainte (MPa) et déformation relative (sans unité)
        contrainte_MPa = frc / section_mm2
        deformation = dep / longueur_initiale_mm

        # 1. Extraction du Module d'Young (E)
        E, r2_max = self._calculer_module_young(deformation, contrainte_MPa)

        # 2. Résistance Maximale (Rm)
        Rm = float(np.max(contrainte_MPa))

        # 3. Limite d'Élasticité Conventionnelle (Rp0.2)
        Rp02 = self._calculer_rp02(deformation, contrainte_MPa, E) if E else None

        # 4. Allongement à la rupture (A%)
        A_pct = float(deformation[-1] * 100)

        return TractionResultats(
            module_young_E_MPa=round(E, 2) if E else None,
            resistance_mecanique_Rm_MPa=round(Rm, 2),
            limite_elasticite_Rp02_MPa=round(Rp02, 2) if Rp02 else None,
            allongement_rupture_A_pct=round(A_pct, 2),
            metadonnees={
                "r2_regression": round(r2_max, 4),
                "nb_points_analyses": len(dep),
                "offset_utilise": self.config.offset_elasticite
            }
        )

    def _calculer_module_young(self, defo: np.ndarray, cont: np.ndarray) -> Tuple[Optional[float], float]:
        """Détection de la pente maximale linéaire par régression glissante."""
        n = len(defo)
        w = self.config.taille_fenetre_glissante
        idx_debut = int(n * self.config.filtre_bruit_initial)
        
        meilleure_pente = None
        meilleur_r2 = 0.0

        for i in range(idx_debut, n - w):
            x_sub = defo[i : i + w]
            y_sub = cont[i : i + w]

            # Régression linéaire : y = E * x + b
            pente, intercept = np.polyfit(x_sub, y_sub, 1)
            
            # Calcul du coefficient de détermination R²
            y_pred = pente * x_sub + intercept
            ss_res = np.sum((y_sub - y_pred) ** 2)
            ss_tot = np.sum((y_sub - np.mean(y_sub)) ** 2)
            r2 = 1 - (ss_res / (ss_tot + 1e-9))

            if r2 > meilleur_r2 and pente > 0:
                meilleur_r2 = r2
                meilleure_pente = pente

        if meilleur_r2 >= self.config.seuil_r2_min:
            return meilleure_pente, meilleur_r2
        return meilleure_pente, meilleur_r2

    def _calculer_rp02(self, defo: np.ndarray, cont: np.ndarray, E: float) -> Optional[float]:
        """Interception de la courbe avec la droite décalée de offset_elasticite (0.2%)."""
        droite_offset = E * (defo - self.config.offset_elasticite)
        
        # Trouver le premier point où la contrainte réelle passe sous la droite décalée
        ecart = cont - droite_offset
        indices_croisement = np.where(np.diff(np.sign(ecart)))[0]

        if len(indices_croisement) > 0:
            idx = indices_croisement[0]
            return float(cont[idx])
        return None


class GammeCalculateur:
    """Gère le calcul en lot de plusieurs éprouvettes et leurs agrégats statistiques."""

    def __init__(self, config: Optional[TractionConfig] = None):
        self.calculateur_individuel = TractionCalculateur(config)

    def analyser_gamme(self, echantillons: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        :param echantillons: Liste de dictionnaires contenant pour chaque éprouvette:
               {"nom": "E1", "deplacement": [...], "force": [...], "section_mm2": 10.0, "longueur_mm": 50.0}
        """
        resultats_eprouvettes = []
        
        for ech in echantillons:
            res = self.calculateur_individuel.analyser(
                deplacement_mm=ech["deplacement"],
                force_N=ech["force"],
                section_mm2=ech["section_mm2"],
                longueur_initiale_mm=ech["longueur_mm"]
            )
            resultats_eprouvettes.append({"nom": ech.get("nom", "Inconnu"), "resultats": res})

        # Extraction des séries pour agrégation
        valeurs_E = [r["resultats"].module_young_E_MPa for r in resultats_eprouvettes if r["resultats"].module_young_E_MPa is not None]
        valeurs_Rm = [r["resultats"].resistance_mecanique_Rm_MPa for r in resultats_eprouvettes if r["resultats"].resistance_mecanique_Rm_MPa is not None]
        valeurs_Rp02 = [r["resultats"].limite_elasticite_Rp02_MPa for r in resultats_eprouvettes if r["resultats"].limite_elasticite_Rp02_MPa is not None]
        valeurs_A = [r["resultats"].allongement_rupture_A_pct for r in resultats_eprouvettes if r["resultats"].allongement_rupture_A_pct is not None]

        def calculer_stats(serie: List[float]) -> Dict[str, Optional[float]]:
            if not serie:
                return {"moyenne": None, "ecart_type": None, "min": None, "max": None}
            arr = np.array(serie)
            return {
                "moyenne": round(float(np.mean(arr)), 2),
                "ecart_type": round(float(np.std(arr, ddof=1)), 2) if len(arr) > 1 else 0.0,
                "min": round(float(np.min(arr)), 2),
                "max": round(float(np.max(arr)), 2)
            }

        return {
            "eprouvettes": resultats_eprouvettes,
            "agregats": {
                "E": calculer_stats(valeurs_E),
                "Rm": calculer_stats(valeurs_Rm),
                "Rp02": calculer_stats(valeurs_Rp02),
                "A%": calculer_stats(valeurs_A)
            }
        }