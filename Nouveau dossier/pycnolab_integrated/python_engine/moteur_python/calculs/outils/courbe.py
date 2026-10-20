"""
Transformations point par point d'une courbe de mesure brute
(force/déplacement) vers les grandeurs mécaniques normalisées
(contrainte/déformation), réutilisables par n'importe quel essai.
"""


def deformation(deplacement_mm: float, longueur_mm: float) -> float:
    """Déformation sans unité (multiplier par 100 pour un pourcentage)."""
    if longueur_mm <= 0:
        raise ValueError("La longueur initiale doit être positive.")
    return deplacement_mm / longueur_mm


def contrainte(force_newton: float, section_mm2: float) -> float:
    """Contrainte en MPa (N/mm²)."""
    if section_mm2 <= 0:
        raise ValueError("La section doit être positive.")
    return force_newton / section_mm2


def courbe_contrainte_deformation(
    points_force_deplacement: list[tuple[float, float]],
    section_mm2: float,
    longueur_mm: float,
) -> list[tuple[float, float]]:
    """
    Convertit une série de points (force_newton, deplacement_mm) en une
    série de points (deformation, contrainte_mpa) - prête pour la
    régression du module d'élasticité ou tout autre traitement de courbe.
    """
    return [
        (deformation(dep, longueur_mm), contrainte(f, section_mm2))
        for f, dep in points_force_deplacement
    ]