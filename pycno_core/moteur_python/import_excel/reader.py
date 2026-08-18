"""
Lecture du fichier Excel d'import - format STRICT à 3 feuilles
(INFO / DIAMETRES / COURBE).

Ancienne approche abandonnée : ce fichier tentait auparavant de deviner
la structure de n'importe quel Excel par heuristique (regex sur "ech",
position des nombres sur la ligne). Trop fragile - une seule inversion
de colonnes ou un fichier légèrement différent suffisait à casser la
lecture silencieusement, avec des résultats faux plutôt qu'une erreur
claire. Remplacé par un format imposé, documenté, avec des noms de
colonnes exacts (voir modele_import_traction.xlsx).

Structure attendue, 3 feuilles :

  INFO        : 2 colonnes (CHAMP, VALEUR), une ligne par métadonnée.
                Champs reconnus : Projet, Opérateur, Matériau (famille),
                Code interne matériau, Norme, Seuil résistance min (MPa),
                Longueur initiale L0 (mm), Température (°C), Humidité (%)

  DIAMETRES   : une ligne par échantillon.
                Colonnes : ID Échantillon | D1 (mm) | D2 (mm) | D3 (mm)

  COURBE      : une ligne par point de mesure (format long - le nombre
                de points peut varier librement d'un échantillon à
                l'autre).
                Colonnes : ID Échantillon | Force (N) | Déplacement (mm)
"""

import os
import math
import re
from typing import Any, Optional

import pandas as pd


def _vers_nombre(valeur: Any) -> Optional[float]:
    """Convertit une cellule en nombre, en tolérant la virgule décimale
    française (0,205 -> 0.205)."""
    if valeur is None or (isinstance(valeur, float) and pd.isna(valeur)):
        return None
    if isinstance(valeur, (int, float)):
        return float(valeur)
    try:
        return float(str(valeur).strip().replace(",", "."))
    except (ValueError, TypeError):
        return None


def _normaliser_chaine(texte: Any) -> str:
    """Met en majuscules et retire espaces/accents de base pour la comparaison."""
    if pd.isna(texte) or texte is None:
        return ""
    s = str(texte).strip().upper()
    s = s.replace("É", "E").replace("È", "E").replace("Ê", "E")
    return s


def _trouver_nom_feuille(xl: pd.ExcelFile, motif: str) -> str:
    """Trouve le nom d'onglet réel correspondant à un motif (ex: 'INFO', 'DIAM', 'COURB')."""
    for nom in xl.sheet_names:
        if motif in _normaliser_chaine(nom):
            return nom
    raise KeyError(f"Feuille correspondant à '{motif}' introuvable dans le fichier Excel.")


def _trouver_colonne(df: pd.DataFrame, motifs: list[str]) -> str:
    """Trouve le nom de colonne réel dans le DataFrame basé sur des mots-clés."""
    for col in df.columns:
        col_norm = _normaliser_chaine(col)
        if any(m in col_norm for m in motifs):
            return col
    raise KeyError(f"Colonne correspondant à {motifs} introuvable parmi {list(df.columns)}")


def _lire_info(chemin: str, xl: pd.ExcelFile) -> dict:
    nom_feuille = _trouver_nom_feuille(xl, "INFO")
    df = pd.read_excel(chemin, sheet_name=nom_feuille, header=0)
    
    res = {}
    for _, ligne in df.iterrows():
        cle = _normaliser_chaine(ligne.iloc[0])
        valeur = ligne.iloc[1]
        res[cle] = valeur
    return res


def _lire_diametres(chemin: str, xl: pd.ExcelFile) -> dict[str, list[float]]:
    nom_feuille = _trouver_nom_feuille(xl, "DIAM")
    df = pd.read_excel(chemin, sheet_name=nom_feuille, header=0).dropna(how="all")

    col_id = _trouver_colonne(df, ["ID", "ECH"])
    cols_d = [c for c in df.columns if "D1" in _normaliser_chaine(c) or "D2" in _normaliser_chaine(c) or "D3" in _normaliser_chaine(c)]
    
    if not cols_d:
        # Fallback sur les colonnes numériques après l'ID
        cols_d = [c for c in df.columns if c != col_id][:3]

    df = df[df[col_id].notna()]
    resultat = {}
    for _, ligne in df.iterrows():
        id_ech = str(ligne["ID Échantillon"]).strip().upper()
        diametres = [
            v for v in (
                _vers_nombre(ligne[col]) for col in ["D1 (mm)", "D2 (mm)", "D3 (mm)"]
            )
            if v is not None
        ]
        if not diametres:
            raise ValueError(
                f"Échantillon '{id_ech}' (feuille DIAMETRES) : aucune valeur "
                "de diamètre renseignée."
            )
        resultat[id_ech] = diametres
    return resultat


def _lire_courbes(chemin: str, xl: pd.ExcelFile) -> dict[str, list[tuple[float, float]]]:
    nom_feuille = _trouver_nom_feuille(xl, "COURB")
    df = pd.read_excel(chemin, sheet_name=nom_feuille, header=0).dropna(how="all")

    col_id = _trouver_colonne(df, ["ID", "ECH"])
    col_force = _trouver_colonne(df, ["FORCE", "N"])
    col_dep = _trouver_colonne(df, ["DEPLAC", "DEPL", "MM"])

    df = df[df[col_id].notna()]
    resultat: dict[str, list[tuple[float, float]]] = {}
    for numero_ligne, ligne in df.iterrows():
        id_ech = str(ligne["ID Échantillon"]).strip().upper()
        force = _vers_nombre(ligne["Force (N)"])
        deplacement = _vers_nombre(ligne["Déplacement (mm)"])
        if force is None or deplacement is None:
            raise ValueError(
                f"Feuille COURBE, ligne {numero_ligne + 2} (échantillon "
                f"'{id_ech}') : Force ou Déplacement non numérique."
            )
        resultat.setdefault(id_ech, []).append((force, deplacement))
    return resultat


def lire_gamme_complete(chemin_fichier: str) -> dict:
    """
    Point d'entrée principal. Lit le fichier 3-feuilles et construit une
    structure prête à être convertie en GammeRequest côté API.

    Le point de rupture (force max, pas le dernier point de la série -
    la force retombe souvent après rupture) et la longueur initiale
    (identique pour tous, depuis INFO) sont dérivés automatiquement.
    """
    if not os.path.exists(chemin_fichier):
        raise FileNotFoundError(f"Fichier introuvable : {chemin_fichier}")

    xl = pd.ExcelFile(chemin_fichier)
    info = _lire_info(chemin_fichier, xl)
    diametres_par_ech = _lire_diametres(chemin_fichier, xl)
    courbes_par_ech = _lire_courbes(chemin_fichier, xl)

    # Recherche tolérante de L0
    l0 = None
    for cle, val in info.items():
        if "L0" in cle or "LONGUEUR" in cle:
            l0 = _vers_nombre(val)
            if l0:
                break

    if not l0 or l0 <= 0:
        l0 = 50.0  # Valeur par défaut de secours si absente

    echantillons = []
    contraintes = []

    for id_ech, diametres in diametres_par_ech.items():
        points = courbes_par_ech.get(id_ech, [])
        if not points:
            continue

        force_rupture, deplacement_rupture = max(points, key=lambda p: p[0])

        echantillons.append({
            "identifiant": id_ech,
            "longueur_initiale_mm": l0,
            "diametres_mm": diametres,
            "section_mm2": round(section_mm2, 4),
            "force_max_newton": round(force_max, 3),
            "force_rupture_newton": round(force_max, 3),
            "deplacement_rupture_mm": round(deplacement_rupture, 3),
            "contrainte_rupture_mpa": round(contrainte_mpa, 2),
            "deformation_rupture_pourcent": round(deformation_pct, 2),
            "points_courbe": [
                {"force_newton": round(f, 3), "deplacement_mm": round(d, 3)} for f, d in points
            ],
        })

    # Extraction des infos annexes
    projet = next((val for cle, val in info.items() if "PROJET" in cle), "Projet Excel")
    norme = next((val for cle, val in info.items() if "NORME" in cle), "ISO 527")

    return {
        "materiau": {
            "nom_usage": str(projet),
            "code_interne": "TEMP",
            "famille": "autre",
        },
        "norme": {
            "code": str(norme),
            "designation": str(norme),
            "seuil_resistance_min_mpa": None,
        },
        "conditions": {
            "temperature_celsius": 23.0,
            "humidite_pourcent": 50.0,
        },
        "echantillons": echantillons,
        "resultats_echantillons": echantillons,
    }