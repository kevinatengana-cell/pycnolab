/// ============================================================
/// Catalogue de fonctions Excel — module AUTONOME
/// ============================================================
/// Volontairement séparé du reste de PycnoLab : ce fichier ne dépend
/// d'aucun modèle PycnoLab (VariableExcelModel, etc.) et n'est dépendu
/// par rien d'autre que le sélecteur de fonctions. L'objectif affiché
/// est de pouvoir un jour extraire ce module tel quel pour servir à
/// n'importe quel utilisateur Excel, pas seulement au contexte labo.
///
/// COUVERTURE ACTUELLE : ~70 fonctions parmi les plus utilisées, à
/// travers les catégories principales d'Excel. Ce n'est PAS l'exhaustivité
/// des ~500 fonctions d'Excel — ça reste un point de départ solide.
/// Étendre la couverture plus tard = ajouter des entrées à la liste
/// ci-dessous, aucune autre partie du code à toucher.
///
/// `supportTest` : indique si la fonction est probablement gérée par
/// les bibliothèques Python gratuites déjà retenues pour le bouton
/// "Tester la formule" (formulas / xlcalculator-xlsx-evaluate). Cette
/// information n'est PAS vérifiée fonction par fonction contre le code
/// réel des bibliothèques — c'est une estimation de départ. À valider
/// avec un vrai script d'audit (interroger la liste des fonctions
/// enregistrées par `formulas` et la croiser avec ce catalogue) avant
/// de s'y fier pour afficher un badge "testable" fiable au technicien.
/// ============================================================

enum CategorieFonctionExcel {
  mathematiquesTrigonometrie,
  statistiques,
  logique,
  texte,
  dateHeure,
  rechercheReference,
  financier,
  information,
}

extension CategorieFonctionExcelLabel on CategorieFonctionExcel {
  String get libelle {
    switch (this) {
      case CategorieFonctionExcel.mathematiquesTrigonometrie:
        return 'Math & Trigonométrie';
      case CategorieFonctionExcel.statistiques:
        return 'Statistiques';
      case CategorieFonctionExcel.logique:
        return 'Logique';
      case CategorieFonctionExcel.texte:
        return 'Texte';
      case CategorieFonctionExcel.dateHeure:
        return 'Date & Heure';
      case CategorieFonctionExcel.rechercheReference:
        return 'Recherche & Référence';
      case CategorieFonctionExcel.financier:
        return 'Financier';
      case CategorieFonctionExcel.information:
        return 'Information';
    }
  }
}

/// Estimation de départ, NON vérifiée contre le code réel des
/// bibliothèques — voir avertissement en tête de fichier.
enum SupportTestEstime { probable, incertain }

class FonctionExcelInfo {
  const FonctionExcelInfo({
    required this.nom,
    required this.categorie,
    required this.syntaxe,
    required this.description,
    required this.supportTest,
  });

  /// Nom anglais tel qu'il doit être écrit dans le fichier (jamais le
  /// nom français — openpyxl écrit le texte tel quel, voir principe
  /// déjà acté ailleurs dans le projet).
  final String nom;
  final CategorieFonctionExcel categorie;
  final String syntaxe;
  final String description;
  final SupportTestEstime supportTest;
}

const List<FonctionExcelInfo> catalogueFonctionsExcel = [
  // --- Math & Trigonométrie ---
  FonctionExcelInfo(nom: 'SUM', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'SUM(nombre1; [nombre2]; ...)', description: 'Additionne les valeurs.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'ABS', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'ABS(nombre)', description: 'Valeur absolue.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'ROUND', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'ROUND(nombre; nb_chiffres)', description: 'Arrondit à un nombre de décimales donné.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'ROUNDUP', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'ROUNDUP(nombre; nb_chiffres)', description: 'Arrondit au supérieur.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'ROUNDDOWN', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'ROUNDDOWN(nombre; nb_chiffres)', description: 'Arrondit à l’inférieur.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'SQRT', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'SQRT(nombre)', description: 'Racine carrée.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'POWER', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'POWER(nombre; puissance)', description: 'Élève un nombre à une puissance.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'PRODUCT', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'PRODUCT(nombre1; [nombre2]; ...)', description: 'Multiplie les valeurs.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'MOD', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'MOD(nombre; diviseur)', description: 'Reste d’une division.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'SUMIF', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'SUMIF(plage; critère; [plage_somme])', description: 'Somme conditionnelle.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'SUMIFS', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'SUMIFS(plage_somme; plage_critère1; critère1; ...)', description: 'Somme à critères multiples.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'PI', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'PI()', description: 'Valeur de π.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'EXP', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'EXP(nombre)', description: 'Exponentielle de base e.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'LN', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'LN(nombre)', description: 'Logarithme népérien.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'LOG10', categorie: CategorieFonctionExcel.mathematiquesTrigonometrie, syntaxe: 'LOG10(nombre)', description: 'Logarithme base 10.', supportTest: SupportTestEstime.probable),

  // --- Statistiques ---
  FonctionExcelInfo(nom: 'AVERAGE', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'AVERAGE(nombre1; [nombre2]; ...)', description: 'Moyenne arithmétique.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'MIN', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'MIN(nombre1; [nombre2]; ...)', description: 'Valeur minimale.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'MAX', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'MAX(nombre1; [nombre2]; ...)', description: 'Valeur maximale.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'COUNT', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'COUNT(valeur1; [valeur2]; ...)', description: 'Compte les cellules numériques.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'COUNTA', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'COUNTA(valeur1; [valeur2]; ...)', description: 'Compte les cellules non vides.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'COUNTIF', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'COUNTIF(plage; critère)', description: 'Compte selon un critère.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'COUNTIFS', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'COUNTIFS(plage1; critère1; ...)', description: 'Compte à critères multiples.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'MEDIAN', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'MEDIAN(nombre1; [nombre2]; ...)', description: 'Valeur médiane.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'STDEV', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'STDEV(nombre1; [nombre2]; ...)', description: 'Écart-type (échantillon).', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'VAR', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'VAR(nombre1; [nombre2]; ...)', description: 'Variance (échantillon).', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'AVERAGEIF', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'AVERAGEIF(plage; critère; [plage_moyenne])', description: 'Moyenne conditionnelle.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'LARGE', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'LARGE(plage; k)', description: 'k-ième plus grande valeur.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'SMALL', categorie: CategorieFonctionExcel.statistiques, syntaxe: 'SMALL(plage; k)', description: 'k-ième plus petite valeur.', supportTest: SupportTestEstime.incertain),

  // --- Logique ---
  FonctionExcelInfo(nom: 'IF', categorie: CategorieFonctionExcel.logique, syntaxe: 'IF(test_logique; valeur_si_vrai; [valeur_si_faux])', description: 'Test conditionnel.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'AND', categorie: CategorieFonctionExcel.logique, syntaxe: 'AND(logique1; [logique2]; ...)', description: 'Vrai si toutes les conditions sont vraies.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'OR', categorie: CategorieFonctionExcel.logique, syntaxe: 'OR(logique1; [logique2]; ...)', description: 'Vrai si au moins une condition est vraie.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'NOT', categorie: CategorieFonctionExcel.logique, syntaxe: 'NOT(logique)', description: 'Inverse une valeur logique.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'IFERROR', categorie: CategorieFonctionExcel.logique, syntaxe: 'IFERROR(valeur; valeur_si_erreur)', description: 'Valeur de repli en cas d’erreur.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'IFS', categorie: CategorieFonctionExcel.logique, syntaxe: 'IFS(test1; valeur1; [test2; valeur2]; ...)', description: 'Plusieurs tests en cascade.', supportTest: SupportTestEstime.incertain),

  // --- Texte ---
  FonctionExcelInfo(nom: 'CONCAT', categorie: CategorieFonctionExcel.texte, syntaxe: 'CONCAT(texte1; [texte2]; ...)', description: 'Concatène du texte.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'CONCATENATE', categorie: CategorieFonctionExcel.texte, syntaxe: 'CONCATENATE(texte1; [texte2]; ...)', description: 'Concatène du texte (ancienne fonction).', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'LEFT', categorie: CategorieFonctionExcel.texte, syntaxe: 'LEFT(texte; [nb_car])', description: 'Extrait depuis la gauche.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'RIGHT', categorie: CategorieFonctionExcel.texte, syntaxe: 'RIGHT(texte; [nb_car])', description: 'Extrait depuis la droite.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'MID', categorie: CategorieFonctionExcel.texte, syntaxe: 'MID(texte; départ; nb_car)', description: 'Extrait depuis une position.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'LEN', categorie: CategorieFonctionExcel.texte, syntaxe: 'LEN(texte)', description: 'Longueur du texte.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'TRIM', categorie: CategorieFonctionExcel.texte, syntaxe: 'TRIM(texte)', description: 'Supprime les espaces superflus.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'UPPER', categorie: CategorieFonctionExcel.texte, syntaxe: 'UPPER(texte)', description: 'Met en majuscules.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'LOWER', categorie: CategorieFonctionExcel.texte, syntaxe: 'LOWER(texte)', description: 'Met en minuscules.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'TEXT', categorie: CategorieFonctionExcel.texte, syntaxe: 'TEXT(valeur; format)', description: 'Met en forme selon un format texte.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'SUBSTITUTE', categorie: CategorieFonctionExcel.texte, syntaxe: 'SUBSTITUTE(texte; ancien_texte; nouveau_texte; [instance])', description: 'Remplace du texte.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'VALUE', categorie: CategorieFonctionExcel.texte, syntaxe: 'VALUE(texte)', description: 'Convertit un texte en nombre.', supportTest: SupportTestEstime.incertain),

  // --- Date & Heure ---
  FonctionExcelInfo(nom: 'TODAY', categorie: CategorieFonctionExcel.dateHeure, syntaxe: 'TODAY()', description: 'Date du jour.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'NOW', categorie: CategorieFonctionExcel.dateHeure, syntaxe: 'NOW()', description: 'Date et heure actuelles.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'DATE', categorie: CategorieFonctionExcel.dateHeure, syntaxe: 'DATE(année; mois; jour)', description: 'Construit une date.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'YEAR', categorie: CategorieFonctionExcel.dateHeure, syntaxe: 'YEAR(date)', description: 'Extrait l’année.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'MONTH', categorie: CategorieFonctionExcel.dateHeure, syntaxe: 'MONTH(date)', description: 'Extrait le mois.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'DAY', categorie: CategorieFonctionExcel.dateHeure, syntaxe: 'DAY(date)', description: 'Extrait le jour.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'DATEDIF', categorie: CategorieFonctionExcel.dateHeure, syntaxe: 'DATEDIF(date_début; date_fin; unité)', description: 'Différence entre deux dates.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'NETWORKDAYS', categorie: CategorieFonctionExcel.dateHeure, syntaxe: 'NETWORKDAYS(début; fin; [jours_fériés])', description: 'Jours ouvrés entre deux dates.', supportTest: SupportTestEstime.incertain),

  // --- Recherche & Référence ---
  FonctionExcelInfo(nom: 'VLOOKUP', categorie: CategorieFonctionExcel.rechercheReference, syntaxe: 'VLOOKUP(valeur; plage; index_colonne; [proche])', description: 'Recherche verticale.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'HLOOKUP', categorie: CategorieFonctionExcel.rechercheReference, syntaxe: 'HLOOKUP(valeur; plage; index_ligne; [proche])', description: 'Recherche horizontale.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'INDEX', categorie: CategorieFonctionExcel.rechercheReference, syntaxe: 'INDEX(plage; ligne; [colonne])', description: 'Valeur à une position donnée.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'MATCH', categorie: CategorieFonctionExcel.rechercheReference, syntaxe: 'MATCH(valeur; plage; [type])', description: 'Position d’une valeur dans une plage.', supportTest: SupportTestEstime.probable),
  FonctionExcelInfo(nom: 'XLOOKUP', categorie: CategorieFonctionExcel.rechercheReference, syntaxe: 'XLOOKUP(valeur; plage_recherche; plage_résultat; [si_non_trouvé])', description: 'Recherche moderne (remplace VLOOKUP/HLOOKUP).', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'OFFSET', categorie: CategorieFonctionExcel.rechercheReference, syntaxe: 'OFFSET(référence; lignes; colonnes; [hauteur]; [largeur])', description: 'Référence décalée.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'CHOOSE', categorie: CategorieFonctionExcel.rechercheReference, syntaxe: 'CHOOSE(index; valeur1; [valeur2]; ...)', description: 'Choisit une valeur selon un index.', supportTest: SupportTestEstime.incertain),

  // --- Financier ---
  FonctionExcelInfo(nom: 'PMT', categorie: CategorieFonctionExcel.financier, syntaxe: 'PMT(taux; npm; va; [vc]; [type])', description: 'Paiement périodique d’un prêt.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'FV', categorie: CategorieFonctionExcel.financier, syntaxe: 'FV(taux; npm; vpm; [va]; [type])', description: 'Valeur future d’un placement.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'PV', categorie: CategorieFonctionExcel.financier, syntaxe: 'PV(taux; npm; vpm; [vc]; [type])', description: 'Valeur actuelle d’un placement.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'NPV', categorie: CategorieFonctionExcel.financier, syntaxe: 'NPV(taux; valeur1; [valeur2]; ...)', description: 'Valeur actuelle nette.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'IRR', categorie: CategorieFonctionExcel.financier, syntaxe: 'IRR(valeurs; [estimation])', description: 'Taux de rentabilité interne.', supportTest: SupportTestEstime.incertain),

  // --- Information ---
  FonctionExcelInfo(nom: 'ISBLANK', categorie: CategorieFonctionExcel.information, syntaxe: 'ISBLANK(valeur)', description: 'Vrai si la cellule est vide.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'ISNUMBER', categorie: CategorieFonctionExcel.information, syntaxe: 'ISNUMBER(valeur)', description: 'Vrai si la valeur est un nombre.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'ISTEXT', categorie: CategorieFonctionExcel.information, syntaxe: 'ISTEXT(valeur)', description: 'Vrai si la valeur est du texte.', supportTest: SupportTestEstime.incertain),
  FonctionExcelInfo(nom: 'ISERROR', categorie: CategorieFonctionExcel.information, syntaxe: 'ISERROR(valeur)', description: 'Vrai si la valeur est une erreur.', supportTest: SupportTestEstime.incertain),
];
