# Guide Technique : Approche Mixte d'Ingestion des Normes dans PycnoLab

Ce document détaille l'architecture et le flux opérationnel de l'**Approche Mixte (Assistée)**. Ce workflow combine l'extraction automatique par script Python/JSON et l'édition humaine No-Code dans Flutter pour garantir 100 % de précision dans les protocoles d'essais.

---

## 1. Vision Globale de l'Approche Mixte

```text
┌────────────────┐     ┌──────────────────────┐     ┌────────────────────────┐     ┌──────────────────┐
│  Document PDF  │ ──> │ Script Parser Python │ ──> │ JSON Intermédiaire     │ ──> │ Éditeur No-Code  │
│  (Norme brute) │     │ (pdfplumber / Regex) │     │ (Pré-remplissage ~80%) │     │ (Interface UI)   │
└────────────────┘     └──────────────────────┘     └────────────────────────┘     └────────┬─────────┘
                                                                                            │
                                                                                    [ Édition Humaine ]
                                                                                    [   & Validation  ]
                                                                                            │
                                                                                            ▼
                                                                                   ┌──────────────────┐
                                                                                   │ BDD PycnoLab     │
                                                                                   │ (Protocole Final)│
                                                                                   └──────────────────┘
```

---

## 2. Étapes Détallées du Workflow

### Étape 1 : Ingestion du PDF & Parsing Déterministe
- Le technicien téléverse le document PDF officiel de la norme (ex: `ISO_527-2.pdf`).
- Le service Python backend (`norm_ingestion_service.py`) exécute un parsing ciblé :
  - **Extraction d'en-tête** : Recherche du code de la norme, du titre et de la catégorie.
  - **Extraction des tableaux de symboles** : Identification des grandeurs, libellés et unités (ex: $b$, $h$, $F_m$).
  - **Détection des équations en texte brut** : Capture des motifs d'égalités simples ($\sigma = F / A$).

### Étape 2 : Génération du JSON de Pré-remplissage
Le parser génère un objet JSON temporaire annoté avec des niveaux de confiance (`confidence_score`) et des indicateurs de révision requise :

```json
{
  "draft_id": "draft_iso_527_2_temp",
  "metadata": {
    "norme": "ISO 527-2",
    "titre": "Détermination des propriétés en traction des plastiques",
    "confidence": 0.95
  },
  "extracted_inputs": [
    {
      "key": "largeur_b",
      "label": "Largeur de la partie étroite (b)",
      "unit": "mm",
      "type": "decimal",
      "status": "verified"
    },
    {
      "key": "epaisseur_h",
      "label": "Épaisseur (h)",
      "unit": "mm",
      "type": "decimal",
      "status": "verified"
    },
    {
      "key": "force_f",
      "label": "Force mesurée (F)",
      "unit": "N",
      "type": "decimal",
      "status": "verified"
    }
  ],
  "extracted_formulas": [
    {
      "output_key": "contrainte_sigma",
      "label": "Contrainte en traction",
      "unit": "MPa",
      "raw_detected_formula": "F / (b * h)",
      "status": "needs_review"
    }
  ]
}
```

### Étape 3 : Édition & Validation par l'Opérateur (UI Flutter)
Le JSON temporaire alimente l'écran `EditeurProtocoleScreen`. L'opérateur passe par un parcours d'édition guidé :

1. **Vérification des Métadonnées** : Validation du nom de la norme et du domaine d'application.
2. **Revue des Variables (Inputs)** :
   - Ajout ou suppression de champs manquants.
   - Rectification des unités mal lues (ex: conversion automatique de `KN` en `kN`).
3. **Ajustement des Formules (Formula Builder)** :
   - Les formules détectées avec le statut `needs_review` sont surlignées.
   - L'opérateur utilise les **puces interactives (Pill Builder)** pour reconstituer ou corriger l'équation sans risque d'erreur de syntaxe.
4. **Validation dans la Sandbox** :
   - Injection de jeu de données de test réels.
   - Calcul instantané et comparaison avec les valeurs théoriques de la norme.

### Étape 4 : Persistance et Déploiement
Après confirmation par l'opérateur, le protocole passe au statut `ACTIVE` et est enregistré dans la base de données. Il devient immédiatement disponible dans le tableau de bord pour toutes les saisies d'essais du laboratoire.

---

## 3. Matrice de Répartition des Tâches (Machine vs. Humain)

| Tâche Métier | Prise en charge Machine (80%) | Prise en charge Opérateur (20%) |
| :--- | :--- | :--- |
| **Code & Nom de Norme** | Extraction Regex automatique | Validation visuelle d'un clic |
| **Liste des Variables** | Extraction des tableaux du PDF | Ajout/Correction de variables spécifiques |
| **Normalisation des Unités** | Saisie automatique des unités standards | Choix de l'unité d'affichage par défaut |
| **Formules Complexes** | Pré-détection de la structure brute | Assemblage final via le Pill Builder No-Code |
| **Contrôle Qualité** | Vérification de syntaxe mathématique | Test de valeurs limites dans la Sandbox |

---

## 4. Avantages Stratégiques pour PycnoLab

1. **Fiabilité Absolue (Erreur Zéro)** : L'œil de l'expert métier garantit qu'aucune erreur de parsing PDF ou de corruption de symbole Unicode ne termine dans un rapport d'essai officiel.
2. **Gain de Temps Énorme** : L'opérateur ne passe pas 15 minutes à créer un protocole de zéro ; il passe moins de 60 secondes à valider des champs pré-remplis.
3. **Autonomie Totale** : Le laboratoire n'a pas besoin de faire appel au développeur pour ajouter une nouvelle norme ou adapter un coefficient.
