import random
import unittest

from moteur_python.calculs.outils.regression import (
    _candidat,
    selectionner_pente_ascendante,
)
from moteur_python.modeles.models import PointCourbe


def _selection_reference(
    points_courbe,
    section_mm2,
    longueur_mm,
    min_points=4,
    max_points=10,
    r2_min=0.98,
):
    points = sorted(points_courbe, key=lambda point: point.deplacement_mm)
    meilleurs_valides = []
    meilleur_repli = None
    for taille in range(len(points), min_points - 1, -1):
        for debut in range(len(points) - taille + 1):
            candidat = _candidat(
                points, section_mm2, longueur_mm, debut, debut + taille
            )
            if candidat is None:
                continue
            selection, pente, r2 = candidat
            score_repli = (r2, len(selection), pente)
            if meilleur_repli is None or score_repli > meilleur_repli[0]:
                meilleur_repli = (score_repli, selection)
            if r2 >= r2_min:
                meilleurs_valides.append(((len(selection), r2, pente), selection))
        if meilleurs_valides:
            break

    if meilleurs_valides:
        selection = max(meilleurs_valides, key=lambda item: item[0])[1]
    elif meilleur_repli is not None:
        selection = meilleur_repli[1]
    else:
        selection = points[:min_points]
    return selection[:max_points]


class RegressionSelectionTests(unittest.TestCase):
    def test_selection_optimisee_preserve_la_reference_sur_courbes_variees(self):
        for seed, taille, r2_min in (
            (14, 12, 0.98),
            (27, 30, 0.98),
            (35, 50, 1.1),
            (42, 75, 1.1),
        ):
            rng = random.Random(seed)
            points = [
                PointCourbe(
                    force_newton=rng.uniform(0, 10),
                    deplacement_mm=(index // 2 if index % 9 == 0 else index)
                    * 0.01,
                )
                for index in range(taille)
            ]

            reference = _selection_reference(
                points, 25.0, 150.0, r2_min=r2_min
            )
            actual = selectionner_pente_ascendante(
                points, 25.0, 150.0, r2_min=r2_min
            )

            self.assertEqual(actual, reference, f"seed={seed}, taille={taille}")


if __name__ == "__main__":
    unittest.main()
