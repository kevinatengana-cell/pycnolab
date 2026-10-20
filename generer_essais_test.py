"""
Génère des fichiers Excel synthétiques pour tester PycnoLab
sur les 6 géométries supportées.

Les fichiers sont écrits dans essais/bruts/.
Chaque fichier contient :
  - une feuille DIMENSIONS (ou DIAMETRE pour compat)
  - une feuille GAMME_<forme> avec les courbes Elong/Force

Usage :
    python generer_essais_test.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment

random.seed(42)   # reproductibilité

DOSSIER_SORTIE = Path(__file__).parent / 'essais' / 'bruts'
DOSSIER_SORTIE.mkdir(parents=True, exist_ok=True)

POLICE = 'Times New Roman'
FONT_TITRE = Font(name=POLICE, size=12, bold=True, color='1F3864')
FONT_EN_TETE = Font(name=POLICE, size=11, bold=True, color='1F3864')
FONT_NORMAL = Font(name=POLICE, size=11)
FILL_EN_TETE = PatternFill('solid', fgColor='BDD7EE')
ALIGN_CENTRE = Alignment(horizontal='center', vertical='center')


# ---------------------------------------------------------------------------
# Génération des courbes physiquement plausibles
# ---------------------------------------------------------------------------

def generer_courbe_traction(
    force_max_n: float,
    deplacement_rupture_mm: float,
    module_mpa: float,
    l0_mm: float,
    section_mm2: float,
    n_points: int = 30,
) -> list[tuple[float, float]]:
    """Génère une courbe force/déplacement de traction plausible.

    Comportement : zone élastique linéaire, plateau plastique, rupture.
    """
    # Déplacement à la limite élastique (0.2% de L0)
    eps_y = 0.002
    f_y = section_mm2 * module_mpa * eps_y
    f_y = min(f_y, force_max_n * 0.85)
    deplacement_y = eps_y * l0_mm

    points = []
    for i in range(n_points):
        t = i / (n_points - 1)
        if t * deplacement_rupture_mm <= deplacement_y:
            # Zone élastique
            force = f_y * (t * deplacement_rupture_mm / deplacement_y)
        else:
            # Zone plastique puis rupture douce
            u = (t * deplacement_rupture_mm - deplacement_y) / (
                deplacement_rupture_mm - deplacement_y
            )
            force = f_y + (force_max_n - f_y) * (1 - (1 - u) ** 2)
            if u > 0.95:
                force *= (1 - (u - 0.95) * 15)   # chute à la rupture
        # Bruit d'acquisition léger
        force *= 1 + random.uniform(-0.005, 0.005)
        points.append((round(t * deplacement_rupture_mm, 3),
                       round(max(force, 0), 3)))
    return points


def generer_courbe_compression(
    force_max_n: float,
    deplacement_rupture_mm: float,
    module_mpa: float,
    l0_mm: float,
    section_mm2: float,
    n_points: int = 30,
) -> list[tuple[float, float]]:
    """Génère une courbe force/déplacement de compression plausible."""
    eps_y = 0.002
    f_y = section_mm2 * module_mpa * eps_y
    f_y = min(f_y, force_max_n * 0.9)
    deplacement_y = eps_y * l0_mm

    points = []
    for i in range(n_points):
        t = i / (n_points - 1)
        d = t * deplacement_rupture_mm
        if d <= deplacement_y:
            force = f_y * (d / deplacement_y)
        else:
            u = (d - deplacement_y) / (deplacement_rupture_mm - deplacement_y)
            force = f_y + (force_max_n - f_y) * (1 - (1 - u) ** 3)
        force *= 1 + random.uniform(-0.005, 0.005)
        points.append((round(d, 3), round(max(force, 0), 3)))
    return points


def generer_courbe_flexion(
    force_max_n: float,
    deplacement_rupture_mm: float,
    rigidite_n_par_mm: float,
    n_points: int = 25,
) -> list[tuple[float, float]]:
    """Génère une courbe force/déplacement de flexion 3 points."""
    points = []
    for i in range(n_points):
        t = i / (n_points - 1)
        d = t * deplacement_rupture_mm
        # Rigidité décroissante puis rupture brutale
        if t < 0.85:
            force = rigidite_n_par_mm * d
        else:
            force = rigidite_n_par_mm * deplacement_rupture_mm * 0.85
            force *= (1 - (t - 0.85) / 0.15)   # chute brutale
        force *= 1 + random.uniform(-0.01, 0.01)
        points.append((round(d, 3), round(max(force, 0), 3)))
    return points


# ---------------------------------------------------------------------------
# Écriture des feuilles
# ---------------------------------------------------------------------------

def _entete_dimensions(ws, titre, colonnes):
    """Écrit un bloc d'en-tête dans la feuille de dimensions."""
    ws.cell(1, 1).value = titre
    ws.cell(1, 1).font = FONT_TITRE
    ws.cell(2, 1).value = 'Identifiant'
    ws.cell(2, 1).font = FONT_EN_TETE
    ws.cell(2, 1).fill = FILL_EN_TETE
    ws.cell(2, 1).alignment = ALIGN_CENTRE
    for j, col in enumerate(colonnes, start=2):
        c = ws.cell(2, j, col)
        c.font = FONT_EN_TETE
        c.fill = FILL_EN_TETE
        c.alignment = ALIGN_CENTRE


def _ecrire_dimensions(ws, echantillons, colonnes):
    """Écrit les lignes d'échantillons dans la feuille de dimensions."""
    for i, (ident, valeurs) in enumerate(echantillons, start=3):
        ws.cell(i, 1).value = ident
        ws.cell(i, 1).font = FONT_NORMAL
        for j, v in enumerate(valeurs, start=2):
            c = ws.cell(i, j, v)
            c.font = FONT_NORMAL


def _ecrire_gamme(ws, nom_gamme, echantillons):
    """Écrit une feuille de gamme : un bloc Elong/Force par échantillon."""
    col = 1
    for ident, points in echantillons:
        # En-têtes du bloc
        ws.cell(1, col).value = f'Elong.(mm) - {nom_gamme} {ident}'
        ws.cell(1, col + 1).value = f'Force(N) - {nom_gamme} {ident}'
        for j in (0, 1):
            c = ws.cell(1, col + j)
            c.font = FONT_EN_TETE
            c.fill = FILL_EN_TETE
            c.alignment = ALIGN_CENTRE
        # Points
        for r, (d, f) in enumerate(points, start=2):
            ws.cell(r, col).value = d
            ws.cell(r, col + 1).value = f
        col += 3   # une colonne vide entre les blocs


# ---------------------------------------------------------------------------
# Générateurs de fichiers
# ---------------------------------------------------------------------------

def _workbook_vierge():
    wb = Workbook()
    wb.remove(wb.active)
    return wb


def generer_cylindre():
    """Traction — fibre cylindrique (diamètre ~0.2 mm)."""
    wb = _workbook_vierge()
    ws_dim = wb.create_sheet('DIMENSIONS')
    _entete_dimensions(ws_dim, 'DIMENSION CYLINDRE',
                       ['D_1(mm)', 'D_2(mm)', 'D_3(mm)',
                        'D_Moy(mm)', 'S_(mm2)'])

    diametres = [
        (0.205, 0.210, 0.208),
        (0.164, 0.166, 0.165),
        (0.310, 0.305, 0.308),
    ]
    echantillons_dim = []
    for i, (d1, d2, d3) in enumerate(diametres, 1):
        d_moy = (d1 + d2 + d3) / 3
        section = math.pi * (d_moy / 2) ** 2
        echantillons_dim.append((f'ECH{i}', [d1, d2, d3, d_moy, section]))
    _ecrire_dimensions(ws_dim, echantillons_dim,
                       ['D_1(mm)', 'D_2(mm)', 'D_3(mm)',
                        'D_Moy(mm)', 'S_(mm2)'])

    ws_gamme = wb.create_sheet('GAMME_CYLINDRE')
    echantillons_gamme = []
    for i, (d1, d2, d3) in enumerate(diametres, 1):
        d_moy = (d1 + d2 + d3) / 3
        section = math.pi * (d_moy / 2) ** 2
        points = generer_courbe_traction(
            force_max_n=8.0 + i,
            deplacement_rupture_mm=1.2 + 0.1 * i,
            module_mpa=15000,
            l0_mm=20.0,
            section_mm2=section,
        )
        echantillons_gamme.append((f'ECH{i}', points))
    _ecrire_gamme(ws_gamme, 'GAMME_CYLINDRE', echantillons_gamme)

    chemin = DOSSIER_SORTIE / 'TEST_CYLINDRE.xlsx'
    wb.save(chemin)
    print(f'  {chemin.name}')


def generer_rectangle():
    """Traction — éprouvette rectangulaire."""
    wb = _workbook_vierge()
    ws_dim = wb.create_sheet('DIMENSIONS')
    colonnes = ['L_1(mm)', 'L_2(mm)', 'L_3(mm)',
                'E_1(mm)', 'E_2(mm)', 'E_3(mm)',
                'L_Moy(mm)', 'E_Moy(mm)', 'S_(mm2)']
    _entete_dimensions(ws_dim, 'DIMENSION RECTANGLE', colonnes)

    mesures = [
        (10.0, 10.1, 9.9, 4.0, 4.1, 4.0),
        (12.0, 12.1, 11.9, 5.0, 5.1, 5.0),
        (8.0, 8.1, 8.0, 3.0, 3.1, 3.0),
    ]
    echantillons_dim = []
    for i, (l1, l2, l3, e1, e2, e3) in enumerate(mesures, 1):
        l_moy = (l1 + l2 + l3) / 3
        e_moy = (e1 + e2 + e3) / 3
        section = l_moy * e_moy
        echantillons_dim.append(
            (f'ECH{i}', [l1, l2, l3, e1, e2, e3, l_moy, e_moy, section])
        )
    _ecrire_dimensions(ws_dim, echantillons_dim, colonnes)

    ws_gamme = wb.create_sheet('GAMME_RECTANGLE')
    echantillons_gamme = []
    for i, (l1, l2, l3, e1, e2, e3) in enumerate(mesures, 1):
        l_moy = (l1 + l2 + l3) / 3
        e_moy = (e1 + e2 + e3) / 3
        section = l_moy * e_moy
        points = generer_courbe_traction(
            force_max_n=400 + 50 * i,
            deplacement_rupture_mm=8.0 + i,
            module_mpa=2000,
            l0_mm=50.0,
            section_mm2=section,
        )
        echantillons_gamme.append((f'ECH{i}', points))
    _ecrire_gamme(ws_gamme, 'GAMME_RECTANGLE', echantillons_gamme)

    chemin = DOSSIER_SORTIE / 'TEST_RECTANGLE.xlsx'
    wb.save(chemin)
    print(f'  {chemin.name}')


def generer_carre():
    """Traction — éprouvette carrée."""
    wb = _workbook_vierge()
    ws_dim = wb.create_sheet('DIMENSIONS')
    colonnes = ['C_1(mm)', 'C_2(mm)', 'C_3(mm)', 'C_Moy(mm)', 'S_(mm2)']
    _entete_dimensions(ws_dim, 'DIMENSION CARRE', colonnes)

    mesures = [
        (10.0, 10.1, 9.9),
        (15.0, 15.1, 14.9),
        (20.0, 20.1, 19.9),
    ]
    echantillons_dim = []
    for i, (c1, c2, c3) in enumerate(mesures, 1):
        c_moy = (c1 + c2 + c3) / 3
        section = c_moy ** 2
        echantillons_dim.append((f'ECH{i}', [c1, c2, c3, c_moy, section]))
    _ecrire_dimensions(ws_dim, echantillons_dim, colonnes)

    ws_gamme = wb.create_sheet('GAMME_CARRE')
    echantillons_gamme = []
    for i, (c1, c2, c3) in enumerate(mesures, 1):
        c_moy = (c1 + c2 + c3) / 3
        section = c_moy ** 2
        points = generer_courbe_traction(
            force_max_n=800 + 100 * i,
            deplacement_rupture_mm=6.0 + i,
            module_mpa=3000,
            l0_mm=40.0,
            section_mm2=section,
        )
        echantillons_gamme.append((f'ECH{i}', points))
    _ecrire_gamme(ws_gamme, 'GAMME_CARRE', echantillons_gamme)

    chemin = DOSSIER_SORTIE / 'TEST_CARRE.xlsx'
    wb.save(chemin)
    print(f'  {chemin.name}')


def generer_tube_circulaire():
    """Traction — tube circulaire."""
    wb = _workbook_vierge()
    ws_dim = wb.create_sheet('DIMENSIONS')
    colonnes = ['D_ext_1(mm)', 'D_ext_2(mm)', 'D_ext_3(mm)',
                'D_int_1(mm)', 'D_int_2(mm)', 'D_int_3(mm)',
                'D_ext_Moy(mm)', 'D_int_Moy(mm)', 'S_(mm2)']
    _entete_dimensions(ws_dim, 'DIMENSION TUBE CIRCULAIRE', colonnes)

    mesures = [
        (12.0, 12.1, 11.9, 8.0, 8.1, 7.9),
        (15.0, 15.1, 14.9, 10.0, 10.1, 9.9),
        (20.0, 20.1, 19.9, 14.0, 14.1, 13.9),
    ]
    echantillons_dim = []
    for i, (de1, de2, de3, di1, di2, di3) in enumerate(mesures, 1):
        de_moy = (de1 + de2 + de3) / 3
        di_moy = (di1 + di2 + di3) / 3
        section = math.pi * (de_moy ** 2 - di_moy ** 2) / 4
        echantillons_dim.append(
            (f'ECH{i}',
             [de1, de2, de3, di1, di2, di3, de_moy, di_moy, section])
        )
    _ecrire_dimensions(ws_dim, echantillons_dim, colonnes)

    ws_gamme = wb.create_sheet('GAMME_TUBE_CIRCULAIRE')
    echantillons_gamme = []
    for i, (de1, de2, de3, di1, di2, di3) in enumerate(mesures, 1):
        de_moy = (de1 + de2 + de3) / 3
        di_moy = (di1 + di2 + di3) / 3
        section = math.pi * (de_moy ** 2 - di_moy ** 2) / 4
        points = generer_courbe_traction(
            force_max_n=500 + 50 * i,
            deplacement_rupture_mm=5.0 + i,
            module_mpa=200000,
            l0_mm=50.0,
            section_mm2=section,
        )
        echantillons_gamme.append((f'ECH{i}', points))
    _ecrire_gamme(ws_gamme, 'GAMME_TUBE_CIRCULAIRE', echantillons_gamme)

    chemin = DOSSIER_SORTIE / 'TEST_TUBE_CIRCULAIRE.xlsx'
    wb.save(chemin)
    print(f'  {chemin.name}')


def generer_tube_rectangulaire():
    """Traction — tube rectangulaire."""
    wb = _workbook_vierge()
    ws_dim = wb.create_sheet('DIMENSIONS')
    colonnes = ['B_1(mm)', 'B_2(mm)', 'B_3(mm)',
                'H_1(mm)', 'H_2(mm)', 'H_3(mm)',
                'b_1(mm)', 'b_2(mm)', 'b_3(mm)',
                'h_1(mm)', 'h_2(mm)', 'h_3(mm)',
                'B_Moy(mm)', 'H_Moy(mm)', 'b_Moy(mm)', 'h_Moy(mm)',
                'S_(mm2)']
    _entete_dimensions(ws_dim, 'DIMENSION TUBE RECTANGULAIRE', colonnes)

    mesures = [
        (20.0, 20.1, 19.9, 10.0, 10.1, 9.9, 14.0, 14.1, 13.9, 6.0, 6.1, 5.9),
        (25.0, 25.1, 24.9, 12.0, 12.1, 11.9, 18.0, 18.1, 17.9, 7.0, 7.1, 6.9),
        (30.0, 30.1, 29.9, 15.0, 15.1, 14.9, 22.0, 22.1, 21.9, 9.0, 9.1, 8.9),
    ]
    echantillons_dim = []
    for i, vals in enumerate(mesures, 1):
        B = sum(vals[0:3]) / 3
        H = sum(vals[3:6]) / 3
        b = sum(vals[6:9]) / 3
        h = sum(vals[9:12]) / 3
        section = B * H - b * h
        echantillons_dim.append(
            (f'ECH{i}', list(vals) + [B, H, b, h, section])
        )
    _ecrire_dimensions(ws_dim, echantillons_dim, colonnes)

    ws_gamme = wb.create_sheet('GAMME_TUBE_RECTANGULAIRE')
    echantillons_gamme = []
    for i, vals in enumerate(mesures, 1):
        B = sum(vals[0:3]) / 3
        H = sum(vals[3:6]) / 3
        b = sum(vals[6:9]) / 3
        h = sum(vals[9:12]) / 3
        section = B * H - b * h
        points = generer_courbe_traction(
            force_max_n=1500 + 200 * i,
            deplacement_rupture_mm=4.0 + i,
            module_mpa=200000,
            l0_mm=100.0,
            section_mm2=section,
        )
        echantillons_gamme.append((f'ECH{i}', points))
    _ecrire_gamme(ws_gamme, 'GAMME_TUBE_RECTANGULAIRE', echantillons_gamme)

    chemin = DOSSIER_SORTIE / 'TEST_TUBE_RECTANGULAIRE.xlsx'
    wb.save(chemin)
    print(f'  {chemin.name}')


def generer_surface():
    """Traction — section quelconque."""
    wb = _workbook_vierge()
    ws_dim = wb.create_sheet('DIMENSIONS')
    colonnes = ['S_1(mm2)', 'S_2(mm2)', 'S_3(mm2)', 'S_Moy(mm2)']
    _entete_dimensions(ws_dim, 'DIMENSION SURFACE', colonnes)

    mesures = [
        (30.0, 30.5, 29.8),
        (42.0, 41.7, 42.2),
        (55.0, 54.5, 55.4),
    ]
    echantillons_dim = []
    for i, (s1, s2, s3) in enumerate(mesures, 1):
        s_moy = (s1 + s2 + s3) / 3
        echantillons_dim.append((f'ECH{i}', [s1, s2, s3, s_moy]))
    _ecrire_dimensions(ws_dim, echantillons_dim, colonnes)

    ws_gamme = wb.create_sheet('GAMME_SURFACE')
    echantillons_gamme = []
    for i, (s1, s2, s3) in enumerate(mesures, 1):
        s_moy = (s1 + s2 + s3) / 3
        points = generer_courbe_traction(
            force_max_n=300 + 50 * i,
            deplacement_rupture_mm=10.0 + i,
            module_mpa=1000,
            l0_mm=40.0,
            section_mm2=s_moy,
        )
        echantillons_gamme.append((f'ECH{i}', points))
    _ecrire_gamme(ws_gamme, 'GAMME_SURFACE', echantillons_gamme)

    chemin = DOSSIER_SORTIE / 'TEST_SURFACE.xlsx'
    wb.save(chemin)
    print(f'  {chemin.name}')


def generer_compression_avec_dimensions():
    """Compression — cylindre avec feuille DIMENSIONS."""
    wb = _workbook_vierge()
    ws_dim = wb.create_sheet('DIMENSIONS')
    colonnes = ['D_1(mm)', 'D_2(mm)', 'D_3(mm)',
                'D_Moy(mm)', 'S_(mm2)']
    _entete_dimensions(ws_dim, 'DIMENSION COMPRESSION CYLINDRE', colonnes)

    diametres = [
        (46.2, 46.1, 46.3),
        (46.0, 46.1, 45.9),
        (46.5, 46.4, 46.6),
    ]
    echantillons_dim = []
    for i, (d1, d2, d3) in enumerate(diametres, 1):
        d_moy = (d1 + d2 + d3) / 3
        section = math.pi * (d_moy / 2) ** 2
        echantillons_dim.append((f'ECH{i}', [d1, d2, d3, d_moy, section]))
    _ecrire_dimensions(ws_dim, echantillons_dim, colonnes)

    ws_gamme = wb.create_sheet('GAMME_CYLINDRE')
    echantillons_gamme = []
    for i, (d1, d2, d3) in enumerate(diametres, 1):
        d_moy = (d1 + d2 + d3) / 3
        section = math.pi * (d_moy / 2) ** 2
        points = generer_courbe_compression(
            force_max_n=50000 + 5000 * i,
            deplacement_rupture_mm=3.0 + 0.3 * i,
            module_mpa=30000,
            l0_mm=20.0,
            section_mm2=section,
        )
        echantillons_gamme.append((f'ECH{i}', points))
    _ecrire_gamme(ws_gamme, 'GAMME_CYLINDRE', echantillons_gamme)

    chemin = DOSSIER_SORTIE / 'TEST_COMPRESSION_CYLINDRE.xlsx'
    wb.save(chemin)
    print(f'  {chemin.name}')


def generer_flexion_avec_dimensions():
    """Flexion 3 points — rectangle avec feuille DIMENSIONS."""
    wb = _workbook_vierge()
    ws_dim = wb.create_sheet('DIMENSIONS')
    colonnes = ['L_1(mm)', 'L_2(mm)', 'L_3(mm)',
                'E_1(mm)', 'E_2(mm)', 'E_3(mm)',
                'L_Moy(mm)', 'E_Moy(mm)', 'S_(mm2)']
    _entete_dimensions(ws_dim, 'DIMENSION FLEXION RECTANGLE', colonnes)

    mesures = [
        (20.0, 20.1, 19.9, 10.0, 10.1, 9.9),
        (25.0, 25.1, 24.9, 12.0, 12.1, 11.9),
        (30.0, 30.1, 29.9, 15.0, 15.1, 14.9),
    ]
    echantillons_dim = []
    for i, (l1, l2, l3, e1, e2, e3) in enumerate(mesures, 1):
        l_moy = (l1 + l2 + l3) / 3
        e_moy = (e1 + e2 + e3) / 3
        section = l_moy * e_moy
        echantillons_dim.append(
            (f'ECH{i}', [l1, l2, l3, e1, e2, e3, l_moy, e_moy, section])
        )
    _ecrire_dimensions(ws_dim, echantillons_dim, colonnes)

    ws_gamme = wb.create_sheet('GAMME_RECTANGLE')
    echantillons_gamme = []
    for i, (l1, l2, l3, e1, e2, e3) in enumerate(mesures, 1):
        points = generer_courbe_flexion(
            force_max_n=2000 + 300 * i,
            deplacement_rupture_mm=5.0 + 0.5 * i,
            rigidite_n_par_mm=400 + 50 * i,
        )
        echantillons_gamme.append((f'ECH{i}', points))
    _ecrire_gamme(ws_gamme, 'GAMME_RECTANGLE', echantillons_gamme)

    chemin = DOSSIER_SORTIE / 'TEST_FLEXION_RECTANGLE.xlsx'
    wb.save(chemin)
    print(f'  {chemin.name}')


# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------

def main():
    print(f'Génération des fichiers de test dans {DOSSIER_SORTIE}…\n')

    print('Traction :')
    generer_cylindre()
    generer_rectangle()
    generer_carre()
    generer_tube_circulaire()
    generer_tube_rectangulaire()
    generer_surface()

    print('\nCompression :')
    generer_compression_avec_dimensions()

    print('\nFlexion :')
    generer_flexion_avec_dimensions()

    print(f'\nTerminé. Fichiers écrits dans {DOSSIER_SORTIE.resolve()}')


if __name__ == '__main__':
    main()