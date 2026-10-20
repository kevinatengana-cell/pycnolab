"""Lecteur Excel PycnoLab : format standard vertical et format labo horizontal."""
from __future__ import annotations

import math
import os
import re
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
    return str(value).strip().upper().replace('É', 'E').replace('È', 'E').replace('Ê', 'E')


def _sheet_by_name(xl: pd.ExcelFile, name: str) -> str | None:
    wanted = _normaliser(name)
    return next((sheet for sheet in xl.sheet_names if _normaliser(sheet) == wanted), None)


def _feuille(xl: pd.ExcelFile, motif: str) -> str:
    wanted = _normaliser(motif)
    for name in xl.sheet_names:
        if wanted in _normaliser(name):
            return name
    raise KeyError(f"Feuille correspondant à '{motif}' introuvable.")


def _colonne(df: pd.DataFrame, motifs: list[str]) -> str:
    for column in df.columns:
        normalized = _normaliser(column)
        if any(motif in normalized for motif in motifs):
            return column
    raise KeyError(f"Colonne correspondant à {motifs} introuvable.")


def _read_vertical(chemin: str, xl: pd.ExcelFile) -> dict[str, Any]:
    info_sheet = _feuille(xl, 'INFO')
    diam_sheet = _feuille(xl, 'DIAM')
    curve_sheet = _feuille(xl, 'COURB')
    info_df = pd.read_excel(chemin, sheet_name=info_sheet, header=0)
    info = {
        _normaliser(row.iloc[0]): row.iloc[1]
        for _, row in info_df.iterrows()
        if len(row) >= 2 and _normaliser(row.iloc[0])
    }
    diam_df = pd.read_excel(chemin, sheet_name=diam_sheet, header=0).dropna(how='all')
    id_col = _colonne(diam_df, ['ID', 'ECH'])
    diameter_cols = [c for c in diam_df.columns if any(t in _normaliser(c) for t in ('D1', 'D2', 'D3'))]
    if not diameter_cols:
        diameter_cols = [c for c in diam_df.columns if c != id_col][:3]
    diameters: dict[str, list[float]] = {}
    for _, row in diam_df[diam_df[id_col].notna()].iterrows():
        ident = str(row[id_col]).strip().upper()
        values = [_vers_nombre(row[c]) for c in diameter_cols]
        values = [v for v in values if v is not None]
        if values:
            diameters[ident] = values
    curve_df = pd.read_excel(chemin, sheet_name=curve_sheet, header=0).dropna(how='all')
    curve_id = _colonne(curve_df, ['ID', 'ECH'])
    force_col = _colonne(curve_df, ['FORCE'])
    disp_col = _colonne(curve_df, ['DEPLAC', 'DEPL', 'MM'])
    curves: dict[str, list[tuple[float, float]]] = {}
    for _, row in curve_df[curve_df[curve_id].notna()].iterrows():
        ident = str(row[curve_id]).strip().upper()
        force = _vers_nombre(row[force_col]); displacement = _vers_nombre(row[disp_col])
        if force is not None and displacement is not None:
            curves.setdefault(ident, []).append((force, displacement))
    l0 = next((_vers_nombre(v) for k, v in info.items() if 'L0' in k or 'LONGUEUR' in k), None) or 50.0
    return _build_gamme(diameters, curves, l0, info.get('PROJET', 'Projet Excel'), info.get('NORME', 'ISO 527'), info.get('SEUIL RESISTANCE'))


def _horizontal_headers(worksheet: Any) -> list[tuple[int, int, str]]:
    """Retourne (colonne elong, colonne force, identifiant) depuis la ligne 1."""
    headers = []
    for col in range(1, worksheet.max_column + 1):
        value = str(worksheet.cell(1, col).value or '').strip()
        match = re.search(r'ELONG\.?\s*\(MM\)\s*-\s*ECH\s*(\d+)', value, re.I)
        if not match:
            continue
        sample_number = int(match.group(1))
        force_col = next(
            (candidate for candidate in range(col + 1, min(worksheet.max_column, col + 8) + 1)
             if str(worksheet.cell(1, candidate).value or '').strip().upper().startswith('FORCE(')),
            None,
        )
        if force_col is not None:
            headers.append((col, force_col, f'ECH{sample_number}'))
    # Certains anciens classeurs répètent l’en-tête Elong deux fois dans un bloc.
    unique: dict[str, tuple[int, int, str]] = {}
    for item in headers:
        unique[item[2]] = item
    return sorted(unique.values(), key=lambda item: item[0])


def _horizontal_diameters(worksheet: Any, side: str) -> dict[str, list[float]]:
    start = 2 if side == 'COROUI' else 10
    id_col = start - 1
    result: dict[str, list[float]] = {}
    for row in range(3, worksheet.max_row + 1):
        ident = worksheet.cell(row, id_col).value
        if ident is None:
            continue
        values = [_vers_nombre(worksheet.cell(row, start + offset).value) for offset in range(3)]
        values = [v for v in values if v is not None]
        if values:
            result[str(ident).strip().upper()] = values
    return result


def _read_horizontal_sheet(worksheet: Any, diameters: dict[str, list[float]], l0: float, project: str, norm: str) -> dict[str, Any]:
    curves: dict[str, list[tuple[float, float]]] = {}
    for elong_col, force_col, ident in _horizontal_headers(worksheet):
        points: list[tuple[float, float]] = []
        for row in range(2, worksheet.max_row + 1):
            displacement = _vers_nombre(worksheet.cell(row, elong_col).value)
            force = _vers_nombre(worksheet.cell(row, force_col).value)
            if displacement is None and force is None:
                continue
            if displacement is None or force is None:
                raise ValueError(f'{worksheet.title}/{ident}: point incomplet à la ligne {row}.')
            points.append((force, displacement))
        if points:
            curves[ident] = points
    return _build_gamme(diameters, curves, l0, project, norm, None)


def _build_gamme(diameters: dict[str, list[float]], curves: dict[str, list[tuple[float, float]]], l0: float, project: Any, norm: Any, threshold: Any) -> dict[str, Any]:
    samples = []
    for ident, values in diameters.items():
        points = curves.get(ident, [])
        if not points:
            continue
        force_rupture, displacement_rupture = max(points, key=lambda point: point[0])
        diameter_mean = sum(values) / len(values)
        samples.append({
            'identifiant': ident,
            'longueur_initiale_mm': l0,
            'diametres_mm': values,
            'diametre_moyen_mm': round(diameter_mean, 6),
            'force_rupture_newton': force_rupture,
            'deplacement_rupture_mm': displacement_rupture,
            'points_courbe': [
                {'force_newton': force, 'deplacement_mm': displacement}
                for force, displacement in points
            ],
            'section_mm2': round(math.pi * (diameter_mean / 2.0) ** 2, 4),
        })
    global_mean = (sum(sample['diametre_moyen_mm'] for sample in samples) / len(samples)) if samples else None
    return {
        'nom_gamme': str(project),
        'diametre_moyen_global_mm': None if global_mean is None else round(global_mean, 6),
        'materiau': {'nom_usage': str(project), 'code_interne': 'EXCEL', 'famille': 'autre'},
        'norme': {'code': str(norm), 'designation': str(norm), 'seuil_resistance_min_mpa': _vers_nombre(threshold), 'seuil_allongement_min_pourcent': None},
        'conditions': {'temperature_celsius': 23.0, 'humidite_pourcent': 50.0},
        'echantillons': samples,
        'calculs_demandes': [],
    }


def lire_gammes_horizontal(chemin_fichier: str) -> list[dict[str, Any]]:
    """Lit toutes les feuilles de courbes horizontales reconnues comme gammes."""
    if not os.path.isfile(chemin_fichier):
        raise FileNotFoundError(f'Fichier introuvable : {chemin_fichier}')
    from openpyxl import load_workbook
    # Les blocs historiques contiennent parfois une colonne Elong auxiliaire
    # remplie par des formules. Les valeurs mises en cache permettent de lire
    # les nombres affichés sans interpréter ces formules comme des mesures.
    wb = load_workbook(chemin_fichier, data_only=True, read_only=False)
    diameter_sheet = wb['DIAMETRE (CR,CS)'] if 'DIAMETRE (CR,CS)' in wb.sheetnames else None
    # Le classeur de référence utilise une longueur utile de 20 mm.
    # En production, cette valeur devra venir des métadonnées ou du protocole.
    l0 = 20.0
    resultats = []
    for sheet_name in wb.sheetnames:
        key = _normaliser(sheet_name)
        if key not in {'COROUI', 'COSOU'}:
            continue
        diameters = _horizontal_diameters(diameter_sheet, key) if diameter_sheet is not None else {}
        resultats.append(_read_horizontal_sheet(wb[sheet_name], diameters, l0, sheet_name, 'À définir'))
    return resultats


def lire_classeur_complet(chemin_fichier: str) -> list[dict[str, Any]]:
    """Lit un seul classeur horizontal contenant toutes ses gammes (COROUI, COSOU, etc.)."""
    return lire_gammes_horizontal(chemin_fichier)


def lire_gammes_depuis_fichiers(chemins: list[str]) -> list[dict[str, Any]]:
    """Lit plusieurs fichiers d'import verticaux, un fichier correspondant à une gamme."""
    if not chemins:
        raise ValueError('Au moins un fichier Excel doit être fourni.')
    gammes = []
    for chemin in chemins:
        gamme = lire_gamme_complete(chemin)
        gamme['source_fichier'] = os.path.basename(chemin)
        gammes.append(gamme)
    return gammes


def lire_gamme_complete(chemin_fichier: str) -> dict[str, Any]:
    """Compatibilité avec l’API existante : lit un fichier vertical ou la première gamme horizontale."""
    xl = pd.ExcelFile(chemin_fichier)
    if _sheet_by_name(xl, 'COROUI') or _sheet_by_name(xl, 'COSOU'):
        gammes = lire_gammes_horizontal(chemin_fichier)
        if not gammes:
            raise ValueError('Aucune gamme horizontale exploitable.')
        return gammes[0]
    return _read_vertical(chemin_fichier, xl)
