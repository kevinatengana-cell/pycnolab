"""
Statistiques d'agrégation sur une série d'échantillons - réutilisable
par n'importe quel essai pour synthétiser des résultats individuels
(contrainte max, module, déformation rupture...) en valeurs de gamme
(moyenne, écart-type). C'est la même opération que celle déjà utilisée
dans traction.py pour resistance_moyenne_mpa/ecart_type_mpa, généralisée
ici pour être réutilisable ailleurs.
"""

import statistics


def moyenne_et_ecart_type(valeurs: list[float | None]) -> tuple[float, float]:
    """
    Retourne (moyenne, écart-type), en ignorant les valeurs None
    (ex : module d'Young non calculé pour un échantillon sans courbe).

    L'écart-type est 0.0 s'il ne reste qu'une seule valeur valide
    (statistics.stdev exige au moins 2 points).
    """
    valeurs_valides = [v for v in valeurs if v is not None]
    if not valeurs_valides:
        return (0.0, 0.0)
    moyenne = statistics.mean(valeurs_valides)
    ecart_type = statistics.stdev(valeurs_valides) if len(valeurs_valides) > 1 else 0.0
    return (moyenne, ecart_type)