"""Lecture stricte des classeurs PycnoLab à trois feuilles."""

import math
import os
from typing import Any, Optional

import pandas as pd


def _vers_nombre(value: Any) -> Optional[float]:
    if value is None or (isinstance(value, float) and pd.isna(value)):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).strip().replace(',', '.'))
    except (TypeError, ValueError):
        return None


def _normaliser(value: Any) -> str:
    if value is None or pd.isna(value):
        return ''
    return (str(value).strip().upper().replace('É', 'E').replace('È', 'E').replace('Ê', 'E'))


def _feuille(xl: pd.ExcelFile, motif: str) -> str:
    for name in xl.sheet_names:
        if motif in _normaliser(name):
            return name
    raise KeyError(f"Feuille correspondant à '{motif}' introuvable.")


def _colonne(df: pd.DataFrame, motifs: list[str]) -> str:
    for column in df.columns:
        normalized = _normaliser(column)
        if any(motif in normalized for motif in motifs):
            return column
    raise KeyError(f"Colonne correspondant à {motifs} introuvable.")


def _lire_info(chemin: str, xl: pd.ExcelFile) -> dict[str, Any]:
    df = pd.read_excel(chemin, sheet_name=_feuille(xl, 'INFO'), header=0)
    if len(df.columns) < 2:
        raise ValueError('La feuille INFO doit contenir au moins deux colonnes.')
    return {_normaliser(row.iloc[0]): row.iloc[1] for _, row in df.iterrows() if _normaliser(row.iloc[0])}


def _lire_diametres(chemin: str, xl: pd.ExcelFile) -> dict[str, list[float]]:
    df = pd.read_excel(chemin, sheet_name=_feuille(xl, 'DIAM'), header=0).dropna(how='all')
    id_col = _colonne(df, ['ID', 'ECH'])
    diameter_cols = [c for c in df.columns if any(token in _normaliser(c) for token in ('D1', 'D2', 'D3'))]
    if not diameter_cols:
        diameter_cols = [c for c in df.columns if c != id_col][:3]
    result: dict[str, list[float]] = {}
    for _, row in df[df[id_col].notna()].iterrows():
        sample_id = str(row[id_col]).strip().upper()
        values = [number for number in (_vers_nombre(row[c]) for c in diameter_cols) if number is not None]
        if not values:
            raise ValueError(f"Aucun diamètre pour l'échantillon '{sample_id}'.")
        result[sample_id] = values
    return result


def _lire_courbes(chemin: str, xl: pd.ExcelFile) -> dict[str, list[tuple[float, float]]]:
    df = pd.read_excel(chemin, sheet_name=_feuille(xl, 'COURB'), header=0).dropna(how='all')
    id_col = _colonne(df, ['ID', 'ECH'])
    force_col = _colonne(df, ['FORCE', 'N'])
    displacement_col = _colonne(df, ['DEPLAC', 'DEPL', 'MM'])
    result: dict[str, list[tuple[float, float]]] = {}
    for line_number, (_, row) in enumerate(df[df[id_col].notna()].iterrows(), start=2):
        sample_id = str(row[id_col]).strip().upper()
        force = _vers_nombre(row[force_col])
        displacement = _vers_nombre(row[displacement_col])
        if force is None or displacement is None:
            raise ValueError(f'Ligne {line_number}: force ou déplacement non numérique.')
        result.setdefault(sample_id, []).append((force, displacement))
    return result


def lire_gamme_complete(chemin_fichier: str) -> dict[str, Any]:
    if not os.path.isfile(chemin_fichier):
        raise FileNotFoundError(f'Fichier introuvable : {chemin_fichier}')

    xl = pd.ExcelFile(chemin_fichier)
    info = _lire_info(chemin_fichier, xl)
    diametres = _lire_diametres(chemin_fichier, xl)
    courbes = _lire_courbes(chemin_fichier, xl)
    l0 = next((_vers_nombre(value) for key, value in info.items() if 'L0' in key or 'LONGUEUR' in key), None) or 50.0

    echantillons = []
    for sample_id, sample_diameters in diametres.items():
        points = courbes.get(sample_id, [])
        if not points:
            continue
        force_rupture, displacement_rupture = max(points, key=lambda point: point[0])
        diameter_mean = sum(sample_diameters) / len(sample_diameters)
        section = math.pi * (diameter_mean / 2.0) ** 2
        echantillons.append({
            'identifiant': sample_id,
            'longueur_initiale_mm': l0,
            'diametres_mm': sample_diameters,
            'force_rupture_newton': force_rupture,
            'deplacement_rupture_mm': displacement_rupture,
            'points_courbe': [
                {'force_newton': force, 'deplacement_mm': displacement}
                for force, displacement in points
            ],
            'section_mm2': round(section, 4),
        })

    norme = next((value for key, value in info.items() if 'NORME' in key), 'ISO 527')
    projet = next((value for key, value in info.items() if 'PROJET' in key), 'Projet Excel')
    seuil = next((_vers_nombre(value) for key, value in info.items() if 'SEUIL' in key and 'RESIST' in key), None)
    return {
        'materiau': {'nom_usage': str(projet), 'code_interne': 'EXCEL', 'famille': 'autre'},
        'norme': {
            'code': str(norme),
            'designation': str(norme),
            'seuil_resistance_min_mpa': seuil,
            'seuil_allongement_min_pourcent': None,
        },
        'conditions': {'temperature_celsius': 23.0, 'humidite_pourcent': 50.0},
        'echantillons': echantillons,
        'calculs_demandes': [],
    }
