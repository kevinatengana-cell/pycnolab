# Correction de l'export traction PycnoLab

## Fichiers à remplacer

Dans le projet Windows réel :

```text
D:\F1\flutterapp\pycnolab\pycno_core\moteur_python\api\main.py
D:\F1\flutterapp\pycnolab\pycno_core\moteur_python\export_excel\production_workbook_exporter.py
D:\F1\flutterapp\pycnolab\pycno_core\moteur_python\import_excel\reader.py
```

Le fichier `reader.py` fourni ici est celui utilisé pour lire `IMPORT_TRACTION.xlsx`. Les deux fichiers importants corrigés sont `main.py` et `production_workbook_exporter.py`.

## Modèle obligatoire

Copier le fichier de référence :

```text
TRACTIONFIBREVEGETALE.xlsx
```

vers :

```text
D:\F1\flutterapp\pycnolab\pycno_core\moteur_python\modeles\MODELE_TRACTION.xlsx
```

## Route utilisée par Flutter

Le service Flutter appelle :

```text
POST /essais/traction/exporter-excel
```

Cette route charge maintenant `MODELE_TRACTION.xlsx` et appelle `process_workbook`. Elle ne crée plus un classeur vide avec une feuille `Résultats`.

## Vérification attendue

Le fichier exporté doit contenir exactement les quatre premières feuilles :

```text
DIAMETRE (CR,CS)
COROUI
COSOU
RECCAPITULATIF
```

Il doit conserver 22 graphiques ScatterChart dans `COROUI`, 22 dans `COSOU` et 3 graphiques en barres dans `RECCAPITULATIF`.

## Redémarrage

Fermer l'ancienne instance Python, puis lancer une seule fois l'application Flutter. Ne pas lancer Uvicorn manuellement en parallèle.
