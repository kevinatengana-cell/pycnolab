import os
import sys
import unittest

# s'assurer que pycno_core est dans le path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'pycno_core'))

from pycno_core.moteur_python.import_excel.reader import lire_donnees_brutes, read_workbook, _normaliser_entete


class TestReaderOptimization(unittest.TestCase):
    def setUp(self):
        self.fichier_test = os.path.join('essais', 'bruts', 'TRACTION HAMPE NaOH_BRUT.xlsx')

    def test_lecture_donnees_brutes_traction_hampe(self):
        if not os.path.exists(self.fichier_test):
            self.skipTest(f"Fichier de test non disponible : {self.fichier_test}")

        donnees = lire_donnees_brutes(self.fichier_test, 'traction')
        self.assertIn('gammes', donnees)
        gammes = donnees['gammes']
        self.assertEqual(len(gammes), 17)

        # Vérification du nombre total d'échantillons et de points
        nb_echantillons = sum(len(g['echantillons']) for g in gammes)
        nb_points = sum(len(e['points_courbe']) for g in gammes for e in g['echantillons'])
        self.assertEqual(nb_echantillons, 220)
        self.assertEqual(nb_points, 7866)

        # Vérification de la première gamme ('exp1 ')
        g1 = gammes[0]
        self.assertEqual(_normaliser_entete(g1['nom_gamme']), 'EXP1')
        self.assertEqual(len(g1['echantillons']), 12)
        e1 = g1['echantillons'][0]
        self.assertEqual(e1['identifiant'], 'ECH6')
        self.assertEqual(len(e1['points_courbe']), 38)
        self.assertAlmostEqual(e1['points_courbe'][0]['deplacement_mm'], 0.0, places=3)
        self.assertAlmostEqual(e1['points_courbe'][0]['force_newton'], 0.0, places=3)
        self.assertAlmostEqual(e1['points_courbe'][-1]['deplacement_mm'], 2.725, places=3)

    def test_read_workbook_sample_file(self):
        fichier_simple = os.path.join('pycno_core', 'moteur_python', 'IMPORT_TRACTION.xlsx')
        if not os.path.exists(fichier_simple):
            self.skipTest(f"Fichier simple non disponible : {fichier_simple}")

        donnees = read_workbook(fichier_simple, type_essai='traction')
        self.assertIn('gammes', donnees)
        self.assertGreaterEqual(len(donnees['gammes']), 1)


if __name__ == '__main__':
    unittest.main()
