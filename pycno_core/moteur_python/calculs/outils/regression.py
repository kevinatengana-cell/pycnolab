"""Outils d'analyse de courbe et détection de la pente ascendante pertinente."""

from __future__ import annotations

import math
from typing import Iterable

from moteur_python.modeles.models import PointCourbe


def regression_lineaire(points_xy: list[tuple[float, float]]) -> float | None:
    """Retourne la pente des moindres carrés, ou None si elle est indéfinie."""
    n = len(points_xy)
    if n < 2:
        return None
    xs = [p[0] for p in points_xy]
    ys = [p[1] for p in points_xy]
    moy_x = sum(xs) / n
    moy_y = sum(ys) / n
    numerateur = sum((x - moy_x) * (y - moy_y) for x, y in points_xy)
    denominateur = sum((x - moy_x) ** 2 for x in xs)
    if denominateur <= 0:
        return None
    return numerateur / denominateur


def coefficient_determination(points_xy: list[tuple[float, float]], pente: float | None = None) -> float | None:
    """Calcule R² pour une régression linéaire sur les points fournis."""
    if len(points_xy) < 2:
        return None
    if pente is None:
        pente = regression_lineaire(points_xy)
    if pente is None:
        return None
    moy_y = sum(y for _, y in points_xy) / len(points_xy)
    intercept = sum(y - pente * x for x, y in points_xy) / len(points_xy)
    ss_tot = sum((y - moy_y) ** 2 for _, y in points_xy)
    if ss_tot <= 0:
        return 1.0
    ss_res = sum((y - (intercept + pente * x)) ** 2 for x, y in points_xy)
    return max(0.0, min(1.0, 1.0 - ss_res / ss_tot))


def _points_valides(points_courbe: Iterable[PointCourbe]) -> list[PointCourbe]:
    points = [
        point for point in points_courbe
        if math.isfinite(float(point.force_newton))
        and math.isfinite(float(point.deplacement_mm))
    ]
    # Une courbe machine est analysée dans l'ordre croissant du déplacement.
    return sorted(points, key=lambda point: point.deplacement_mm)


def _candidat(points: list[PointCourbe], section_mm2: float, longueur_mm: float, debut: int, fin: int):
    selection = points[debut:fin]
    xy = [
        (point.deplacement_mm / longueur_mm, point.force_newton / section_mm2)
        for point in selection
    ]
    pente = regression_lineaire(xy)
    r2 = coefficient_determination(xy, pente)
    if pente is None or r2 is None or pente <= 0:
        return None
    return selection, pente, r2


def _prefix_sum(values: list[float]) -> list[float]:
    prefix = [0.0]
    total = 0.0
    for value in values:
        total += value
        prefix.append(total)
    return prefix


def selectionner_pente_ascendante(
    points_courbe: list[PointCourbe],
    section_mm2: float,
    longueur_mm: float,
    min_points: int = 4,
    max_points: int = 10,
    r2_min: float = 0.98,
) -> list[PointCourbe]:
    """Sélectionne les points contigus formant la meilleure pente ascendante.

    Les fenêtres contiguës sont testées dans la courbe triée par déplacement.
    Une fenêtre valide doit avoir une pente positive et un R² au moins égal à
    ``r2_min``. La sélection privilégiée est la plus longue ; à longueur égale,
    celle dont le R² est le meilleur. Si aucune fenêtre ne franchit le seuil,
    la meilleure fenêtre positive d’au moins ``min_points`` est utilisée afin
    de ne pas rendre un essai inexploitable à cause d’un bruit ponctuel.
    """
    if section_mm2 <= 0 or longueur_mm <= 0:
        return []
    if min_points < 2 or max_points < min_points:
        raise ValueError('max_points doit être supérieur ou égal à min_points.')
    points = _points_valides(points_courbe)
    if len(points) < min_points:
        return points

    n = len(points)

    xs = [point.deplacement_mm / longueur_mm for point in points]
    ys = [point.force_newton / section_mm2 for point in points]
    x_origin = xs[0]
    y_origin = ys[0]
    centered_x = [x - x_origin for x in xs]
    centered_y = [y - y_origin for y in ys]
    sum_x = _prefix_sum(centered_x)
    sum_y = _prefix_sum(centered_y)
    sum_x2 = _prefix_sum([x * x for x in centered_x])
    sum_y2 = _prefix_sum([y * y for y in centered_y])
    sum_xy = _prefix_sum([x * y for x, y in zip(centered_x, centered_y)])

    def evaluate_window(debut: int, fin: int) -> tuple[float, float] | None:
        count = fin - debut
        sx = sum_x[fin] - sum_x[debut]
        sy = sum_y[fin] - sum_y[debut]
        sxx = sum_x2[fin] - sum_x2[debut] - sx * sx / count
        if sxx <= 0:
            return None
        syy = sum_y2[fin] - sum_y2[debut] - sy * sy / count
        sxy = sum_xy[fin] - sum_xy[debut] - sx * sy / count
        pente = sxy / sxx
        if pente <= 0:
            return None
        if syy <= 0:
            r2 = 1.0
        else:
            r2 = min(1.0, max(0.0, sxy * sxy / (sxx * syy)))
        return pente, r2

    meilleur_repli = None
    for taille in range(n, min_points - 1, -1):
        meilleur_valide = None
        for debut in range(0, n - taille + 1):
            stats = evaluate_window(debut, debut + taille)
            if stats is None:
                continue
            pente, r2 = stats
            score_repli = (r2, taille, pente)
            if meilleur_repli is None or score_repli > meilleur_repli[0]:
                meilleur_repli = (score_repli, debut, taille)
            if r2 >= r2_min:
                score = (taille, r2, pente)
                if meilleur_valide is None or score > meilleur_valide[0]:
                    meilleur_valide = (score, debut, taille)
        if meilleur_valide is not None:
            _, debut, taille = meilleur_valide
            selection = points[debut:debut + taille]
            break
    else:
        if meilleur_repli is not None:
            _, debut, taille = meilleur_repli
            selection = points[debut:debut + taille]
        else:
            selection = points[:min_points]

    if len(selection) <= max_points:
        return selection

    # La série Excel doit rester contiguë : une sélection espacée ferait
    # référence à toute la plage intermédiaire et réintroduirait des points.
    # On conserve donc une fenêtre contiguë de max_points points.
    return selection[:max_points]


# Alias explicite pour les appelants métier et l’exporteur.
detecter_pente_ascendante = selectionner_pente_ascendante


def module_depuis_courbe(
    points_courbe: list[PointCourbe],
    section_mm2: float,
    longueur_mm: float,
    contrainte_rupture_mpa: float,
    seuil_zone_elastique: float = 0.5,
    max_points: int = 10,
) -> float | None:
    """Calcule E(MPa) sur les points sélectionnés de la pente ascendante."""
    del contrainte_rupture_mpa, seuil_zone_elastique
    selection = selectionner_pente_ascendante(
        points_courbe=points_courbe,
        section_mm2=section_mm2,
        longueur_mm=longueur_mm,
        max_points=max_points,
    )
    xy = [
        (point.deplacement_mm / longueur_mm, point.force_newton / section_mm2)
        for point in selection
    ]
    return regression_lineaire(xy)


def module_zone_deformation(
    points_deformation_contrainte: list[tuple[float, float]],
    borne_inf: float = 0.0005,
    borne_sup: float = 0.0025,
) -> float | None:
    points_filtres = [
        (eps, sigma) for eps, sigma in points_deformation_contrainte
        if borne_inf <= eps <= borne_sup
    ]
    return regression_lineaire(points_filtres)
