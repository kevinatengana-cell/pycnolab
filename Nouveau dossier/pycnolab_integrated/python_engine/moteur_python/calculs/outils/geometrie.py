"""
Outils de calcul géométrique réutilisables par n'importe quel essai.

Comme pour outils/regression.py : ces fonctions ne connaissent rien du
contexte métier (Echantillon, Gamme...), elles prennent des nombres et
rendent des nombres. C'est ce qui permet de les partager entre traction,
compression, flexion, etc.
"""

import math


def diametre_moyen(diametres: list[float]) -> float:
    """
    Moyenne arithmétique de plusieurs mesures de diamètre sur un même
    échantillon (typique des fibres naturelles, dont le diamètre varie
    le long de la longueur - on mesure généralement 3 points : D1, D2, D3).
    """
    if not diametres:
        raise ValueError("Au moins une mesure de diamètre est requise.")
    return sum(diametres) / len(diametres)


def section_circulaire(diametre_mm: float) -> float:
    """Section d'un échantillon à section circulaire (mm²)."""
    if diametre_mm <= 0:
        raise ValueError("Le diamètre doit être positif.")
    rayon = diametre_mm / 2
    return math.pi * rayon ** 2


def section_rectangulaire(largeur_mm: float, epaisseur_mm: float) -> float:
    """Section d'un échantillon à section rectangulaire (mm²)."""
    if largeur_mm <= 0 or epaisseur_mm <= 0:
        raise ValueError("Largeur et épaisseur doivent être positives.")
    return largeur_mm * epaisseur_mm