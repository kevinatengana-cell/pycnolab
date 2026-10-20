import os
import re
import math
import pandas as pd
from openpyxl import load_workbook
from typing import List, Dict, Any, Optional

ALIAS_COLONNES = {
    'identifiant': ['identifiant', 'echantillon', 'id', 'code', 'ech'],
    'largeur': ['largeur_mm', 'largeur', 'b', 'b_mm', 'largeur (mm)'],
    'epaisseur': ['epaisseur_mm', 'epaisseur', 'h', 'h_mm', 'epaisseur (mm)', 'e'],
    'longueur': ['longueur_initiale_mm', 'longueur', 'l0', 'l0_mm', 'longueur (mm)'],
    'force': ['force_rupture_newton', 'force_n', 'f_max', 'force', 'force (n)'],
    'deplacement': ['deplacement_rupture_mm', 'deplacement_mm', 'dl', 'deplacement']
}


# ---------------------------------------------------------------------------
# Feuille de dimensions : support multi-formes
# ---------------------------------------------------------------------------

# Ordre volontaire : du plus spécifique au plus général.
# Le tube rectangulaire est testé avant les autres car, après normalisation,
# b_1 et B_1 deviennent identiques ; seul le tube rectangulaire comporte deux
# triplets B/H dans la même signature.
_FORMES_BLOCS = {
    'tube_rectangulaire': [
        'B1', 'B2', 'B3',
        'H1', 'H2', 'H3',
        'B1', 'B2', 'B3',
        'H1', 'H2', 'H3',
    ],
    'tube_circulaire': [
        'DEXT1', 'DEXT2', 'DEXT3',
        'DINT1', 'DINT2', 'DINT3',
    ],
    'rectangle': [
        'L1', 'L2', 'L3',
        'E1', 'E2', 'E3',
    ],
    'carre': ['C1', 'C2', 'C3'],
    'cylindre': ['D1', 'D2', 'D3'],
    'surface': ['S1', 'S2', 'S3'],
}

# Noms de colonnes brutes par forme (pour reconstituer un dict lisible).
_NOMS_COLONNES = {
    'cylindre':           ['D_1', 'D_2', 'D_3'],
    'rectangle':          ['L_1', 'L_2', 'L_3', 'E_1', 'E_2', 'E_3'],
    'carre':              ['C_1', 'C_2', 'C_3'],
    'tube_circulaire':    ['D_ext_1', 'D_ext_2', 'D_ext_3',
                           'D_int_1', 'D_int_2', 'D_int_3'],
    'tube_rectangulaire': ['B_1', 'B_2', 'B_3', 'H_1', 'H_2', 'H_3',
                           'b_1', 'b_2', 'b_3', 'h_1', 'h_2', 'h_3'],
    'surface':            ['S_1', 'S_2', 'S_3'],
}

_FORMES_VALIDES = tuple(_FORMES_BLOCS.keys())

# Formes compatibles avec la flexion 3 points (section rectangulaire ou carrée).
_FORMES_FLEXION = ('rectangle', 'carre')


def _trouver_colonne(df_cols: List[Any], clé: str) -> Optional[str]:
    cols_clean = {str(c).strip().lower(): str(c) for c in df_cols}
    for synonyme in ALIAS_COLONNES[clé]:
        if synonyme in cols_clean:
            return cols_clean[synonyme]
    return None


def _convertir_en_float(valeur: Any) -> Optional[float]:
    """Nettoie et convertit une valeur en float (gère les virgules et espaces)."""
    if pd.isna(valeur) or valeur is None:
        return None
    try:
        val_str = str(valeur).strip().replace(',', '.')
        return float(val_str)
    except (ValueError, TypeError):
        return None


def _charger_dataframe(chemin_fichier: str, sheet_name: Optional[str] = None) -> pd.DataFrame:
    """Charge dynamiquement un fichier Excel ou CSV."""
    if not os.path.exists(chemin_fichier):
        raise FileNotFoundError(f"Le fichier spécifié est introuvable : {chemin_fichier}")

    extension = os.path.splitext(chemin_fichier)[1].lower()

    if extension == '.csv':
        try:
            df = pd.read_csv(chemin_fichier, sep=';', decimal=',')
            if len(df.columns) > 1:
                return df
        except Exception:
            pass
        return pd.read_csv(chemin_fichier, sep=',', decimal='.')

    elif extension in ['.xlsx', '.xls']:
        if sheet_name:
            return pd.read_excel(chemin_fichier, sheet_name=sheet_name, header=None)
        return pd.read_excel(chemin_fichier, header=None)

    else:
        raise ValueError(f"Extension de fichier non supportée : {extension}")


def _extraire_donnees_courbe(feuille: pd.DataFrame, col_debut: int,
                             n_lignes: int = 330) -> List[Dict[str, float]]:
    points = []

    for i in range(1, n_lignes):
        if col_debut >= len(feuille.columns) or col_debut + 1 >= len(feuille.columns):
            break

        elong_val = feuille.iloc[i, col_debut] if col_debut < len(feuille.columns) else None
        force_val = feuille.iloc[i, col_debut + 1] if col_debut + 1 < len(feuille.columns) else None

        elong = _convertir_en_float(elong_val)
        force = _convertir_en_float(force_val)

        if elong is not None and force is not None and force > 0:
            points.append({
                "deplacement": elong,
                "force": force
            })

    return points


def _identifier_blocs_courbe(feuille: pd.DataFrame) -> List[Dict[str, Any]]:
    blocs = []
    n_lignes, n_colonnes = feuille.shape

    for j in range(n_colonnes - 1):
        en_tete = str(feuille.iloc[0, j]).strip() if not pd.isna(feuille.iloc[0, j]) else ""

        if "Elong" in en_tete or "Elong." in en_tete or "Allong" in en_tete:
            match = re.search(r'Ech\s*(\d+)', en_tete, re.IGNORECASE)
            num_ech = int(match.group(1)) if match else len(blocs) + 1

            if j + 1 < n_colonnes:
                en_tete_force = str(feuille.iloc[0, j + 1]).strip() if not pd.isna(feuille.iloc[0, j + 1]) else ""
                if "Force" in en_tete_force:
                    blocs.append({
                        "num_echantillon": num_ech,
                        "col_debut": j,
                        "col_elong": j,
                        "col_force": j + 1
                    })

    return blocs


# ---------------------------------------------------------------------------
# Format CR/CS (fichier IMPORT_TRACTION historique)
# ---------------------------------------------------------------------------

def _lire_diametres(chemin_fichier: str) -> Dict[str, Dict[str, float]]:
    try:
        df = _charger_dataframe(chemin_fichier, sheet_name="DIAMETRE (CR,CS)")
    except Exception:
        return {"CR": {}, "CS": {}}

    resultats = {"CR": {}, "CS": {}}
    n_lignes, n_colonnes = df.shape

    for i in range(n_lignes):
        label = str(df.iloc[i, 0]).strip() if not pd.isna(df.iloc[i, 0]) else ""

        if label.lower().startswith('ech'):
            try:
                num_ech = int(''.join(filter(str.isdigit, label)))
                d_cr = _convertir_en_float(df.iloc[i, 4])
                d_cs = _convertir_en_float(df.iloc[i, 12])

                if d_cr and d_cr > 0:
                    resultats["CR"][f"Ech{num_ech}"] = d_cr
                if d_cs and d_cs > 0:
                    resultats["CS"][f"Ech{num_ech}"] = d_cs
            except (ValueError, TypeError):
                continue

    return resultats


def _lire_recapitulatif(chemin_fichier: str) -> Dict[str, Dict[str, Dict[str, float]]]:
    try:
        df = _charger_dataframe(chemin_fichier, sheet_name="RECCAPITULATIF")
    except Exception:
        return {"CR": {}, "CS": {}}

    resultats = {"CR": {}, "CS": {}}
    n_lignes, n_colonnes = df.shape

    for i in range(n_lignes):
        label = str(df.iloc[i, 1]).strip() if len(df.columns) > 1 and not pd.isna(df.iloc[i, 1]) else ""

        if label.lower().startswith('ech'):
            try:
                num_ech = int(''.join(filter(str.isdigit, label)))

                contrainte_cr = _convertir_en_float(df.iloc[i, 2]) if len(df.columns) > 2 else None
                deformation_cr = _convertir_en_float(df.iloc[i, 3]) if len(df.columns) > 3 else None
                module_cr = _convertir_en_float(df.iloc[i, 4]) if len(df.columns) > 4 else None

                contrainte_cs = _convertir_en_float(df.iloc[i, 7]) if len(df.columns) > 7 else None
                deformation_cs = _convertir_en_float(df.iloc[i, 8]) if len(df.columns) > 8 else None
                module_cs = _convertir_en_float(df.iloc[i, 9]) if len(df.columns) > 9 else None

                if contrainte_cr is not None:
                    resultats["CR"][f"Ech{num_ech}"] = {
                        "contrainte": contrainte_cr,
                        "deformation": deformation_cr,
                        "module_elasticite": module_cr
                    }

                if contrainte_cs is not None:
                    resultats["CS"][f"Ech{num_ech}"] = {
                        "contrainte": contrainte_cs,
                        "deformation": deformation_cs,
                        "module_elasticite": module_cs
                    }
            except (ValueError, TypeError):
                continue

    return resultats


def _lire_courbes(chemin_fichier: str, feuille_nom: str) -> Dict[str, List[Dict[str, float]]]:
    try:
        df = _charger_dataframe(chemin_fichier, sheet_name=feuille_nom)
    except Exception:
        return {}

    resultats = {}
    blocs = _identifier_blocs_courbe(df)

    for bloc in blocs:
        num_ech = bloc["num_echantillon"]
        col_debut = bloc["col_debut"]
        points = _extraire_donnees_courbe(df, col_debut)

        if points:
            cle = f"Ech{num_ech}"
            resultats[cle] = points

    return resultats


def _lire_echantillons_format_cr_cs(chemin_fichier: str) -> List[Dict[str, Any]]:
    diametres = _lire_diametres(chemin_fichier)
    recap = _lire_recapitulatif(chemin_fichier)
    courbes_cr = _lire_courbes(chemin_fichier, "COROUI")
    courbes_cs = _lire_courbes(chemin_fichier, "COSOU")

    echantillons_data = []
    tous_ech = set()
    for source in [diametres["CR"], diametres["CS"], recap["CR"], recap["CS"], courbes_cr, courbes_cs]:
        for cle in source.keys():
            if cle.startswith("Ech"):
                tous_ech.add(cle)

    if not tous_ech:
        raise ValueError(
            "Le classeur correspond au format CR/CS, mais aucune donnée "
            "d'échantillon exploitable n'a été détectée."
        )

    for cle_ech in sorted(tous_ech):
        num = int(''.join(filter(str.isdigit, cle_ech)))
        identifiant = f"Ech{num:02d}"

        diam_cr = diametres["CR"].get(cle_ech)
        diam_cs = diametres["CS"].get(cle_ech)

        largeur_mm = None
        epaisseur_mm = None

        if diam_cr:
            largeur_mm = diam_cr
            epaisseur_mm = diam_cr
        elif diam_cs:
            largeur_mm = diam_cs
            epaisseur_mm = diam_cs

        longueur_initiale = 20.0
        data_cr = recap["CR"].get(cle_ech, {})
        data_cs = recap["CS"].get(cle_ech, {})

        force_rupture_cr = None
        deplacement_rupture_cr = None
        force_rupture_cs = None
        deplacement_rupture_cs = None

        if cle_ech in courbes_cr and courbes_cr[cle_ech]:
            force_max_cr = max(p["force"] for p in courbes_cr[cle_ech])
            for p in courbes_cr[cle_ech]:
                if p["force"] == force_max_cr:
                    deplacement_rupture_cr = p["deplacement"]
                    break
            force_rupture_cr = force_max_cr

        if cle_ech in courbes_cs and courbes_cs[cle_ech]:
            force_max_cs = max(p["force"] for p in courbes_cs[cle_ech])
            for p in courbes_cs[cle_ech]:
                if p["force"] == force_max_cs:
                    deplacement_rupture_cs = p["deplacement"]
                    break
            force_rupture_cs = force_max_cs

        echantillon = {
            "identifiant": identifiant,
            "largeur_mm": largeur_mm,
            "epaisseur_mm": epaisseur_mm,
            "longueur_initiale_mm": longueur_initiale,
            "force_rupture_newton": force_rupture_cr or force_rupture_cs,
            "deplacement_rupture_mm": deplacement_rupture_cr or deplacement_rupture_cs,
            "points_courbe": []
        }

        if cle_ech in courbes_cr:
            echantillon["points_courbe"] = courbes_cr[cle_ech]
        elif cle_ech in courbes_cs:
            echantillon["points_courbe"] = courbes_cs[cle_ech]

        if data_cr:
            echantillon["contrainte_max_cr"] = data_cr.get("contrainte")
            echantillon["deformation_max_cr"] = data_cr.get("deformation")
            echantillon["module_elasticite_cr"] = data_cr.get("module_elasticite")

        if data_cs:
            echantillon["contrainte_max_cs"] = data_cs.get("contrainte")
            echantillon["deformation_max_cs"] = data_cs.get("deformation")
            echantillon["module_elasticite_cs"] = data_cs.get("module_elasticite")

        echantillon["diametre_cr"] = diam_cr
        echantillon["diametre_cs"] = diam_cs

        echantillons_data.append(echantillon)

    return echantillons_data


# ---------------------------------------------------------------------------
# Format générique : courbes + dimensions multi-formes
# ---------------------------------------------------------------------------

_TYPES_ESSAI = ('traction', 'compression', 'flexion')
_FEUILLES_A_IGNORER = {'INFO'}


def _normaliser_entete(valeur: Any) -> str:
    return re.sub(r'[^A-Z0-9]', '', str(valeur or '').upper())


def _trouver_feuille_dimensions(classeur) -> Optional[str]:
    """Renvoie le nom de la feuille de dimensions, ou None si absente."""
    for nom in classeur.sheetnames:
        if _normaliser_entete(nom).startswith(('DIAMETRE', 'DIAMETER', 'DIMENSION')):
            return nom
    return None


def _cell_matches_pattern(cell_value: Any, pattern: str) -> bool:
    """« D_1(mm) », « D1 », « D 1 (mm) »… matchent tous « D1 ».
    L'unité (mm ou mm2) est tolérée en suffixe."""
    normalise = _normaliser_entete(cell_value)
    return re.fullmatch(rf'{pattern}(MM2?)?', normalise) is not None


def _match_signature(row, start_col: int, patterns: List[str]) -> bool:
    for offset, pattern in enumerate(patterns):
        col = start_col + offset
        if col >= len(row):
            return False
        if not _cell_matches_pattern(row[col], pattern):
            return False
    return True


def _calculer_section(forme: str, valeurs: List[Optional[float]]) -> Optional[float]:
    """Calcule S (mm²) selon la forme. Renvoie None si une mesure manque."""
    if not valeurs or any(v is None or v <= 0 for v in valeurs):
        return None
    if forme == 'cylindre':
        d = sum(valeurs[:3]) / 3
        return math.pi * (d / 2) ** 2
    if forme == 'rectangle':
        l_moy = sum(valeurs[:3]) / 3
        e_moy = sum(valeurs[3:6]) / 3
        return l_moy * e_moy
    if forme == 'carre':
        return (sum(valeurs[:3]) / 3) ** 2
    if forme == 'tube_circulaire':
        d_ext = sum(valeurs[:3]) / 3
        d_int = sum(valeurs[3:6]) / 3
        return math.pi * (d_ext ** 2 - d_int ** 2) / 4
    if forme == 'tube_rectangulaire':
        B = sum(valeurs[0:3]) / 3
        H = sum(valeurs[3:6]) / 3
        b = sum(valeurs[6:9]) / 3
        h = sum(valeurs[9:12]) / 3
        return B * H - b * h
    if forme == 'surface':
        return sum(valeurs[:3]) / 3
    return None


def _lire_dimensions_pour_forme(classeur, forme_demandee: str) -> Dict[str, List[Dict[str, Any]]]:
    """Lit la feuille de dimensions et renvoie {nom_gamme: [échantillons]}
    pour la forme demandée. Renvoie {} si la feuille est absente ou si aucun
    bloc ne correspond — l'appelant décide s'il s'agit d'une erreur.
    """
    if forme_demandee not in _FORMES_VALIDES:
        raise ValueError(f"Forme inconnue : {forme_demandee!r}")

    nom_feuille = _trouver_feuille_dimensions(classeur)
    if nom_feuille is None:
        return {}

    feuille = classeur[nom_feuille]
    rows = list(feuille.iter_rows(values_only=True))
    if not rows:
        return {}

    patterns = _FORMES_BLOCS[forme_demandee]
    n_cols = len(patterns)

    header_idx = None
    blocs = []
    for idx in range(min(3, len(rows))):
        row = rows[idx]
        col = 0
        trouves = []
        while col < len(row) - n_cols + 1:
            if _match_signature(row, col, patterns):
                trouves.append(col)
                col += n_cols
            else:
                col += 1
        if trouves:
            header_idx = idx
            blocs = trouves
            break

    if header_idx is None or not blocs:
        return {}

    row_titre = rows[header_idx - 1] if header_idx > 0 else []

    resultats: Dict[str, List[Dict[str, Any]]] = {}
    for numero, first_col in enumerate(blocs, start=1):
        ident_col = first_col - 1

        nom_gamme = None
        for c in (ident_col, first_col):
            if 0 <= c < len(row_titre) and row_titre[c] and str(row_titre[c]).strip():
                nom_gamme = str(row_titre[c]).strip()
                break
        cle_gamme = nom_gamme or f'__groupe_{numero}'

        lignes = []
        for r_idx in range(header_idx + 1, len(rows)):
            row = rows[r_idx]
            if ident_col < 0 or ident_col >= len(row):
                continue
            identifiant_raw = row[ident_col]
            if identifiant_raw is None or not str(identifiant_raw).strip():
                continue

            valeurs = [
                _convertir_en_float(row[first_col + k])
                if first_col + k < len(row) else None
                for k in range(n_cols)
            ]
            section = _calculer_section(forme_demandee, valeurs)
            if section is None:
                continue

            match_id = re.search(r'(?:PLOT|ECH)\s*(\d+)', str(identifiant_raw), re.IGNORECASE)
            id_clean = (f'ECH{match_id.group(1)}' if match_id
                        else str(identifiant_raw).strip().upper())

            echantillon = {
                'identifiant': id_clean,
                'forme': forme_demandee,
                'titre_source': nom_gamme,
                'dimensions_mm': dict(zip(_NOMS_COLONNES[forme_demandee], valeurs)),
                'section_mm2': section,
            }
            # Compat export : diamètres seulement pour la forme cylindre.
            if forme_demandee == 'cylindre':
                echantillon['diametres_mm'] = valeurs[:3]
                echantillon['diametre_moyen_mm'] = sum(valeurs[:3]) / 3

            lignes.append(echantillon)

        if lignes:
            cle = cle_gamme
            suffixe = 1
            while cle in resultats:
                suffixe += 1
                cle = f'{cle_gamme}_{suffixe}'
            resultats[cle] = lignes

    return resultats


def _extraire_base_hauteur(
    forme: str, dimensions_mm: Dict[str, Optional[float]]
) -> tuple[Optional[float], Optional[float]]:
    """Extrait base (b) et hauteur (h) moyennes pour la flexion 3 points.

    - rectangle : b = moyenne des L_i, h = moyenne des E_i
    - carre     : b = h = moyenne des C_i
    Renvoie (None, None) si la forme n'est pas supportée ou si une mesure manque.
    """
    if forme == 'rectangle':
        vals_l = [dimensions_mm.get(f'L_{i}') for i in (1, 2, 3)]
        vals_e = [dimensions_mm.get(f'E_{i}') for i in (1, 2, 3)]
        if any(v is None or v <= 0 for v in vals_l + vals_e):
            return None, None
        return sum(vals_l) / 3, sum(vals_e) / 3
    if forme == 'carre':
        vals_c = [dimensions_mm.get(f'C_{i}') for i in (1, 2, 3)]
        if any(v is None or v <= 0 for v in vals_c):
            return None, None
        c_moy = sum(vals_c) / 3
        return c_moy, c_moy
    return None, None


# Alias rétro-compatible : le code qui appelait _lire_diametres_generiques
# continue de fonctionner, en supposant la forme cylindre.
def _lire_diametres_generiques(classeur):
    return _lire_dimensions_pour_forme(classeur, 'cylindre')


def _lire_courbes_generiques(classeur) -> List[Dict[str, Any]]:
    gammes = []
    for nom_feuille in classeur.sheetnames:
        entete_feuille = _normaliser_entete(nom_feuille)
        if (
            nom_feuille.upper() in _FEUILLES_A_IGNORER
            or entete_feuille.startswith(('DIAMETRE', 'DIAMETER', 'DIMENSION', 'RECAPITULATIF'))
        ):
            continue

        feuille = classeur[nom_feuille]
        rows = list(feuille.iter_rows(values_only=True))
        if not rows:
            continue

        ligne_entete_idx = next(
            (
                idx
                for idx in (0, 1)
                if idx < len(rows)
                and any('FORCE' in _normaliser_entete(cell) for cell in rows[idx])
            ),
            None,
        )
        if ligne_entete_idx is None:
            continue

        row_entete = rows[ligne_entete_idx]
        max_colonne = len(row_entete)

        blocs = []
        for col_force_idx in range(max_colonne):
            if 'FORCE' not in _normaliser_entete(row_entete[col_force_idx]):
                continue
            col_depl_idx = next(
                (
                    col_force_idx - delta
                    for delta in range(1, min(3, col_force_idx) + 1)
                    if any(
                        marqueur in _normaliser_entete(row_entete[col_force_idx - delta])
                        for marqueur in ('ELONG', 'ALLONG', 'DEPLAC')
                    )
                ),
                None,
            )
            if col_depl_idx is not None:
                blocs.append((col_depl_idx, col_force_idx))

        echantillons = []
        for index, (col_deplacement, col_force) in enumerate(blocs, start=1):
            points = []
            for r_idx in range(ligne_entete_idx + 1, len(rows)):
                row = rows[r_idx]
                depl_val = row[col_deplacement] if col_deplacement < len(row) else None
                force_val = row[col_force] if col_force < len(row) else None
                deplacement = _convertir_en_float(depl_val)
                force = _convertir_en_float(force_val)
                if deplacement is None or force is None:
                    if points:
                        break
                    continue
                points.append({
                    'deplacement_mm': deplacement,
                    'force_newton': force,
                })
            if points:
                val_force = row_entete[col_force]
                val_depl = row_entete[col_deplacement]
                match_id = re.search(r'(?:PLOT|ECH)\s*(\d+)', str(val_force or ''), re.IGNORECASE)
                if not match_id:
                    match_id = re.search(r'(?:PLOT|ECH)\s*(\d+)', str(val_depl or ''), re.IGNORECASE)
                num_ech = int(match_id.group(1)) if match_id else index
                echantillons.append({
                    'identifiant': f'ECH{num_ech}',
                    'points_courbe': points,
                })
        if echantillons:
            gammes.append({'nom_gamme': nom_feuille, 'echantillons': echantillons})

    return gammes


# ---------------------------------------------------------------------------
# API publique
# ---------------------------------------------------------------------------

def lire_donnees_brutes(
    chemin_fichier: str, type_essai: str
) -> Dict[str, Any]:
    """Lit les courbes et signale la présence éventuelle d'une feuille de
    dimensions. La fusion courbes ↔ dimensions se fait dans read_workbook.
    """
    if type_essai not in _TYPES_ESSAI:
        raise ValueError(f"Type d'essai inconnu : {type_essai!r}")

    classeur = load_workbook(chemin_fichier, data_only=True, read_only=True)
    try:
        gammes = _lire_courbes_generiques(classeur)
        if not gammes:
            raise ValueError('Aucune gamme avec courbe exploitable détectée.')

        a_feuille = _trouver_feuille_dimensions(classeur) is not None

        return {
            'gammes': gammes,
            'source': chemin_fichier,
            'type_essai': type_essai,
            'a_feuille_dimensions': a_feuille,
        }
    finally:
        classeur.close()


def lister_echantillons(chemin_fichier: str, type_essai: str) -> Dict[str, Any]:
    """Liste les courbes détectées sans exiger les dimensions."""
    donnees = lire_donnees_brutes(chemin_fichier, type_essai)
    return {
        'type_essai': type_essai,
        'a_feuille_dimensions': donnees.get('a_feuille_dimensions', False),
        'gammes': [
            {
                'nom_gamme': gamme['nom_gamme'],
                'echantillons': [ech['identifiant'] for ech in gamme['echantillons']],
            }
            for gamme in donnees['gammes']
        ],
    }


def _lire_dimensions_fichier(chemin_fichier: str, forme: str) -> Dict[str, List[Dict[str, Any]]]:
    """Helper : ouvre le fichier et renvoie les dimensions pour la forme."""
    classeur = load_workbook(chemin_fichier, data_only=True, read_only=True)
    try:
        return _lire_dimensions_pour_forme(classeur, forme)
    finally:
        classeur.close()


def _index_dimensions_par_gamme(
    donnees: Dict[str, Any], dims: Dict[str, List[Dict[str, Any]]]
) -> Dict[str, Dict[str, Dict[str, Any]]]:
    """Associe les dimensions lues aux gammes de `donnees`, en respectant
    l'ordre de découverte si les noms ne correspondent pas exactement.
    Renvoie {nom_gamme: {identifiant: dict_dimensions}}.
    """
    noms = list(dims)
    par_gamme: Dict[str, Dict[str, Dict[str, Any]]] = {}
    for i, gamme in enumerate(donnees['gammes']):
        lignes = dims.get(gamme['nom_gamme'])
        if lignes is None and i < len(noms):
            lignes = dims[noms[i]]
        if lignes:
            par_gamme[gamme['nom_gamme']] = {
                l['identifiant']: l for l in lignes
            }
    return par_gamme


def _fusionner_dimensions_gamme(
    gamme: Dict[str, Any],
    dimensions: Dict[str, Dict[str, Any]],
) -> None:
    """Fusionne les mesures d'une gamme et conserve son titre source."""
    titre_source = next(
        (dimension.get('titre_source') for dimension in dimensions.values()
         if dimension.get('titre_source')),
        None,
    )
    if titre_source:
        gamme['titre_dimensions_source'] = titre_source

    for echantillon in gamme['echantillons']:
        dimension = dimensions.get(echantillon['identifiant'])
        if dimension:
            echantillon.update(dimension)
            echantillon.pop('titre_source', None)


def read_workbook(
    chemin_fichier: str,
    type_essai: str = 'traction',
    geometrie: Optional[Dict[str, Any]] = None,
    forme: Optional[str] = None,
) -> Dict[str, Any]:
    """Lit un classeur d'essai et applique la géométrie fournie.

    Pour les trois essais, la feuille de dimensions est optionnelle :
    - si elle est présente, les dimensions sont lues depuis le fichier ;
    - sinon, l'app se replie sur la géométrie fournie par l'UI.

    - traction    : feuille → section par échantillon ; UI → section globale.
    - compression : feuille → section par échantillon ; UI → section + L0.
    - flexion     : feuille → base/hauteur par échantillon ; UI → base/hauteur
                    globales. `portee_mm` reste toujours fournie par l'UI.
    """
    geometrie = geometrie or {}
    donnees = lire_donnees_brutes(chemin_fichier, type_essai)
    a_feuille = donnees.get('a_feuille_dimensions', False)

    # ---------------------------------------------------------------------
    # TRACTION
    # ---------------------------------------------------------------------
    if type_essai == 'traction':
        dims_par_gamme: Dict[str, Dict[str, Dict[str, Any]]] = {}

        if a_feuille:
            if forme is None:
                forme = 'cylindre'  # rétrocompatibilité
            if forme not in _FORMES_VALIDES:
                raise ValueError(f"Forme inconnue : {forme!r}")
            dims_par_gamme = _index_dimensions_par_gamme(
                donnees, _lire_dimensions_fichier(chemin_fichier, forme)
            )
            if not dims_par_gamme:
                raise ValueError(
                    f"Feuille de dimensions présente mais aucune colonne "
                    f"correspondant à la forme {forme!r} n'a été trouvée."
                )

        for gamme in donnees['gammes']:
            dict_dim = dims_par_gamme.get(gamme['nom_gamme'], {})
            _fusionner_dimensions_gamme(gamme, dict_dim)

        # Repli UI pour les échantillons sans section
        section_ui = geometrie.get('section_mm2')
        l0_ui = geometrie.get('l0_mm')
        for gamme in donnees['gammes']:
            for ech in gamme['echantillons']:
                if 'section_mm2' not in ech:
                    if section_ui is None or l0_ui is None:
                        continue  # sera filtré plus bas
                    ech['section_mm2'] = float(section_ui)
                    ech['l0_mm'] = float(l0_ui)

        # Filtrer les échantillons sans section
        for gamme in donnees['gammes']:
            gamme['echantillons'] = [
                e for e in gamme['echantillons'] if 'section_mm2' in e
            ]
        donnees['gammes'] = [g for g in donnees['gammes'] if g['echantillons']]

    
    # ---------------------------------------------------------------------
    # COMPRESSION
    # ---------------------------------------------------------------------
    elif type_essai == 'compression':
        dims_par_gamme: Dict[str, Dict[str, Dict[str, Any]]] = {}
        if a_feuille and forme:
            if forme not in _FORMES_VALIDES:
                raise ValueError(f"Forme inconnue : {forme!r}")
            dims_par_gamme = _index_dimensions_par_gamme(
                donnees, _lire_dimensions_fichier(chemin_fichier, forme)
            )

        dimensions_ui_par_gamme = geometrie.get('dimensions_par_echantillon') or {}

        for gamme in donnees['gammes']:
            dict_dim = dims_par_gamme.get(gamme['nom_gamme'], {})
            _fusionner_dimensions_gamme(gamme, dict_dim)
            dims_ui_gamme = dimensions_ui_par_gamme.get(gamme['nom_gamme'], {})

            for ech in gamme['echantillons']:
                # 1. L0 : toujours depuis l'UI (la feuille n'en fournit pas)
                dims_ui = dims_ui_gamme.get(ech['identifiant'], {})
                if 'l0_mm' not in ech:
                    l0 = dims_ui.get('l0_mm', geometrie.get('l0_mm'))
                    if l0 is not None:
                        ech['l0_mm'] = float(l0)

                # 2. Section : repli sur l'UI si absente de la feuille
                if 'section_mm2' not in ech:
                    section = dims_ui.get(
                        'section_mm2', geometrie.get('section_mm2')
                    )
                    if section is not None:
                        ech['section_mm2'] = float(section)

                # 3. Vérification finale
                if 'l0_mm' not in ech or 'section_mm2' not in ech:
                    raise ValueError(
                        f"Dimensions manquantes pour {ech['identifiant']} "
                        f"(gamme {gamme['nom_gamme']!r}) : renseignez l0_mm et "
                        "section_mm2 avant le calcul."
                    )

    # ---------------------------------------------------------------------
    # FLEXION
    # ---------------------------------------------------------------------
    elif type_essai == 'flexion':
        portee = geometrie.get('portee_mm')
        if portee is None:
            raise ValueError("Paramètres de flexion manquants : portee_mm")

        dims_par_gamme: Dict[str, Dict[str, Dict[str, Any]]] = {}
        if a_feuille and forme:
            if forme not in _FORMES_FLEXION:
                raise ValueError(
                    f"Forme {forme!r} non compatible avec la flexion. "
                    f"Formes acceptées : {', '.join(_FORMES_FLEXION)}."
                )
            dims_par_gamme = _index_dimensions_par_gamme(
                donnees, _lire_dimensions_fichier(chemin_fichier, forme)
            )

        geo_par_ech: Dict[str, Dict[str, Dict[str, float]]] = {}
        base_globale = geometrie.get('base_mm')
        hauteur_globale = geometrie.get('hauteur_mm')

        for gamme in donnees['gammes']:
            dict_dim = dims_par_gamme.get(gamme['nom_gamme'], {})
            _fusionner_dimensions_gamme(gamme, dict_dim)
            for ech in gamme['echantillons']:
                base, hauteur = None, None
                if ech['identifiant'] in dict_dim:
                    base, hauteur = _extraire_base_hauteur(
                        forme, dict_dim[ech['identifiant']]['dimensions_mm']
                    )
                if base is None:
                    base = base_globale
                if hauteur is None:
                    hauteur = hauteur_globale
                if base is None or hauteur is None:
                    raise ValueError(
                        f"Base/hauteur manquantes pour {ech['identifiant']} "
                        f"(gamme {gamme['nom_gamme']!r})."
                    )
                geo_par_ech.setdefault(gamme['nom_gamme'], {})[ech['identifiant']] = {
                    'base_mm': float(base),
                    'hauteur_mm': float(hauteur),
                }

        donnees['geometrie_flexion'] = {
            'portee_mm': float(portee),
            'dimensions_par_echantillon': geo_par_ech,
            # Repli global, utile si l'appelant ne regarde pas le détail
            'base_mm': float(base_globale) if base_globale is not None else None,
            'hauteur_mm': float(hauteur_globale) if hauteur_globale is not None else None,
        }

    return donnees


def lire_classeur_complet(chemin_fichier: str) -> Dict[str, Any]:
    return lire_donnees_brutes(chemin_fichier, 'traction')


def lire_gamme_complete(chemin_fichier: str) -> Dict[str, Any]:
    donnees = read_workbook(chemin_fichier, 'traction')
    gamme = donnees['gammes'][0]
    echantillons = []
    for sample in gamme['echantillons']:
        points = sample['points_courbe']
        point_max = max(points, key=lambda point: point['force_newton'])
        echantillons.append({
            'identifiant': sample['identifiant'],
            'longueur_initiale_mm': None,
            'diametres_mm': sample.get('diametres_mm', []),
            'section_mm2': sample['section_mm2'],
            'force_rupture_newton': point_max['force_newton'],
            'deplacement_rupture_mm': point_max['deplacement_mm'],
            'points_courbe': points,
        })
    return {
        'materiau': {
            'nom_usage': gamme['nom_gamme'],
            'code_interne': gamme['nom_gamme'],
            'famille': 'autre',
        },
        'norme': {
            'code': 'NON_SPECIFIEE',
            'designation': 'Norme non spécifiée dans le fichier Excel',
        },
        'conditions': {},
        'echantillons': echantillons,
    }


def lire_echantillons_depuis_excel(chemin_fichier: str) -> List[Dict[str, Any]]:
    classeur = load_workbook(chemin_fichier, read_only=True, data_only=True)
    try:
        feuilles = {_normaliser_entete(nom) for nom in classeur.sheetnames}
        est_format_cr_cs = {
            'DIAMETRECRCS',
            'RECCAPITULATIF',
            'COROUI',
            'COSOU',
        }.issubset(feuilles)
    finally:
        classeur.close()

    if est_format_cr_cs:
        return _lire_echantillons_format_cr_cs(chemin_fichier)

    donnees = lire_donnees_brutes(chemin_fichier, 'traction')
    echantillons = []
    for gamme in donnees['gammes']:
        for echantillon in gamme['echantillons']:
            points = echantillon['points_courbe']
            point_max = max(points, key=lambda point: point['force_newton'])
            echantillons.append({
                'identifiant': echantillon['identifiant'],
                'largeur_mm': echantillon.get('diametre_moyen_mm'),
                'epaisseur_mm': echantillon.get('diametre_moyen_mm'),
                'longueur_initiale_mm': None,
                'diametres_mm': echantillon.get('diametres_mm', []),
                'force_rupture_newton': point_max['force_newton'],
                'deplacement_rupture_mm': point_max['deplacement_mm'],
                'points_courbe': [
                    {'deplacement': point['deplacement_mm'], 'force': point['force_newton']}
                    for point in points
                ],
            })
    return echantillons
