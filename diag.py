from pycno_core.moteur_python.import_excel.reader import (
    lire_donnees_brutes,
    _lire_dimensions_fichier,
    _trouver_feuille_dimensions,
)
from openpyxl import load_workbook

FICHIER = 'essais/bruts/COMPRESSION 14 jrs_BRUT.xlsx'
FORME = 'cylindre'

wb = load_workbook(FICHIER, data_only=True, read_only=True)
print('Feuille de dimensions :', repr(_trouver_feuille_dimensions(wb)))
wb.close()

d = lire_donnees_brutes(FICHIER, 'compression')
print('a_feuille_dimensions :', d.get('a_feuille_dimensions'))
print()
print('Gammes (courbes) :')
for g in d['gammes']:
    print('  ', repr(g['nom_gamme']), '->',
          [e['identifiant'] for e in g['echantillons']])

print()
dims = _lire_dimensions_fichier(FICHIER, FORME)
print('Blocs dimensions :')
for n, v in dims.items():
    print('  ', repr(n), '->',
          [e['identifiant'] for e in v])