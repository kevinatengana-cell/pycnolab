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


def afficher_contenu_excel(chemin_fichier: str) -> None:
    """
    Outil de diagnostic : affiche la structure brute du fichier Excel
    dans le terminal, feuille par feuille. Utile pour vérifier
    rapidement qu'un fichier envoyé par le labo a bien la bonne
    structure avant de tenter une lecture complète.
    """
    if not os.path.exists(chemin_fichier):
        print(f"\n[EXCEL READ] Fichier introuvable : {chemin_fichier}\n")
        return

    xl = pd.ExcelFile(chemin_fichier)
    print(f"\n=== INSPECTION : {os.path.basename(chemin_fichier)} ===")
    print(f"Feuilles disponibles : {xl.sheet_names}")

    feuilles_attendues = {"INFO", "DIAMETRES", "COURBE"}
    manquantes = feuilles_attendues - set(xl.sheet_names)
    if manquantes:
        print(f"⚠️  Feuilles manquantes par rapport au format attendu : {manquantes}")

    for sheet in xl.sheet_names:
        df = xl.parse(sheet, header=None)
        print(f"\n--- '{sheet}' ({df.shape[0]} lignes x {df.shape[1]} colonnes) ---")
        if df.empty:
            print("  (vide)")
            continue
        print(df.head(10).to_string(index=True))
    print()


def _lire_info(chemin: str) -> dict:
    df = pd.read_excel(chemin, sheet_name="INFO", header=0)
    return dict(zip(df.iloc[:, 0], df.iloc[:, 1]))


def _lire_diametres(chemin: str) -> dict[str, list[float]]:
    """Retourne {identifiant: [D1, D2, D3]}."""
    df = pd.read_excel(chemin, sheet_name="DIAMETRES", header=0)
    df = df.dropna(how="all")
    df = df[df["ID Échantillon"].notna()]

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


def _lire_courbes(chemin: str) -> dict[str, list[tuple[float, float]]]:
    """Retourne {identifiant: [(force_newton, deplacement_mm), ...]}."""
    df = pd.read_excel(chemin, sheet_name="COURBE", header=0)
    df = df.dropna(how="all")
    df = df[df["ID Échantillon"].notna()]

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

    info = _lire_info(chemin_fichier)
    diametres_par_ech = _lire_diametres(chemin_fichier)
    courbes_par_ech = _lire_courbes(chemin_fichier)

    l0 = _vers_nombre(info.get("Longueur initiale L0 (mm)"))
    if not l0 or l0 <= 0:
        raise ValueError(
            "Longueur initiale L0 (mm) manquante ou invalide dans la feuille INFO."
        )

    echantillons = []
    for id_ech, diametres in diametres_par_ech.items():
        points = courbes_par_ech.get(id_ech, [])
        if not points:
            raise ValueError(
                f"Aucun point de courbe trouvé pour '{id_ech}' dans la feuille "
                f"COURBE (vérifiez que l'identifiant est identique dans les "
                f"deux feuilles)."
            )
        # Point de rupture = force MAXIMALE, pas le dernier point (la force
        # retombe souvent après rupture, prendre le dernier point donnerait
        # une valeur quasi nulle et fausse).
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

    seuil = _vers_nombre(info.get("Seuil résistance min (MPa)"))
    temperature = _vers_nombre(info.get("Température (°C)"))
    humidite = _vers_nombre(info.get("Humidité (%)"))

    return {
        "materiau": {
            "nom_usage": str(info.get("Projet", "À définir")),
            "code_interne": str(info.get("Code interne matériau", "TEMP")),
            "famille": str(info.get("Matériau (famille)", "autre")),
        },
        "norme": {
            "code": str(info.get("Norme", "À définir")),
            "designation": str(info.get("Norme", "À définir")),
            "seuil_resistance_min_mpa": seuil,
        },
        "conditions": {
            "temperature_celsius": temperature,
            "humidite_pourcent": humidite,
        },
        "echantillons": echantillons,
    }