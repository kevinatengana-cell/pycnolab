# Export Excel au format TRACTIONFIBREVEGETALE

Le correctif conserve une copie du modèle Excel et remplit les quatre feuilles principales : `DIAMETRE (CR,CS)`, `COROUI`, `COSOU` et `RECCAPITULATIF`. Les autres feuilles du modèle sont également conservées.

## Fichiers

- `rapport_labo_modele.py` : exporteur Python, y compris le récapitulatif comparatif.
- `backend_route_export_modele.py` : route FastAPI à ajouter à `moteur_python/api/main.py`.
- `python_engine_service_export.dart` : méthode à ajouter à `PythonEngineService`.
- `TRACTIONFIBREVEGETALE.xlsx` : à placer dans `pycno_core/modeles/` pour que l’export soit automatique.

## Fonctionnement prévu

Le Runner exécute d’abord les fichiers d’entrée. Pour obtenir un classeur contenant COROUI et COSOU, il faut transmettre les deux fichiers d’entrée. Le premier résultat est identifié comme COROUI et le second comme COSOU si le nom du fichier ou le code interne contient ces termes.

La route crée un fichier temporaire, recalcule les résultats à partir des fichiers source, injecte les courbes, les diamètres, les contraintes et les déformations dans une copie du modèle, calcule la moyenne et l’écart-type pour chaque gamme, alimente `RECCAPITULATIF` et ses cellules sources de graphiques, puis renvoie le fichier `.xlsx` à Flutter.

Les valeurs exportées sont arrondies à trois décimales. Les graphiques déjà présents dans le modèle sont conservés par `openpyxl`, notamment les 22 courbes de chaque gamme et les 3 graphiques de comparaison du récapitulatif.

## Installation Python

Copier `rapport_labo_modele.py` dans :

```text
pycno_core/moteur_python/export_excel/rapport_labo_modele.py
```

Copier le classeur modèle dans :

```text
pycno_core/modeles/TRACTIONFIBREVEGETALE.xlsx
```

Ajouter l’import et la route décrits dans `backend_route_export_modele.py` à la version propre de `moteur_python/api/main.py`.

## Installation Flutter

Ajouter la méthode de `python_engine_service_export.dart` dans la classe `PythonEngineService`, puis appeler cette méthode après l’exécution réussie du protocole. Le fichier retourné sera enregistré dans le dossier choisi par l’utilisateur.

## Important

Le fichier modèle ne doit pas être réécrit. Chaque export doit partir d’une copie fraîche afin de préserver la mise en page, les feuilles supplémentaires et les graphiques.
