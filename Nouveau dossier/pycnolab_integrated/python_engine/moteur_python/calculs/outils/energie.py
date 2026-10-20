"""
Calcul d'énergie absorbée (aire sous une courbe force-déplacement),
par intégration numérique (méthode des trapèzes).

Utile pour caractériser la ténacité d'un matériau - pertinent notamment
pour les fibres naturelles, le bois, ou tout matériau où la résistance
seule ne suffit pas à qualifier le comportement à la rupture.
"""


def energie_absorbee(points_force_deplacement: list[tuple[float, float]]) -> float:
    """
    points_force_deplacement : liste de (force_newton, deplacement_mm),
    peu importe l'ordre - la fonction trie elle-même par déplacement
    croissant avant d'intégrer.

    Retourne l'énergie en N.mm (millijoules). Diviser par 1000 pour des
    joules si besoin dans l'affichage.
    """
    if len(points_force_deplacement) < 2:
        return 0.0

    points_tries = sorted(points_force_deplacement, key=lambda p: p[1])
    energie = 0.0
    for (f1, d1), (f2, d2) in zip(points_tries, points_tries[1:]):
        energie += (f1 + f2) / 2 * (d2 - d1)
    return energie