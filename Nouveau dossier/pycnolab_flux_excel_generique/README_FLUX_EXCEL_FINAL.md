# Flux Excel final PycnoLab

## Fichier d’entrée opérateur

Le reader lit un seul classeur contenant exactement les trois feuilles de données suivantes :

```text
DIAMETRE (CR,CS)
COROUI
COSOU
```

Le récapitulatif ne doit pas être exigé à l’entrée. L’opérateur fournit les diamètres et les mesures machine `Elong`/`Force` dans les blocs horizontaux des deux gammes.

## Traitement

`reader.py` lit les deux gammes, associe les diamètres à chaque échantillon et retourne les données structurées. `production_workbook_exporter.py` calcule ensuite D_Moy, S, Def, Cont, Cont(max), Def rupt et E(mpa). Il part d’une copie du modèle Excel, écrit les résultats et met à jour les références des nuages de points.

## Fichier final

Le fichier final contient exactement :

```text
DIAMETRE (CR,CS) complétée
COROUI complétée
COSOU complétée
RECCAPITULATIF généré après calcul
```

Les feuilles d’absorption, de reprise d’humidité et de densité ne font pas partie de ce flux.

## Installation Python

Placer les fichiers ainsi :

```text
pycno_core/
├── modeles/
│   └── MODELE_TRACTION.xlsx
└── moteur_python/
    ├── import_excel/
    │   ├── __init__.py
    │   └── reader.py
    ├── export_excel/
    │   ├── __init__.py
    │   └── production_workbook_exporter.py
    └── api/
        └── main.py
```

Intégrer le routeur `route_export_traction.py` dans `main.py`, puis inclure :

```python
app.include_router(router)
```

## Installation Flutter

Ajouter la méthode de `export_excel_service.dart` dans `PythonEngineService`. Le bouton `Exporter le rapport Excel` doit appeler cette méthode après une exécution réussie du protocole.

Le bouton de sélection du fichier ne doit pas déclencher l’export. Le parcours est : `Sélectionner` → `Calculer` → `Afficher` → `Exporter`.
