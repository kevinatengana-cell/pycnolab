# Correction du flux Excel dans le projet réel PycnoLab

## Fichiers Python

Copier ou remplacer dans `pycnolab_integrated/python_engine/` :

```text
moteur_python/import_excel/reader.py
moteur_python/export_excel/production_workbook_exporter.py
moteur_python/modeles/MODELE_TRACTION.xlsx
```

Le `reader.py` découvre les feuilles de gammes et les blocs horizontaux `Elong/Force`. Il conserve l’adaptateur `lire_gamme_complete()` pour les routes historiques.

Le `production_workbook_exporter.py` lit le classeur d’entrée, calcule les résultats et produit une copie avec les feuilles de gammes et `RECCAPITULATIF`.

## `main.py`

Le fichier réel à modifier est :

```text
pycnolab_integrated/python_engine/main.py
```

La nouvelle route est :

```text
POST /essais/traction/exporter-excel
```

Elle reçoit :

```json
{
  "chemin_fichier": "D:/essais/entree.xlsx",
  "l0_mm": 20.0
}
```

Elle utilise `MODELE_TRACTION.xlsx` et retourne `RAPPORT_TRACTION.xlsx`. Les routes existantes de calcul et d’exécution Studio sont conservées.

## Fichiers Flutter

Les fichiers réels modifiés sont :

```text
pycnolab_integrated/flutter_app/lib/services/python_engine_service.dart
pycnolab_integrated/flutter_app/lib/screens/import_screen.dart
pycnolab_integrated/flutter_app/lib/screens/resultats_screen.dart
```

Le parcours devient :

```text
Sélectionner le fichier
→ Calculer et afficher les résultats
→ Vérifier les résultats et graphiques
→ Exporter le rapport
```

`import_screen.dart` transmet le chemin du fichier source à `ResultatsScreen`. `resultats_screen.dart` affiche le bouton d’export et appelle `PythonEngineService.exporterClasseurTraction()`.

## Important

`RAPPORT_TRACTION.xlsx` est créé à l’exécution et ne doit pas être copié dans le projet. Le fichier d’entrée opérateur est sélectionné à l’exécution et doit contenir les feuilles `DIAMETRE (CR,CS)`, `COROUI`, `COSOU` ou toute autre feuille de gamme détectée automatiquement.

Le modèle permanent est uniquement :

```text
pycnolab_integrated/python_engine/moteur_python/modeles/MODELE_TRACTION.xlsx
```

Le test local a confirmé la lecture de deux gammes de 22 échantillons et la génération d’un rapport à quatre feuilles.
