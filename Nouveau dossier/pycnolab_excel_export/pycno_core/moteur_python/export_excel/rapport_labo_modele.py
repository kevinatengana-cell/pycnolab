"""Export Excel PycnoLab au format du modèle TRACTIONFIBREVEGETALE.xlsx.

Le module reçoit des ResultatGamme déjà calculés et remplit une copie du modèle
sans recalculer les résultats. Les trois feuilles attendues sont conservées :
DIAMETRE (CR,CS), COROUI et COSOU.
"""
from __future__ import annotations

from pathlib import Path
from shutil import copyfile
from typing import Any, Iterable

from openpyxl import load_workbook
from openpyxl.utils import get_column_letter


XLSX_MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
DEFAULT_TEMPLATE = "TRACTIONFIBREVEGETALE.xlsx"


def _number(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return round(float(value), 3)
    except (TypeError, ValueError):
        return None


def _group_key(resultat: Any, index: int) -> str:
    parts = []
    gamme = getattr(resultat, "gamme", None)
    materiau = getattr(gamme, "materiau", None)
    norme = getattr(gamme, "norme", None)
    for obj in (materiau, norme):
        for attr in ("code_interne", "nom_usage", "code", "designation"):
            value = getattr(obj, attr, None)
            if value:
                parts.append(str(value).upper())
    text = " ".join(parts)
    if "COROUI" in text:
        return "COROUI"
    if "COSOU" in text:
        return "COSOU"
    return "COROUI" if index == 0 else "COSOU"


def _samples(resultat: Any) -> list[Any]:
    return list(getattr(getattr(resultat, "gamme", None), "echantillons", []) or [])


def _results_by_id(resultat: Any) -> dict[str, Any]:
    return {
        str(getattr(item, "identifiant", "")): item
        for item in (getattr(resultat, "resultats_echantillons", []) or [])
    }


def _curve_points(echantillon: Any) -> list[tuple[float, float]]:
    return [
        (float(getattr(point, "deplacement_mm")), float(getattr(point, "force_newton")))
        for point in (getattr(echantillon, "points_courbe", []) or [])
    ]


def _section(echantillon: Any) -> float | None:
    try:
        return float(echantillon.section_mm2())
    except (AttributeError, TypeError, ValueError):
        return None


def _find_sample_columns(ws: Any, sample_number: int) -> dict[str, int] | None:
    """Trouve les colonnes du bloc EchN à partir des libellés de la ligne 1."""
    token = f"ECH {sample_number}"
    candidates: dict[str, list[int]] = {"elong": [], "force": [], "def": [], "cont": [], "max": [], "rupt": [], "young": []}
    for col in range(1, ws.max_column + 1):
        value = ws.cell(1, col).value
        label = str(value or "").strip().upper()
        if f"ECH {sample_number}" not in label:
            continue
        if label.startswith("ELONG."):
            candidates["elong"].append(col)
        elif label.startswith("FORCE("):
            candidates["force"].append(col)
        elif label == "DEF":
            candidates["def"].append(col)
        elif label == "CONT":
            candidates["cont"].append(col)
        elif label == "CONT(MAX)":
            candidates["max"].append(col)
        elif label == "DEF RUPT":
            candidates["rupt"].append(col)
        elif label == "E(MPA)":
            candidates["young"].append(col)
    if not candidates["force"] or not candidates["elong"]:
        return None
    # Lorsqu’une ancienne feuille possède deux colonnes Elong., la dernière
    # est la colonne utilisée avec la colonne Force située juste après.
    force = candidates["force"][-1]
    elong = max((c for c in candidates["elong"] if c < force), default=candidates["elong"][-1])
    def nearest(label: str, offset: int) -> int:
        values = candidates[label]
        return min(values, key=lambda c: abs(c - (force + offset))) if values else force + offset
    return {
        "elong": elong,
        "force": force,
        "def": nearest("def", 1),
        "cont": nearest("cont", 2),
        "max": nearest("max", 3),
        "rupt": nearest("rupt", 4),
        "young": nearest("young", 5),
    }


def _clear_data_rows(ws: Any, columns: Iterable[int], start: int = 2, end: int = 500) -> None:
    for row in range(start, min(end, ws.max_row + 1) + 1):
        for col in columns:
            ws.cell(row, col).value = None


def _fill_diameter_sheet(ws: Any, results_by_group: dict[str, Any]) -> None:
    # Le modèle réserve CR à gauche (B:F) et CS à droite (J:N).
    for group, start in (("COROUI", 2), ("COSOU", 10)):
        resultat = results_by_group.get(group)
        if resultat is None:
            continue
        samples = _samples(resultat)
        for row, ech in enumerate(samples, start=3):
            diameters = list(getattr(ech, "diametres_mm", []) or [])
            ws.cell(row, start - 1).value = getattr(ech, "identifiant", f"Ech{row - 2}")
            for offset in range(3):
                ws.cell(row, start + offset).value = _number(diameters[offset] if offset < len(diameters) else None)
            if diameters:
                mean = sum(float(v) for v in diameters) / len(diameters)
                ws.cell(row, start + 3).value = _number(mean)
                ws.cell(row, start + 4).value = _number(3.14 * mean * mean / 4.0)
        # Remplace la moyenne globale de la zone par une valeur calculée.
        means = []
        for ech in samples:
            ds = list(getattr(ech, "diametres_mm", []) or [])
            if ds:
                means.append(sum(float(v) for v in ds) / len(ds))
        if means:
            ws.cell(3, start + 5).value = _number(sum(means) / len(means))


def _fill_curve_sheet(ws: Any, resultat: Any) -> None:
    by_id = _results_by_id(resultat)
    all_columns: list[int] = []
    for index, ech in enumerate(_samples(resultat), start=1):
        cols = _find_sample_columns(ws, index)
        if cols is None:
            continue
        all_columns.extend(cols.values())
        points = _curve_points(ech)
        section = _section(ech)
        longueur = float(getattr(ech, "longueur_initiale_mm", 0) or 0)
        item = by_id.get(str(getattr(ech, "identifiant", "")))
        for row in range(2, ws.max_row + 1):
            for key in ("elong", "force", "def", "cont"):
                ws.cell(row, cols[key]).value = None
        for row, (displacement, force) in enumerate(points, start=2):
            ws.cell(row, cols["elong"]).value = _number(displacement)
            ws.cell(row, cols["force"]).value = _number(force)
            deformation = displacement / longueur if longueur else None
            stress = force / section if section else None
            ws.cell(row, cols["def"]).value = _number(deformation)
            ws.cell(row, cols["cont"]).value = _number(stress)
        if item is not None:
            peak = max((force for _, force in points), default=None)
            stress_peak = getattr(item, "contrainte_rupture_mpa", None)
            rupture_def = getattr(item, "deformation_rupture_pourcent", None)
            young = getattr(item, "module_young_mpa", None)
            ws.cell(2, cols["max"]).value = _number(stress_peak if stress_peak is not None else (peak / section if peak is not None and section else None))
            ws.cell(2, cols["rupt"]).value = _number((rupture_def / 100.0) if rupture_def is not None else None)
            ws.cell(2, cols["young"]).value = _number(young)
    # Les zones de données sont conservées même si une feuille contient moins
    # d’échantillons que le modèle.
    _clear_data_rows(ws, all_columns)
    # Réécriture après nettoyage : le nettoyage ne doit pas effacer les lignes
    # déjà écrites lorsque les colonnes se recouvrent dans une ancienne feuille.
    for index, ech in enumerate(_samples(resultat), start=1):
        cols = _find_sample_columns(ws, index)
        if cols is None:
            continue
        points = _curve_points(ech)
        section = _section(ech)
        longueur = float(getattr(ech, "longueur_initiale_mm", 0) or 0)
        item = _results_by_id(resultat).get(str(getattr(ech, "identifiant", "")))
        for row, (displacement, force) in enumerate(points, start=2):
            ws.cell(row, cols["elong"]).value = _number(displacement)
            ws.cell(row, cols["force"]).value = _number(force)
            ws.cell(row, cols["def"]).value = _number(displacement / longueur if longueur else None)
            ws.cell(row, cols["cont"]).value = _number(force / section if section else None)
        if item is not None:
            ws.cell(2, cols["max"]).value = _number(getattr(item, "contrainte_rupture_mpa", None))
            rupture = getattr(item, "deformation_rupture_pourcent", None)
            ws.cell(2, cols["rupt"]).value = _number(rupture / 100.0 if rupture is not None else None)
            ws.cell(2, cols["young"]).value = _number(getattr(item, "module_young_mpa", None))


def _mean_stdev(values: list[float | None]) -> tuple[float | None, float | None]:
    numbers = [float(v) for v in values if v is not None]
    if not numbers:
        return None, None
    mean = sum(numbers) / len(numbers)
    if len(numbers) < 2:
        return mean, 0.0
    variance = sum((value - mean) ** 2 for value in numbers) / (len(numbers) - 1)
    return mean, variance ** 0.5


def _fill_recap_sheet(ws: Any, grouped: dict[str, Any]) -> None:
    """Remplit RECCAPITULATIF sans supprimer sa mise en page ni ses graphiques."""
    definitions = [("COROUI", 2, 3, 4, 5), ("COSOU", 7, 8, 9, 10)]
    stats: dict[str, dict[str, tuple[float | None, float | None]]] = {}
    for group, id_col, stress_col, def_col, young_col in definitions:
        resultat = grouped.get(group)
        if resultat is None:
            continue
        samples = _samples(resultat)
        by_id = _results_by_id(resultat)
        stress_values: list[float | None] = []
        def_values: list[float | None] = []
        young_values: list[float | None] = []
        for row in range(3, 25):
            for col in (id_col, stress_col, def_col, young_col):
                ws.cell(row, col).value = None
        for row, ech in enumerate(samples[:22], start=3):
            identifiant = str(getattr(ech, "identifiant", f"Ech{row - 2}"))
            item = by_id.get(identifiant)
            stress = getattr(item, "contrainte_rupture_mpa", None) if item else None
            deformation = getattr(item, "deformation_rupture_pourcent", None) if item else None
            young = getattr(item, "module_young_mpa", None) if item else None
            deformation_fraction = float(deformation) / 100.0 if deformation is not None else None
            ws.cell(row, id_col).value = identifiant
            ws.cell(row, stress_col).value = _number(stress)
            ws.cell(row, def_col).value = _number(deformation_fraction)
            ws.cell(row, young_col).value = _number(young)
            stress_values.append(stress)
            def_values.append(deformation_fraction)
            young_values.append(young)
        stats[group] = {
            "stress": _mean_stdev(stress_values),
            "deformation": _mean_stdev(def_values),
            "young": _mean_stdev(young_values),
        }
        mean_row, stdev_row = 25, 26
        ws.cell(mean_row, id_col).value = "MOYENNE"
        ws.cell(stdev_row, id_col).value = "ECART-TYPE"
        for col, key in ((stress_col, "stress"), (def_col, "deformation"), (young_col, "young")):
            mean, stdev = stats[group][key]
            ws.cell(mean_row, col).value = _number(mean)
            ws.cell(stdev_row, col).value = _number(stdev)

    # Zone de synthèse utilisée par les trois graphiques du modèle.
    left = stats.get("COROUI", {})
    right = stats.get("COSOU", {})
    ws["B31"] = "COROUI"
    ws["C31"] = "COSOU"
    ws["I31"] = "COROUI"
    ws["J31"] = "COSOU"
    ws["O31"] = "COROUI"
    ws["P31"] = "COSOU"
    metrics = [("Cont(max)", "stress", "B32", "C32", "D32", "B33", "C33", "D33"),
               ("Def rupt", "deformation", "H32", "I32", "J32", "H33", "I33", "J33"),
               ("E(mpa)", "young", "N32", "O32", "P32", "N33", "O33", "P33")]
    for label, key, label_mean, left_mean, right_mean, label_std, left_std, right_std in metrics:
        ws[label_mean] = label
        ws[label_std] = "ECART-TYPE"
        ws[left_mean] = _number(left.get(key, (None, None))[0])
        ws[right_mean] = _number(right.get(key, (None, None))[0])
        ws[left_std] = _number(left.get(key, (None, None))[1])
        ws[right_std] = _number(right.get(key, (None, None))[1])


def generer_rapport_modele(resultats: list[Any], chemin_modele: str | Path, chemin_sortie: str | Path) -> Path:
    """Crée une copie du modèle et remplit ses trois premières feuilles."""
    if not resultats:
        raise ValueError("Aucun résultat fourni pour générer le rapport Excel.")
    template = Path(chemin_modele)
    output = Path(chemin_sortie)
    if not template.is_file():
        raise FileNotFoundError(f"Modèle Excel introuvable : {template}")
    copyfile(template, output)
    wb = load_workbook(output)
    required = ["DIAMETRE (CR,CS)", "COROUI", "COSOU"]
    missing = [name for name in required if name not in wb.sheetnames]
    if missing:
        raise ValueError(f"Le modèle ne contient pas les feuilles attendues : {missing}")
    grouped: dict[str, Any] = {}
    for index, resultat in enumerate(resultats):
        grouped[_group_key(resultat, index)] = resultat
    _fill_diameter_sheet(wb["DIAMETRE (CR,CS)"], grouped)
    for group in ("COROUI", "COSOU"):
        if group in grouped:
            _fill_curve_sheet(wb[group], grouped[group])
    recap_name = "RECCAPITULATIF" if "RECCAPITULATIF" in wb.sheetnames else ("RECAPITULATIF" if "RECAPITULATIF" in wb.sheetnames else None)
    if recap_name is not None:
        _fill_recap_sheet(wb[recap_name], grouped)
    try:
        wb.calculation.fullCalcOnLoad = True
        wb.calculation.forceFullCalc = True
        wb.calculation.calcMode = "auto"
    except AttributeError:
        pass
    wb.save(output)
    return output
