import 'critere_model.dart';
import 'formule_model.dart';
import 'feuille_excel_model.dart';
import 'recapitulatif_agregat_model.dart';

class ProtocoleModel {
  const ProtocoleModel({
    this.id,
    required this.codeNorme,
    required this.titre,
    required this.categorie,
    this.version = 1,
    this.description,
    this.estValide = true,
    this.estDansCorbeille = false,
    required this.dateCreation,
    this.dateSuppression,
    this.formules = const <FormuleModel>[],
    this.criteres = const <CritereModel>[],
    this.feuillesExcel = const <FeuilleExcelModel>[],
    this.recapitulatif = const <RecapitulatifAgregatModel>[],
  });

  final int? id;
  final String codeNorme;
  final String titre;
  final String categorie;
  final int version;
  final String? description;
  final bool estValide;
  final bool estDansCorbeille;
  final String dateCreation;
  final String? dateSuppression;
  final List<FormuleModel> formules;
  final List<CritereModel> criteres;

  /// Structure Excel définie à l'étape 4 (Échantillon Zéro) : une entrée
  /// par onglet du fichier généré, avec ses variables, ses relais
  /// inter-feuille et ses briques algorithme.
  final List<FeuilleExcelModel> feuillesExcel;

  /// Agrégats du récapitulatif final, indépendants de toute feuille
  /// particulière puisqu'ils peuvent croiser plusieurs feuilles sources.
  final List<RecapitulatifAgregatModel> recapitulatif;

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'code_norme': codeNorme,
      'titre': titre,
      'categorie': categorie,
      'version': version,
      'description': description,
      'est_valide': estValide ? 1 : 0,
      'est_dans_corbeille': estDansCorbeille ? 1 : 0,
      'date_creation': dateCreation,
      'date_suppression': dateSuppression,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  factory ProtocoleModel.fromMap(Map<String, Object?> map, {
    List<FormuleModel> formules = const <FormuleModel>[],
    List<CritereModel> criteres = const <CritereModel>[],
    List<FeuilleExcelModel> feuillesExcel = const <FeuilleExcelModel>[],
    List<RecapitulatifAgregatModel> recapitulatif = const <RecapitulatifAgregatModel>[],
  }) {
    return ProtocoleModel(
      id: (map['id'] as num?)?.toInt(),
      codeNorme: map['code_norme'] as String? ?? '',
      titre: map['titre'] as String? ?? '',
      categorie: map['categorie'] as String? ?? '',
      version: (map['version'] as num?)?.toInt() ?? 1,
      description: map['description'] as String?,
      estValide: ((map['est_valide'] as num?)?.toInt() ?? 1) == 1,
      estDansCorbeille: ((map['est_dans_corbeille'] as num?)?.toInt() ?? 0) == 1,
      dateCreation: map['date_creation'] as String? ?? DateTime.now().toIso8601String(),
      dateSuppression: map['date_suppression'] as String?,
      formules: List.unmodifiable(formules),
      criteres: List.unmodifiable(criteres),
      feuillesExcel: List.unmodifiable(feuillesExcel),
      recapitulatif: List.unmodifiable(recapitulatif),
    );
  }

  ProtocoleModel copyWith({
    int? id,
    String? codeNorme,
    String? titre,
    String? categorie,
    int? version,
    String? description,
    bool? estValide,
    bool? estDansCorbeille,
    String? dateCreation,
    String? dateSuppression,
    List<FormuleModel>? formules,
    List<CritereModel>? criteres,
    List<FeuilleExcelModel>? feuillesExcel,
    List<RecapitulatifAgregatModel>? recapitulatif,
    bool clearDescription = false,
    bool clearDateSuppression = false,
  }) {
    return ProtocoleModel(
      id: id ?? this.id,
      codeNorme: codeNorme ?? this.codeNorme,
      titre: titre ?? this.titre,
      categorie: categorie ?? this.categorie,
      version: version ?? this.version,
      description: clearDescription ? null : (description ?? this.description),
      estValide: estValide ?? this.estValide,
      estDansCorbeille: estDansCorbeille ?? this.estDansCorbeille,
      dateCreation: dateCreation ?? this.dateCreation,
      dateSuppression: clearDateSuppression ? null : (dateSuppression ?? this.dateSuppression),
      formules: List.unmodifiable(formules ?? this.formules),
      criteres: List.unmodifiable(criteres ?? this.criteres),
      feuillesExcel: List.unmodifiable(feuillesExcel ?? this.feuillesExcel),
      recapitulatif: List.unmodifiable(recapitulatif ?? this.recapitulatif),
    );
  }

  /// Alias pour toProtocoleJson() assurant la compatibilité avec toJson().
  Map<String, Object?> toJson() => toProtocoleJson();

  /// Contrat complet envoyé au moteur Python pour exécution — distinct de
  /// toMap() qui ne sert qu'à la ligne SQL (essais_config). Ici tout est
  /// imbriqué : formules, critères, feuilles Excel avec leurs variables,
  /// relais et briques, et le récapitulatif.
  Map<String, Object?> toProtocoleJson() {
    return <String, Object?>{
      'code_norme': codeNorme,
      'titre': titre,
      'categorie': categorie,
      'version': version,
      'formules': formules
          .map((item) => <String, Object?>{
                'cle_variable': item.cleVariable,
                'libelle': item.libelle,
                'unite': item.unite,
                'expression': item.expression,
                'ordre_execution': item.ordreExecution,
              })
          .toList(),
      'criteres': criteres
          .map((item) => <String, Object?>{
                'cle_variable': item.cleVariable,
                'seuil_min': item.seuilMin,
                'seuil_max': item.seuilMax,
              })
          .toList(),
      'feuilles_excel': feuillesExcel.map((item) => item.toJson()).toList(),
      'recapitulatif': recapitulatif.map((item) => item.toJson()).toList(),
    };
  }
}