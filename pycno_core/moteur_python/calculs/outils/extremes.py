"""
Extraction de valeurs extrêmes sur une série de mesures - réutilisable
par n'importe quel essai (traction, compression, flexion...).

Une seule fonction générique sert aussi bien pour la force maximale que
pour la contrainte maximale : c'est la même opération (max d'une série),
juste appliquée à des grandeurs différentes selon l'appelant.
"""


def valeur_maximale(valeurs: list[float]) -> float:
    if not valeurs:
        raise ValueError("La série ne contient aucune valeur.")
    return max(valeurs)