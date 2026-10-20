from __future__ import annotations
from pathlib import Path
from typing import Any
import math, re, sys, traceback

from openpyxl import load_workbook
from openpyxl.chart import ScatterChart, BarChart, Reference, Series
from openpyxl.chart.label import DataLabelList
from openpyxl.chart.text import RichText, Text
from openpyxl.chart.title import Title
from openpyxl.drawing.text import (
    Paragraph, ParagraphProperties, CharacterProperties, RegularTextRun,
    Font as _PoliceDessin,
)
from openpyxl.drawing.spreadsheet_drawing import AnchorMarker, OneCellAnchor
from openpyxl.drawing.xdr import XDRPositiveSize2D
from openpyxl.chart.marker import Marker
from openpyxl.chart.trendline import Trendline
from openpyxl.chart.shapes import GraphicalProperties
from openpyxl.drawing.line import LineProperties
from openpyxl.styles import PatternFill, Font
from openpyxl.utils import get_column_letter, column_index_from_string
from openpyxl.utils.units import cm_to_EMU

try:
    from ..import_excel.reader import read_workbook
except ImportError:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    try:
        from reader import read_workbook
    except ImportError:
        from classeur_entree_reader import read_workbook


RECAP_SHEET = 'RECCAPITULATIF'
TYPES_ESSAI_SUPPORTES = ('traction', 'compression', 'flexion')

FILL_BLEU_EN_TETE = PatternFill('solid', fgColor='BDD7EE')
FILL_BLEU_TOTAL   = PatternFill('solid', fgColor='DEEAF6')
FONT_GRAS = Font(bold=True)

COULEUR_GRAPHE = '4472C4'
COULEUR_ZONE   = 'ED7D31'


# ---------------------------------------------------------------------------
# Description des blocs de dimensions, une entrée par forme.
# ---------------------------------------------------------------------------
_ENTETES_FORMES = {
    'cylindre': (
        ('D_1(mm)', 'D_2(mm)', 'D_3(mm)', 'D_Moy(mm)', 'S_(mm2)'),
        ['D1', 'D2', 'D3'],
    ),
    'rectangle': (
        ('L_1(mm)', 'L_2(mm)', 'L_3(mm)',
         'E_1(mm)', 'E_2(mm)', 'E_3(mm)',
         'L_Moy(mm)', 'E_Moy(mm)', 'S_(mm2)'),
        ['L1', 'L2', 'L3', 'E1', 'E2', 'E3'],
    ),
    'carre': (
        ('C_1(mm)', 'C_2(mm)', 'C_3(mm)', 'C_Moy(mm)', 'S_(mm2)'),
        ['C1', 'C2', 'C3'],
    ),
    'tube_circulaire': (
        ('D_ext_1(mm)', 'D_ext_2(mm)', 'D_ext_3(mm)',
         'D_int_1(mm)', 'D_int_2(mm)', 'D_int_3(mm)',
         'D_ext_Moy(mm)', 'D_int_Moy(mm)', 'S_(mm2)'),
        ['DEXT1', 'DEXT2', 'DEXT3', 'DINT1', 'DINT2', 'DINT3'],
    ),
    'tube_rectangulaire': (
        ('B_1(mm)', 'B_2(mm)', 'B_3(mm)',
         'H_1(mm)', 'H_2(mm)', 'H_3(mm)',
         'b_1(mm)', 'b_2(mm)', 'b_3(mm)',
         'h_1(mm)', 'h_2(mm)', 'h_3(mm)',
         'B_Moy(mm)', 'H_Moy(mm)', 'b_Moy(mm)', 'h_Moy(mm)', 'S_(mm2)'),
        ['B1', 'B2', 'B3', 'H1', 'H2', 'H3',
         'B1', 'B2', 'B3', 'H1', 'H2', 'H3'],
    ),
    'surface': (
        ('S_1(mm2)', 'S_2(mm2)', 'S_3(mm2)', 'S_Moy(mm2)'),
        ['S1', 'S2', 'S3'],
    ),
}

# Index (0-based, relatif au début du bloc) de la colonne S
_OFFSET_S = {
    'cylindre': 4,
    'rectangle': 8,
    'carre': 4,
    'tube_circulaire': 8,
    'tube_rectangulaire': 16,
    'surface': 3,
}


def _log(msg: str) -> None:
    try:
        print(f"[EXPORT] {msg}", flush=True)
    except Exception:
        pass


def _normaliser_txt(valeur) -> str:
    return re.sub(r'[^A-Z0-9]', '', str(valeur or '').upper())


def _blocks(ws):
    out = []
    for c in range(1, ws.max_column + 1):
        h = str(ws.cell(1, c).value or '')
        m = re.search(r'ELONG.*(?:ECH|PLOT)\s*(\d+)', h, re.I)
        if not m:
            continue
        force = next(
            (j for j in range(c + 1, min(ws.max_column, c + 10) + 1)
             if 'FORCE' in str(ws.cell(1, j).value or '').upper()),
            None
        )
        if force is not None:
            out.append((int(m.group(1)), c, force))
    out.sort(key=lambda t: t[1])
    result = {}
    for n, c, f in out:
        if n not in result:
            result[n] = (c, f)
    return result


def _find_diameter_sheet_name(wb):
    """Renvoie le nom de la feuille de dimensions du template, ou None."""
    candidates = [
        name for name in wb.sheetnames
        if re.sub(r'[^A-Z0-9]+', '', str(name).upper()).startswith(
            ('DIAMETRE', 'DIAMETER', 'DIMENSION'))
    ]
    return candidates[0] if candidates else None


def _find_group_template_name(wb, sheets_a_exclure, preferred=None):
    exclus = {re.sub(r'[^A-Z0-9]+', '', str(s).upper()) for s in sheets_a_exclure}
    if preferred and preferred in wb.sheetnames:
        if re.sub(r'[^A-Z0-9]+', '', preferred.upper()) not in exclus:
            return preferred
    for name in wb.sheetnames:
        normalized = re.sub(r'[^A-Z0-9]+', '', str(name).upper())
        if normalized not in exclus:
            return name
    return None


def _ensure_group_sheet(wb, name, sheets_a_exclure, template_name=None):
    if name in wb.sheetnames:
        return wb[name]
    template_name = _find_group_template_name(wb, sheets_a_exclure, preferred=template_name)
    if template_name is None:
        return wb.create_sheet(name)
    ws = wb.copy_worksheet(wb[template_name])
    ws.title = name
    return ws


def _ensure_block(ws, index):
    blocks = _blocks(ws)
    if index in blocks:
        ec, fc = blocks[index]
    else:
        ec = ws.max_column + 2
        fc = ec + 1
        ws.cell(1, ec).value = f'Elong.(mm) - Ech {index}'
        ws.cell(1, fc).value = f'Force(N) - Ech {index}'
        for off, label in enumerate(
                ['Def', 'Cont', 'Cont(max)', 'Def rupt', 'E(mpa)'], 1):
            ws.cell(1, fc + off).value = label

    derniere_col = min(fc + 5, ws.max_column)
    for rr in range(2, ws.max_row + 1):
        for cc in range(ec, derniere_col + 1):
            cur = ws.cell(rr, cc).value
            if (cc == ec + 1 and fc > ec + 1
                    and isinstance(cur, str) and cur.startswith('=')):
                continue
            ws.cell(rr, cc).value = None

    return ec, fc


def _set_cell(ws, row, col, value):
    cell = ws.cell(row, col)
    if type(cell).__name__ == 'MergedCell':
        for rng in ws.merged_cells.ranges:
            if rng.min_row <= row <= rng.max_row and rng.min_col <= col <= rng.max_col:
                ws.cell(rng.min_row, rng.min_col).value = value
                return
    cell.value = value


# ---------------------------------------------------------------------------
# Gestion des blocs de dimensions, multi-formes
# ---------------------------------------------------------------------------

def _signature_bloc(ws, row, start_col, patterns):
    for offset, pattern in enumerate(patterns):
        val = ws.cell(row, start_col + offset).value
        norm = _normaliser_txt(val)
        if not re.fullmatch(rf'{pattern}(MM2?)?', norm):
            return False
    return True


def _trouver_debuts_bloc(ws, patterns, ligne_entete=2):
    debuts = []
    col = 1
    while col <= ws.max_column - len(patterns) + 1:
        if _signature_bloc(ws, ligne_entete, col, patterns):
            debuts.append(col)
            col += len(patterns)
        else:
            col += 1
    return debuts


def _ensure_dimension_group(ws, group_index, name, forme, titre_source=None):
    if forme not in _ENTETES_FORMES:
        forme = 'cylindre'
    entetes, patterns = _ENTETES_FORMES[forme]

    debuts = _trouver_debuts_bloc(ws, patterns, ligne_entete=2)

    # On utilise le titre source du labo s'il existe, sinon on garde le format par défaut
    titre_cellule = titre_source if titre_source else f'DIMENSION {forme.upper()} — {name}'

    if group_index <= len(debuts):
        start = debuts[group_index - 1]
        _set_cell(ws, 1, start, titre_cellule)
        return start

    if debuts:
        pas = (debuts[-1] - debuts[-2]) if len(debuts) > 1 else len(entetes) + 2
        start = debuts[-1] + pas
    else:
        start = ws.max_column + 2

    _set_cell(ws, 1, start, titre_cellule)
    ws.cell(2, start - 1).value = 'Identifiant'
    for off, label in enumerate(entetes):
        ws.cell(2, start + off).value = label

    return start


def _ensure_diameter_group(ws, group_index, name):
    return _ensure_dimension_group(ws, group_index, name, 'cylindre')


def _ecrire_formules_dimensions(ws, ligne, dstart, forme):
    L = get_column_letter

    def rng(col_start, n):
        return (f"{L(dstart + col_start)}{ligne}:"
                f"{L(dstart + col_start + n - 1)}{ligne}")

    if forme == 'cylindre':
        ws.cell(ligne, dstart + 3).value = f'=AVERAGE({rng(0, 3)})'
        dm = L(dstart + 3)
        ws.cell(ligne, dstart + 4).value = f'=PI()*{dm}{ligne}^2/4'

    elif forme == 'rectangle':
        ws.cell(ligne, dstart + 6).value = f'=AVERAGE({rng(0, 3)})'
        ws.cell(ligne, dstart + 7).value = f'=AVERAGE({rng(3, 3)})'
        lm = L(dstart + 6)
        em = L(dstart + 7)
        ws.cell(ligne, dstart + 8).value = f'={lm}{ligne}*{em}{ligne}'

    elif forme == 'carre':
        ws.cell(ligne, dstart + 3).value = f'=AVERAGE({rng(0, 3)})'
        cm = L(dstart + 3)
        ws.cell(ligne, dstart + 4).value = f'={cm}{ligne}^2'

    elif forme == 'tube_circulaire':
        ws.cell(ligne, dstart + 6).value = f'=AVERAGE({rng(0, 3)})'
        ws.cell(ligne, dstart + 7).value = f'=AVERAGE({rng(3, 3)})'
        de = L(dstart + 6)
        di = L(dstart + 7)
        ws.cell(ligne, dstart + 8).value = (
            f'=PI()*({de}{ligne}^2-{di}{ligne}^2)/4'
        )

    elif forme == 'tube_rectangulaire':
        ws.cell(ligne, dstart + 12).value = f'=AVERAGE({rng(0, 3)})'
        ws.cell(ligne, dstart + 13).value = f'=AVERAGE({rng(3, 3)})'
        ws.cell(ligne, dstart + 14).value = f'=AVERAGE({rng(6, 3)})'
        ws.cell(ligne, dstart + 15).value = f'=AVERAGE({rng(9, 3)})'
        B = L(dstart + 12)
        H = L(dstart + 13)
        b = L(dstart + 14)
        h = L(dstart + 15)
        ws.cell(ligne, dstart + 16).value = (
            f'={B}{ligne}*{H}{ligne}-{b}{ligne}*{h}{ligne}'
        )

    elif forme == 'surface':
        ws.cell(ligne, dstart + 3).value = f'=AVERAGE({rng(0, 3)})'


def _valeurs_brutes_pour_forme(s, forme):
    if forme == 'cylindre':
        d = s.get('diametres_mm') or []
        if len(d) >= 3:
            return list(d[:3])
        dims = s.get('dimensions_mm', {})
        return [dims.get(k) for k in ('D_1', 'D_2', 'D_3')]

    if forme == 'rectangle':
        dims = s.get('dimensions_mm', {})
        return [dims.get(k) for k in ('L_1', 'L_2', 'L_3', 'E_1', 'E_2', 'E_3')]

    if forme == 'carre':
        dims = s.get('dimensions_mm', {})
        return [dims.get(k) for k in ('C_1', 'C_2', 'C_3')]

    if forme == 'tube_circulaire':
        dims = s.get('dimensions_mm', {})
        return [dims.get(k) for k in
                ('D_ext_1', 'D_ext_2', 'D_ext_3',
                 'D_int_1', 'D_int_2', 'D_int_3')]

    if forme == 'tube_rectangulaire':
        dims = s.get('dimensions_mm', {})
        return [dims.get(k) for k in
                ('B_1', 'B_2', 'B_3', 'H_1', 'H_2', 'H_3',
                 'b_1', 'b_2', 'b_3', 'h_1', 'h_2', 'h_3')]

    if forme == 'surface':
        dims = s.get('dimensions_mm', {})
        return [dims.get(k) for k in ('S_1', 'S_2', 'S_3')]

    return []


def _young(strains, stresses, zero_tol=1e-9):
    n = len(strains)
    if n < 3 or len(stresses) != n:
        return (None, None, None)

    sigma_max = max(stresses)
    if sigma_max <= zero_tol:
        return (None, None, None)

    seuil_toe = 0.05 * sigma_max
    i_debut_utile = 0
    for k in range(1, n):
        if stresses[k] > seuil_toe and stresses[k] > stresses[k - 1]:
            i_debut_utile = max(0, k - 1)
            break

    if i_debut_utile >= n - 2:
        i_debut_utile = 0

    points = []
    dernier_x = None
    for idx in range(i_debut_utile, n):
        x = strains[idx]
        y = stresses[idx]
        if abs(y) <= zero_tol:
            continue
        if dernier_x is not None and abs(x - dernier_x) <= zero_tol:
            continue
        points.append((idx, x, y))
        dernier_x = x

    if len(points) < 3:
        return (None, None, None)

    pos_max = max(range(len(points)), key=lambda i: points[i][2])
    points = points[:pos_max + 1]
    if len(points) < 3:
        return (None, None, None)

    paliers = [
        (6, 0.99),
        (5, 0.97),
        (4, 0.95),
        (3, 0.90),
    ]

    for min_points, r2_min in paliers:
        if len(points) < min_points:
            continue

        for debut in range(0, len(points) - min_points + 1):
            for taille in range(min_points, len(points) - debut + 1):
                win = points[debut:debut + taille]
                xs = [p[1] for p in win]
                ys = [p[2] for p in win]

                if len(set(round(x, 12) for x in xs)) < 2:
                    continue
                if any(ys[i] < ys[i - 1] for i in range(1, len(ys))):
                    continue

                mx = sum(xs) / taille
                my = sum(ys) / taille
                dx2 = sum((x - mx) ** 2 for x in xs)
                if dx2 < 1e-15:
                    continue

                pente = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / dx2
                if pente <= 0:
                    continue

                y_pred = [my + pente * (x - mx) for x in xs]
                ss_res = sum((y - yp) ** 2 for y, yp in zip(ys, y_pred))
                ss_tot = sum((y - my) ** 2 for y in ys)
                if ss_tot < 1e-15:
                    continue

                r2 = 1.0 - ss_res / ss_tot
                if r2 >= r2_min:
                    return (pente, win[0][0], taille)

    for debut in range(max(1, len(points) - 5)):
        win = points[debut:debut + 3]
        if len(win) < 3:
            break
        xs = [p[1] for p in win]
        ys = [p[2] for p in win]

        mx = sum(xs) / 3
        my = sum(ys) / 3
        dx2 = sum((x - mx) ** 2 for x in xs)
        if dx2 <= 1e-15:
            continue

        pente = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / dx2
        if pente > 0:
            return (pente, win[0][0], 3)

    return (None, None, None)


def _deformation_contrainte(type_essai, x_mm, force_n, *,
                             l0_mm=None, section_mm2=None,
                             portee_mm=None, base_mm=None, hauteur_mm=None):
    """Calcule (déformation, contrainte) pour un point.

    - traction/compression : l0_mm et section_mm2 requis.
    - flexion : portee_mm, base_mm et hauteur_mm requis (par échantillon).
    """
    if type_essai in ('traction', 'compression'):
        strain = x_mm / l0_mm
        stress = force_n / section_mm2
    elif type_essai == 'flexion':
        strain = 6.0 * hauteur_mm * x_mm / (portee_mm ** 2)
        stress = 3.0 * force_n * portee_mm / (2.0 * base_mm * hauteur_mm ** 2)
    else:
        raise ValueError(f"type_essai inconnu : {type_essai!r}")
    return strain, stress


def _geometrie_flexion_pour_ech(geometrie_flexion, nom_gamme, identifiant):
    """Renvoie (portee, base, hauteur) pour un échantillon.

    Priorité : dimensions_par_echantillon[gamme][ech], sinon repli global.
    Chaque échantillon peut définir sa portée, sa base et sa hauteur.
    """
    portee = geometrie_flexion.get('portee_mm')
    dims_gamme = (geometrie_flexion.get('dimensions_par_echantillon') or {}).get(
        nom_gamme, {}
    )
    dims_ech = dims_gamme.get(identifiant, {})
    portee = dims_ech.get('portee_mm', portee)
    base = dims_ech.get('base_mm', geometrie_flexion.get('base_mm'))
    hauteur = dims_ech.get('hauteur_mm', geometrie_flexion.get('hauteur_mm'))
    return portee, base, hauteur


def _police_dessin(taille, gras=True):
    return CharacterProperties(sz=taille, b=gras, solidFill='000000',
                               latin=_PoliceDessin(typeface='Times New Roman'))


def _texte_riche(taille, gras=True):
    cp = _police_dessin(taille, gras)
    return RichText(p=[Paragraph(pPr=ParagraphProperties(defRPr=cp), endParaRPr=cp)])


def _titre_style(texte, taille):
    cp = _police_dessin(taille, True)
    par = Paragraph(pPr=ParagraphProperties(defRPr=cp),
                    r=[RegularTextRun(rPr=cp, t=texte)])
    return Title(tx=Text(rich=RichText(p=[par])), overlay=False)


def _largeur_col_cm(ws, c):
    w = None
    for lettre, dim in ws.column_dimensions.items():
        try:
            if dim.min is not None and dim.max is not None:
                dedans = dim.min <= c <= dim.max
            else:
                dedans = column_index_from_string(lettre) == c
            if dedans and dim.width:
                w = dim.width
                break
        except Exception:
            pass
    if w is None:
        w = getattr(ws.sheet_format, 'defaultColWidth', None) or 8.43
    return (w * 7 + 5) / 37.795


def _style_barres_recap(chart, titre, titre_y):
    chart.title = _titre_style(titre, 1400)
    chart.x_axis.title = _titre_style('Variétés', 1000)
    chart.y_axis.title = _titre_style(titre_y, 1000)
    chart.x_axis.delete = False
    chart.y_axis.delete = False
    chart.x_axis.txPr = _texte_riche(1000, True)
    chart.y_axis.txPr = _texte_riche(900, False)
    chart.y_axis.scaling.min = 0
    chart.y_axis.majorGridlines.spPr = GraphicalProperties(
        ln=LineProperties(solidFill='B7B7B7'))
    chart.legend = None
    chart.width = 9.0
    chart.height = 11.6
    dl = DataLabelList()
    dl.showVal = True
    dl.showSerName = False
    dl.showCatName = False
    dl.showLegendKey = False
    dl.showPercent = False
    dl.numFmt = '0.000'
    dl.position = 'outEnd'
    dl.txPr = _texte_riche(900, True)
    chart.series[0].dLbls = dl


def _safe_style_bar(series, couleur=COULEUR_GRAPHE):
    for s in series:
        try:
            if s.graphicalProperties is None:
                s.graphicalProperties = GraphicalProperties()
            s.graphicalProperties.solidFill = couleur
            if s.graphicalProperties.line is None:
                s.graphicalProperties.line = LineProperties()
            s.graphicalProperties.line.noFill = True
        except Exception as e:
            _log(f"style barre : {e}")


def _safe_apply_fill(cell, fill):
    try:
        cell.fill = fill
    except Exception:
        pass


def _safe_apply_font(cell, font):
    try:
        cell.font = font
    except Exception:
        pass


def process_workbook(
    input_path,
    template_path,
    output_path,
    type_essai='traction',
    l0_mm=20.0,
    geometrie=None,
    forme=None,
):
    _log(f"input={input_path} template={template_path} output={output_path}")
    _log(f"type_essai={type_essai} l0_mm={l0_mm} forme={forme!r}")

    if type_essai not in TYPES_ESSAI_SUPPORTES:
        raise ValueError(f"type_essai inconnu : {type_essai!r}")

    # Fusionner l0_mm dans la géométrie pour qu'il soit disponible dans
    # read_workbook quel que soit le type d'essai. Pour la compression,
    # l0_mm vient de l'UI (la feuille de dimensions n'en fournit pas).
    geometrie_effective = dict(geometrie or {})
    if l0_mm is not None and 'l0_mm' not in geometrie_effective:
        geometrie_effective['l0_mm'] = float(l0_mm)

    data = read_workbook(
        input_path,
        type_essai=type_essai,
        geometrie=geometrie_effective,
        forme=forme,
    )
    wb = load_workbook(template_path, data_only=False)
    groups = data['gammes']
    _log(f"{len(groups)} gamme(s) : {[g['nom_gamme'] for g in groups]}")

    a_feuille_dimensions = data.get('a_feuille_dimensions', False)

    # Détection de la feuille de dimensions dans le template, pour tous
    # les types d'essai. Si le template n'en a pas, on tombe en repli
    # "sections en littéral" sans lever d'erreur.
    diameter_sheet_name = None
    if a_feuille_dimensions:
        diameter_sheet_name = _find_diameter_sheet_name(wb)
        if diameter_sheet_name is None:
            _log("Template sans feuille de dimensions : sections en littéral")

    if RECAP_SHEET not in wb.sheetnames:
        wb.create_sheet(RECAP_SHEET)

    sheets_a_exclure = {RECAP_SHEET}
    if diameter_sheet_name:
        sheets_a_exclure.add(diameter_sheet_name)

    needed = sheets_a_exclure | {g['nom_gamme'] for g in groups}
    for g in groups:
        _ensure_group_sheet(wb, g['nom_gamme'], sheets_a_exclure)
        try:
            wb[g['nom_gamme']]._charts.clear()
        except Exception:
            pass
    for name in list(wb.sheetnames):
        if name not in needed:
            try:
                wb.remove(wb[name])
            except Exception:
                pass

    diam = wb[diameter_sheet_name] if diameter_sheet_name else None
    summaries = []
    geometrie_flexion = data.get('geometrie_flexion')
    forme_effective = forme or 'cylindre'

    for gi, g in enumerate(groups, 1):
        name = g['nom_gamme']
        ws = wb[name]
        _log(f"Gamme {gi}/{len(groups)} : {name} ({len(g['echantillons'])} éch.)")

        dstart = None
        if diam is not None:
            dstart = _ensure_dimension_group(
                diam,
                gi,
                name,
                forme_effective,
                titre_source=g.get('titre_dimensions_source'),
            )

        n_s = len(g['echantillons'])

        for i, s in enumerate(g['echantillons'], 1):
            ident = s['identifiant']
            try:
                # ------------------------------------------------------------------
                # Préparation des paramètres selon le type d'essai
                # ------------------------------------------------------------------
                if type_essai in ('traction', 'compression'):
                    sec = s['section_mm2']
                    l0_local = l0_mm if type_essai == 'traction' else s['l0_mm']
                    portee = base = hauteur = None
                elif type_essai == 'flexion':
                    sec = None
                    l0_local = None
                    portee, base, hauteur = _geometrie_flexion_pour_ech(
                        geometrie_flexion, name, ident
                    )
                    if portee is None or base is None or hauteur is None:
                        raise ValueError(
                            f"Portée/base/hauteur manquante(s) pour {ident} "
                            f"(gamme {name!r})"
                        )
                else:
                    sec = l0_local = None
                    portee = base = hauteur = None

                # ------------------------------------------------------------------
                # Écriture du bloc de dimensions dans la feuille DIMENSIONS
                # (uniquement si le template en a une et si le fichier d'entrée
                # en avait une).
                # ------------------------------------------------------------------
                sec_cell = f'{sec:.6g}' if sec is not None else None
                if diam is not None:
                    ligne_dim = 2 + i
                    diam.cell(ligne_dim, dstart - 1).value = ident
                    valeurs = _valeurs_brutes_pour_forme(s, forme_effective)
                    for j, valeur in enumerate(valeurs):
                        diam.cell(ligne_dim, dstart + j).value = valeur
                    _ecrire_formules_dimensions(
                        diam, ligne_dim, dstart, forme_effective
                    )
                    if type_essai in ('traction', 'compression'):
                        offset_S = _OFFSET_S.get(forme_effective, 4)
                        sm_l = get_column_letter(dstart + offset_S)
                        sec_cell = (
                            f"'{diameter_sheet_name}'!${sm_l}${ligne_dim}"
                        )

                # ------------------------------------------------------------------
                # Écriture des points de la courbe dans la feuille de gamme
                # ------------------------------------------------------------------
                ec, fc = _ensure_block(ws, i)
                ec_l = get_column_letter(ec)
                fc_l = get_column_letter(fc)
                def_l = get_column_letter(fc + 1)
                cont_l = get_column_letter(fc + 2)
                contmax_l = get_column_letter(fc + 3)
                defrupt_l = get_column_letter(fc + 4)
                e_l = get_column_letter(fc + 5)

                strains, stresses = [], []

                for rr, p in enumerate(s['points_courbe'], 2):
                    x = p['deplacement_mm']
                    force = p['force_newton']

                    if type_essai == 'flexion':
                        strain, stress = _deformation_contrainte(
                            type_essai, x, force,
                            portee_mm=portee, base_mm=base, hauteur_mm=hauteur,
                        )
                    else:
                        strain, stress = _deformation_contrainte(
                            type_essai, x, force,
                            l0_mm=l0_local, section_mm2=sec,
                        )

                    ws.cell(rr, ec).value = x
                    ws.cell(rr, fc).value = force

                    if type_essai == 'flexion':
                        ws.cell(rr, fc + 1).value = (
                            f'=6*{hauteur:.6g}*{ec_l}{rr}/{portee:.6g}^2'
                        )
                        ws.cell(rr, fc + 2).value = (
                            f'=3*{fc_l}{rr}*{portee:.6g}'
                            f'/(2*{base:.6g}*{hauteur:.6g}^2)'
                        )
                    else:
                        ws.cell(rr, fc + 1).value = f'={ec_l}{rr}/{l0_local:.6g}'
                        ws.cell(rr, fc + 2).value = f'={fc_l}{rr}/{sec_cell}'

                    strains.append(strain)
                    stresses.append(stress)

                if not stresses:
                    _log(f"  Éch. {ident} : aucun point, ignoré")
                    continue

                dernier_row = len(stresses) + 1
                cont_range = f'{cont_l}2:{cont_l}{dernier_row}'
                def_range = f'{def_l}2:{def_l}{dernier_row}'

                ws.cell(2, fc + 3).value = f'=MAX({cont_range})'
                ws.cell(2, fc + 4).value = (
                    f'=INDEX({def_range},MATCH({contmax_l}2,{cont_range},0))'
                )

                young, debut, taille = _young(strains, stresses)
                if young is not None:
                    r1 = debut + 2
                    r2 = r1 + taille - 1
                    ws.cell(2, fc + 5).value = (
                        f'=SLOPE({cont_l}{r1}:{cont_l}{r2},'
                        f'{def_l}{r1}:{def_l}{r2})'
                    )
                    _log(f"  Éch. {ident} : E lignes {r1}-{r2} ({taille} pts)")
                else:
                    ws.cell(2, fc + 5).value = None
                    _log(f"  Éch. {ident} : pas de fenêtre élastique")

                # ------------------------------------------------------------------
                # Graphique : nuage de points + tendance si zone élastique.
                # ------------------------------------------------------------------
                ch = ScatterChart()
                ch.title = ident
                ch.style = 13
                ch.x_axis.title = 'Déformation'
                ch.y_axis.title = 'Contrainte (MPa)'

                ch.height = 7.5
                ch.width = sum(
                    _largeur_col_cm(ws, colonne)
                    for colonne in range(ec, fc + 6)
                )

                ch.x_axis.delete = False
                ch.y_axis.delete = False

                if young is not None:
                    r1 = debut + 2
                    r2 = r1 + taille - 1
                    x_win = Reference(ws, min_col=fc + 1, min_row=r1,
                                      max_col=fc + 1, max_row=r2)
                    y_win = Reference(ws, min_col=fc + 2, min_row=r1,
                                      max_col=fc + 2, max_row=r2)
                    s_win = Series(y_win, x_win, title='Zone élastique')

                    s_win.marker = Marker(symbol='circle', size=5)
                    if s_win.marker.graphicalProperties is None:
                        s_win.marker.graphicalProperties = GraphicalProperties()
                    s_win.marker.graphicalProperties.solidFill = COULEUR_GRAPHE
                    s_win.marker.graphicalProperties.line = LineProperties(
                        solidFill=COULEUR_GRAPHE
                    )

                    if s_win.graphicalProperties is None:
                        s_win.graphicalProperties = GraphicalProperties()
                    s_win.graphicalProperties.line = LineProperties(noFill=True)

                    tl = Trendline(trendlineType='linear',
                                   dispRSqr=True, dispEq=True)
                    if tl.graphicalProperties is None:
                        tl.graphicalProperties = GraphicalProperties()
                    tl.graphicalProperties.line = LineProperties(
                        solidFill=COULEUR_GRAPHE, w=15000
                    )
                    s_win.trendline = tl
                    ch.series.append(s_win)

                else:
                    x_full = Reference(ws, min_col=fc + 1, min_row=2,
                                       max_col=fc + 1, max_row=dernier_row)
                    y_full = Reference(ws, min_col=fc + 2, min_row=2,
                                       max_col=fc + 2, max_row=dernier_row)
                    s_full = Series(y_full, x_full, title='Relevé complet')

                    s_full.marker = Marker(symbol='circle', size=5)
                    if s_full.marker.graphicalProperties is None:
                        s_full.marker.graphicalProperties = GraphicalProperties()
                    s_full.marker.graphicalProperties.solidFill = COULEUR_GRAPHE
                    s_full.marker.graphicalProperties.line = LineProperties(
                        solidFill=COULEUR_GRAPHE
                    )

                    if s_full.graphicalProperties is None:
                        s_full.graphicalProperties = GraphicalProperties()
                    s_full.graphicalProperties.line = LineProperties(noFill=True)

                    ch.series.append(s_full)

                ancre = OneCellAnchor(
                    _from=AnchorMarker(col=ec - 1, row=7),
                    ext=XDRPositiveSize2D(
                        cx=cm_to_EMU(ch.width),
                        cy=cm_to_EMU(ch.height),
                    ),
                )
                ws.add_chart(ch, ancre)
                # ------------------------------------------------------------------

                ix = max(range(len(stresses)), key=stresses.__getitem__)
                summaries.append({
                    'gamme': name,
                    'identifiant': ident,
                    'contmax_cell': f'{contmax_l}2',
                    'defrupt_cell': f'{defrupt_l}2',
                    'e_cell': f'{e_l}2',
                    'contmax_header': f'{contmax_l}1',
                    'defrupt_header': f'{defrupt_l}1',
                    'e_header': f'{e_l}1',
                })

            except Exception as e:
                _log(f"  Éch. {ident} : ERREUR ({type(e).__name__} : {e})")
                traceback.print_exc()

        # Le modèle place D_Moy Global juste après les colonnes D1-D3, Dmoy et S.
        # La moyenne porte sur les Dmoy individuels, jamais sur les sections S.
        if (
            diam is not None
            and dstart is not None
            and n_s > 0
            and type_essai in ('traction', 'compression')
            and forme_effective == 'cylindre'
        ):
            dm_l = get_column_letter(dstart + 3)
            global_col_idx = dstart + _OFFSET_S['cylindre'] + 1
            _set_cell(diam, 2, global_col_idx, 'D_Moy Global(mm)')
            diam.cell(3, global_col_idx).value = (
                f'=AVERAGE({dm_l}3:{dm_l}{2+n_s})'
            )

        try:
            nb_attendu = len(g['echantillons'])
            if len(ws._charts) > nb_attendu:
                del ws._charts[nb_attendu:]
        except Exception:
            pass

    _log("Construction RECAP...")
    rec = wb[RECAP_SHEET]
    try:
        rec._charts.clear()
    except Exception:
        pass
    if rec.max_row >= 1:
        try:
            rec.delete_rows(1, rec.max_row)
        except Exception:
            pass
    try:
        rec._charts.clear()
    except Exception:
        pass

    LARGEUR_BLOC = 5
    moyenne_cellules = {}
    ecart_cellules = {}
    derniere_ligne = 2

    for gi, g in enumerate(groups):
        nom = g['nom_gamme']
        items = [s for s in summaries if s['gamme'] == nom]
        if not items:
            continue

        nomq = "'" + nom.replace("'", "''") + "'"
        col_id = 2 + gi * LARGEUR_BLOC
        col_cm = col_id + 1
        col_dr = col_id + 2
        col_e = col_id + 3

        rec.cell(1, col_id).value = nom
        for c in (col_id, col_cm, col_dr, col_e):
            _safe_apply_fill(rec.cell(1, c), FILL_BLEU_EN_TETE)
            _safe_apply_font(rec.cell(1, c), FONT_GRAS)

        first = items[0]
        rec.cell(2, col_cm).value = f"={nomq}!{first['contmax_header']}"
        rec.cell(2, col_dr).value = f"={nomq}!{first['defrupt_header']}"
        rec.cell(2, col_e).value = f"={nomq}!{first['e_header']}"
        for c in (col_id, col_cm, col_dr, col_e):
            _safe_apply_fill(rec.cell(2, c), FILL_BLEU_EN_TETE)
            _safe_apply_font(rec.cell(2, c), FONT_GRAS)

        r = 3
        for it in items:
            rec.cell(r, col_id).value = it['identifiant']
            rec.cell(r, col_cm).value = f"={nomq}!{it['contmax_cell']}"
            rec.cell(r, col_dr).value = f"={nomq}!{it['defrupt_cell']}"
            rec.cell(r, col_e).value = f"={nomq}!{it['e_cell']}"
            r += 1
        dernier = r - 1
        row_moy = r
        row_std = r + 1

        for rr, lib in ((row_moy, 'MOYENNE'), (row_std, 'ECART-TYPE')):
            rec.cell(rr, col_id).value = lib
            for c in (col_id, col_cm, col_dr, col_e):
                _safe_apply_fill(rec.cell(rr, c), FILL_BLEU_TOTAL)
                _safe_apply_font(rec.cell(rr, c), FONT_GRAS)

        cm_l = get_column_letter(col_cm)
        dr_l = get_column_letter(col_dr)
        e_l = get_column_letter(col_e)

        rec.cell(row_moy, col_cm).value = f'=AVERAGE({cm_l}3:{cm_l}{dernier})'
        rec.cell(row_moy, col_dr).value = f'=AVERAGE({dr_l}3:{dr_l}{dernier})*100'
        rec.cell(row_moy, col_e).value = f'=AVERAGE({e_l}3:{e_l}{dernier})'
        rec.cell(row_std, col_cm).value = f'=_xlfn.STDEV.S({cm_l}3:{cm_l}{dernier})'
        rec.cell(row_std, col_dr).value = f'=_xlfn.STDEV.S({dr_l}3:{dr_l}{dernier})*100'
        rec.cell(row_std, col_e).value = f'=_xlfn.STDEV.S({e_l}3:{e_l}{dernier})'

        moyenne_cellules[(nom, 'contmax')] = f'{cm_l}{row_moy}'
        moyenne_cellules[(nom, 'defrupt')] = f'{dr_l}{row_moy}'
        moyenne_cellules[(nom, 'e')] = f'{e_l}{row_moy}'
        ecart_cellules[(nom, 'contmax')] = f'{cm_l}{row_std}'
        ecart_cellules[(nom, 'defrupt')] = f'{dr_l}{row_std}'
        ecart_cellules[(nom, 'e')] = f'{e_l}{row_std}'

        derniere_ligne = max(derniere_ligne, row_std)

    noms = [g['nom_gamme'] for g in groups
            if any(s['gamme'] == g['nom_gamme'] for s in summaries)]
    n_g = len(noms)
    if n_g:
        largeur = n_g + 2
        row_titre = derniere_ligne + 3
        row_moy2 = row_titre + 1
        row_std2 = row_titre + 2

        blocs = []
        for mi, (libelle, cle, titre_g, titre_y) in enumerate((
            ('Cont(max)', 'contmax', 'CONTRAINTE MAXIMALE DES FIBRES',
             'Contrainte Max (MPa)'),
            ('Def rupt', 'defrupt', 'DEFORMATION A LA RUPTURE DES FIBRES',
             'Deformation Rupt (%)'),
            ('E(mpa)', 'e', "MODULE D'YOUNG DES FIBRES", 'E(MPa)'),
        )):
            debut = 1 + mi * largeur
            rec.cell(row_titre, debut).value = libelle
            for c in range(debut, debut + 1 + n_g):
                _safe_apply_fill(rec.cell(row_titre, c), FILL_BLEU_EN_TETE)
                _safe_apply_font(rec.cell(row_titre, c), FONT_GRAS)
            for gi_, nom in enumerate(noms):
                rec.cell(row_titre, debut + 1 + gi_).value = nom
            for rr, lib in ((row_moy2, 'MOYENNE'), (row_std2, 'ECART-TYPE')):
                rec.cell(rr, debut).value = lib
                for c in range(debut, debut + 1 + n_g):
                    _safe_apply_fill(rec.cell(rr, c), FILL_BLEU_TOTAL)
                    _safe_apply_font(rec.cell(rr, c), FONT_GRAS)
            for gi_, nom in enumerate(noms):
                col = debut + 1 + gi_
                if (nom, cle) in moyenne_cellules:
                    rec.cell(row_moy2, col).value = f'={moyenne_cellules[(nom, cle)]}'
                    rec.cell(row_std2, col).value = f'={ecart_cellules[(nom, cle)]}'
                    rec.cell(row_moy2, col).number_format = '0.000'
                    rec.cell(row_std2, col).number_format = '0.000'
            blocs.append((debut, titre_g, titre_y))

        row_graph = row_std2 + 2
        bord_droit_cm = None
        for debut, titre_g, titre_y in blocs:
            chart = BarChart()
            chart.type = 'col'
            data_ref = Reference(rec,
                                 min_col=debut + 1, max_col=debut + n_g,
                                 min_row=row_moy2, max_row=row_moy2)
            cats = Reference(rec,
                             min_col=debut + 1, max_col=debut + n_g,
                             min_row=row_titre, max_row=row_titre)
            chart.add_data(data_ref, titles_from_data=False, from_rows=True)
            chart.set_categories(cats)
            _safe_style_bar(chart.series)
            try:
                _style_barres_recap(chart, titre_g, titre_y)
            except Exception as e:
                _log(f"style histogramme récap : {e}")
            col = debut
            if bord_droit_cm is not None:
                while sum(_largeur_col_cm(rec, k)
                          for k in range(1, col)) < bord_droit_cm + 0.3:
                    col += 1
            bord_droit_cm = (
                sum(_largeur_col_cm(rec, k) for k in range(1, col)) + chart.width
            )
            rec.add_chart(chart, f'{get_column_letter(col)}{row_graph}')

    try:
        rec_final = wb[RECAP_SHEET]
        wb._sheets.remove(rec_final)
        wb._sheets.append(rec_final)
        _log(f"Récap déplacé en dernière position (index {len(wb.sheetnames) - 1})")
    except Exception as e:
        _log(f"déplacement du récap : {e}")

    try:
        wb.calculation.fullCalcOnLoad = True
        wb.calculation.forceFullCalc = True
        wb.calculation.calcMode = 'auto'
    except Exception as e:
        _log(f"recalcul : {e}")

    # --- Metadonnees du fichier (info-bulle "Auteur") ---
    try:
        wb.properties.creator = "PycnoLab"
        wb.properties.lastModifiedBy = "PycnoLab"
    except Exception as e:
        _log(f"metadonnees : {e}")

    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    wb.save(out)
    _log(f"Fichier écrit : {out.resolve()}")
    return out


def _energie_rupture(deplacements_mm, forces_n, jusqu_index):
    if jusqu_index < 1:
        return 0.0
    energie = 0.0
    for i in range(1, jusqu_index + 1):
        dx_m = (deplacements_mm[i] - deplacements_mm[i - 1]) / 1000.0
        energie += 0.5 * (forces_n[i] + forces_n[i - 1]) * dx_m
    return energie


def analyser_resultats(data, l0_mm=20.0):
    type_essai = data.get('type_essai', 'traction')
    geometrie_flexion = data.get('geometrie_flexion')
    gammes_resultats = []

    for g in data['gammes']:
        nom_gamme = g['nom_gamme']
        ech_res = []
        for s in g['echantillons']:
            ident = s['identifiant']
            if type_essai == 'traction':
                sec = s['section_mm2']
                l0_local = l0_mm
                portee = base = hauteur = None
            elif type_essai == 'compression':
                sec = s['section_mm2']
                l0_local = s['l0_mm']
                portee = base = hauteur = None
            elif type_essai == 'flexion':
                sec = None
                l0_local = None
                portee, base, hauteur = _geometrie_flexion_pour_ech(
                    geometrie_flexion, nom_gamme, ident
                )
            else:
                continue

            strains, stresses = [], []
            deplacements = [p['deplacement_mm'] for p in s['points_courbe']]
            forces = [p['force_newton'] for p in s['points_courbe']]
            for p in s['points_courbe']:
                if type_essai == 'flexion':
                    strain, stress = _deformation_contrainte(
                        type_essai, p['deplacement_mm'], p['force_newton'],
                        portee_mm=portee, base_mm=base, hauteur_mm=hauteur,
                    )
                else:
                    strain, stress = _deformation_contrainte(
                        type_essai, p['deplacement_mm'], p['force_newton'],
                        l0_mm=l0_local, section_mm2=sec,
                    )
                strains.append(strain)
                stresses.append(stress)

            if not stresses:
                continue

            ix = max(range(len(stresses)), key=stresses.__getitem__)
            young, debut, taille = _young(strains, stresses)
            limite = stresses[debut + taille - 1] if debut is not None else None
            ech_res.append({
                'identifiant': ident,
                'contrainte_rupture_mpa': stresses[ix],
                'deformation_rupture_pourcent': strains[ix],
                'module_young_mpa': young,
                'energie_rupture_joule': _energie_rupture(deplacements, forces, ix),
                'limite_elastique_mpa': limite,
                'points_courbe': [
                    {'deplacement_mm': d, 'force_newton': f}
                    for d, f in zip(deplacements, forces)
                ],
            })

        if not ech_res:
            continue

        def _vals(cle):
            return [e[cle] for e in ech_res if e[cle] is not None]

        def _moy(cle):
            v = _vals(cle)
            return sum(v) / len(v) if v else None

        def _std(cle):
            v = _vals(cle)
            m = _moy(cle)
            if len(v) < 2 or m is None:
                return 0.0
            return math.sqrt(sum((x - m) ** 2 for x in v) / len(v))

        gammes_resultats.append({
            'nom_gamme': nom_gamme,
            'echantillons': ech_res,
            'resistance_moyenne_mpa': _moy('contrainte_rupture_mpa'),
            'ecart_type_mpa': _std('contrainte_rupture_mpa'),
            'deformation_moyenne_pourcent': _moy('deformation_rupture_pourcent'),
            'ecart_type_deformation_pourcent': _std('deformation_rupture_pourcent'),
            'module_young_moyen_mpa': _moy('module_young_mpa'),
            'ecart_type_module_young_mpa': _std('module_young_mpa'),
            'energie_rupture_moyenne_joule': _moy('energie_rupture_joule'),
            'limite_elastique_moyenne_mpa': _moy('limite_elastique_mpa'),
        })

    return {'type_essai': type_essai, 'gammes': gammes_resultats}
