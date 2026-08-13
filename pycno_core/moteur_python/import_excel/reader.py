import os
from typing import Any, Optional
import pandas as pd


def _vers_nombre(valeur: Any) -> Optional[float]:
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
        id_ech = str(ligne[col_id]).strip().upper()
        diametres = [v for v in (_vers_nombre(ligne[c]) for c in cols_d) if v is not None]
        if diametres:
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

    for _, ligne in df.iterrows():
        id_ech = str(ligne[col_id]).strip().upper()
        force = _vers_nombre(ligne[col_force])
        deplacement = _vers_nombre(ligne[col_dep])
        if force is not None and deplacement is not None:
            resultat.setdefault(id_ech, []).append((force, deplacement))

    return resultat


def lire_gamme_complete(chemin_fichier: str) -> dict:
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
    for id_ech, diametres in diametres_par_ech.items():
        points = courbes_par_ech.get(id_ech, [])
        if not points:
            continue

        force_rupture, deplacement_rupture = max(points, key=lambda p: p[0])

        echantillons.append({
            "identifiant": id_ech,
            "longueur_initiale_mm": l0,
            "diametres_mm": diametres,
            "force_rupture_newton": force_rupture,
            "deplacement_rupture_mm": deplacement_rupture,
            "points_courbe": [
                {"force_newton": f, "deplacement_mm": d} for f, d in points
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
    }