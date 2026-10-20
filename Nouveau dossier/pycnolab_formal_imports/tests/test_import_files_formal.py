import importlib.util

spec = importlib.util.spec_from_file_location('reader', '/home/ubuntu/reader_horizontal_fixed.py')
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)

paths = ['/home/ubuntu/upload/import_COROUI.xlsx', '/home/ubuntu/upload/import_COSOU.xlsx']
gammes = reader.lire_gammes_depuis_fichiers(paths)
assert len(gammes) == 2
for gamme in gammes:
    assert len(gamme['echantillons']) == 22
    assert gamme['diametre_moyen_global_mm'] is not None
    assert gamme['echantillons'][0]['diametre_moyen_mm'] is not None
    assert gamme['echantillons'][0]['section_mm2'] is not None
    assert gamme['echantillons'][0]['points_courbe']
    print(gamme['source_fichier'], gamme['materiau']['nom_usage'], len(gamme['echantillons']), gamme['diametre_moyen_global_mm'])
