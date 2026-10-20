# Formalisation des fichiers import_COROUI.xlsx et import_COSOU.xlsx

## Contrat retenu

Chaque fichier représente une gamme et possède trois feuilles obligatoires : `INFO`, `DIAMETRES` et `COURBE`.

```text
Un fichier Excel = une gamme

INFO
├── Projet
├── Opérateur
├── Matériau (famille)
├── Code interne matériau
├── Norme
├── Seuil résistance min (MPa)
└── Longueur initiale L0 (mm)

DIAMETRES
├── ID Échantillon
├── D1 (mm)
├── D2 (mm)
└── D3 (mm)

COURBE
├── ID Échantillon
├── Force (N)
└── Déplacement (mm)
```

Le lecteur associe les lignes de `DIAMETRES` et `COURBE` grâce à `ID Échantillon`. Il ne dépend pas du nombre fixe de 22 échantillons : tous les identifiants présents sont parcourus.

## Données calculées

Les fichiers d’import ne sont pas obligés de contenir `D_Moy` et `S`. PycnoLab les calcule à partir de `D1`, `D2` et `D3` :

```text
D_Moy = (D1 + D2 + D3) / 3
S = π × D_Moy² / 4
```

Le lecteur expose également `D_Moy Global` sous forme de moyenne des `D_Moy` individuels de la gamme.

Les points de courbe sont conservés sous forme de couples :

```text
(force_newton, deplacement_mm)
```

Les colonnes de résultats `Def`, `Cont`, `Cont(max)`, `Def rupt` et `E(mpa)` ne sont pas attendues dans les fichiers d’import. Elles seront produites par le moteur scientifique et écrites lors de la génération du classeur final.

## Résultat du test

Le lecteur corrigé lit les deux fichiers réels :

| Fichier | Gamme | Échantillons | D_Moy Global |
|---|---|---:|---:|
| `import_COROUI.xlsx` | Fibre végétale - lot COROUI | 22 | 0,196349 mm |
| `import_COSOU.xlsx` | Fibre végétale - lot COSOU | 22 | 0,265697 mm |

Le nombre de points de courbe reste variable selon l’échantillon. Les lignes vides ne sont pas transformées en mesures.

## Fichier Python à intégrer

```text
pycno_core/moteur_python/import_excel/reader.py
```

La fonction historique suivante reste disponible :

```python
lire_gamme_complete(chemin_fichier)
```

Une fonction dédiée permet de lire plusieurs gammes représentées par plusieurs fichiers :

```python
lire_gammes_depuis_fichiers([
    'import_COROUI.xlsx',
    'import_COSOU.xlsx',
])
```

Elle retourne une liste de gammes homogènes que le moteur pourra ensuite calculer et transmettre au générateur de rapport.

## Règles de validation

Le lecteur doit refuser un fichier sans les trois feuilles obligatoires, un échantillon sans diamètres valides, une ligne de courbe avec Force ou Déplacement manquant, une section nulle ou négative, ou une courbe dont l’identifiant n’existe pas dans la feuille `DIAMETRES`.

Les données machine ne doivent pas être modifiées. Le fichier d’import reste une source ; le rapport final est toujours enregistré dans une copie distincte.
