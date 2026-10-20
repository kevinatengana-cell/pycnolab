# Vérification du reader.py — classeur unique multi-gammes

## Conclusion

Le reader modifié conserve la lecture des formats verticaux historiques et ajoute la lecture du format horizontal du classeur `TRACTIONFIBREVEGETALE.xlsx`.

Le classeur unique de référence est lu avec :

```python
lire_classeur_complet('TRACTIONFIBREVEGETALE.xlsx')
```

Cette fonction retourne une liste contenant toutes les gammes reconnues dans le fichier. Sur le classeur réel, le résultat est :

```text
COROUI : 22 échantillons, D_Moy Global = 0,196349 mm
COSOU  : 22 échantillons, D_Moy Global = 0,265697 mm
```

## Différence avec le reader original

Le reader original ne savait lire que le format vertical composé des feuilles `INFO`, `DIAMETRES` et `COURBE`. Il ne pouvait pas lire directement les feuilles horizontales `COROUI` et `COSOU` du classeur complet.

Le reader modifié ajoute la détection des feuilles horizontales, des blocs `Elong/Force` et des diamètres situés dans `DIAMETRE (CR,CS)`. Les fonctions historiques restent disponibles pour les fichiers d’import séparés.

## Fonctions à utiliser

| Situation | Fonction |
|---|---|
| Un seul classeur contenant plusieurs gammes horizontales | `lire_classeur_complet(chemin)` |
| Un seul classeur horizontal, compatibilité ancienne | `lire_gammes_horizontal(chemin)` |
| Un fichier vertical représentant une gamme | `lire_gamme_complete(chemin)` |
| Plusieurs fichiers verticaux, une gamme par fichier | `lire_gammes_depuis_fichiers(chemins)` |

La route FastAPI traitant `TRACTIONFIBREVEGETALE.xlsx` doit utiliser `lire_classeur_complet()` et non `lire_gamme_complete()`, car cette dernière conserve une interface historique mono-gamme.

## Données conservées

Le reader ne supprime ni ne modifie les mesures machine. Il lit les couples `Elong.(mm)` et `Force(N)`, les associe à leur échantillon, lit les diamètres opérateur et expose les valeurs calculées nécessaires au moteur.
