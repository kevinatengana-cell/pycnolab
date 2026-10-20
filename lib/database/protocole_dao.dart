import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/critere_model.dart';
import '../models/formule_model.dart';
import '../models/protocole_model.dart';
import '../models/feuille_excel_model.dart';
import '../models/variable_excel_model.dart';
import '../models/relais_excel_model.dart';
import '../models/brique_algorithme_model.dart';
import '../models/recapitulatif_agregat_model.dart';
import 'db_helper.dart';

class ProtocoleDao {
  ProtocoleDao({DbHelper? dbHelper}) : _dbHelper = dbHelper ?? DbHelper.instance;

  final DbHelper _dbHelper;

  Future<int> saveNouveauProtocole(ProtocoleModel model) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      final essaiId = await txn.insert('essais_config', model.toMap());
      await _insertChildren(txn, essaiId, model);
      return essaiId;
    });
  }

  Future<void> remplacerProtocole(ProtocoleModel model) async {
    final id = model.id;
    if (id == null) throw ArgumentError('Un identifiant est requis pour remplacer un protocole.');
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final updated = await txn.update(
        'essais_config',
        model.copyWith(id: null).toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated == 0) throw StateError('Le protocole $id est introuvable.');
      await txn.delete('formules_calcul', where: 'essai_id = ?', whereArgs: [id]);
      await txn.delete('criteres_conformite', where: 'essai_id = ?', whereArgs: [id]);
      // ON DELETE CASCADE se charge de variables_excel/relais_excel/briques_algorithme
      // à travers feuilles_excel.
      await txn.delete('feuilles_excel', where: 'essai_id = ?', whereArgs: [id]);
      await txn.delete('recapitulatif_agregats', where: 'essai_id = ?', whereArgs: [id]);
      await _insertChildren(txn, id, model);
    });
  }

  Future<int> creerNouvelleVersion(ProtocoleModel model) async {
    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      final idCourant = model.id;
      if (idCourant != null) {
        await txn.update(
          'essais_config',
          <String, Object?>{'est_valide': 0},
          where: 'id = ?',
          whereArgs: [idCourant],
        );
      } else {
        await txn.update(
          'essais_config',
          <String, Object?>{'est_valide': 0},
          where: 'code_norme = ? AND est_valide = 1',
          whereArgs: [model.codeNorme],
        );
      }
      final nouvelleVersion = model.copyWith(
        id: null,
        version: model.version + 1,
        estValide: true,
        estDansCorbeille: false,
        dateCreation: DateTime.now().toIso8601String(),
        clearDateSuppression: true,
      );
      final newId = await txn.insert('essais_config', nouvelleVersion.toMap());
      await _insertChildren(txn, newId, nouvelleVersion);
      return newId;
    });
  }

  Future<void> deplacerEnCorbeille(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'essais_config',
      <String, Object?>{
        'est_dans_corbeille': 1,
        'date_suppression': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> supprimerDefinitivement(int id) async {
    final db = await _dbHelper.database;
    await db.delete('essais_config', where: 'id = ?', whereArgs: [id]);
  }

  Future<ProtocoleModel?> findById(int id, {bool inclureCorbeille = true}) async {
    final db = await _dbHelper.database;
    final rows = await db.query('essais_config', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _hydrate(db, Map<String, Object?>.from(rows.first), inclureCorbeille: inclureCorbeille);
  }

  Future<ProtocoleModel?> findByCodeNorme(String codeNorme, {bool inclureCorbeille = true}) async {
    final db = await _dbHelper.database;
    final where = inclureCorbeille ? 'code_norme = ?' : 'code_norme = ? AND est_dans_corbeille = 0';
    final rows = await db.query(
      'essais_config',
      where: where,
      whereArgs: [codeNorme],
      orderBy: 'version DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _hydrate(db, Map<String, Object?>.from(rows.first), inclureCorbeille: inclureCorbeille);
  }

  Future<List<ProtocoleModel>> lister({bool corbeille = false}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'essais_config',
      where: 'est_dans_corbeille = ?',
      whereArgs: [corbeille ? 1 : 0],
      orderBy: 'code_norme COLLATE NOCASE, version DESC',
    );
    final result = <ProtocoleModel>[];
    for (final row in rows) {
      result.add(await _hydrate(db, Map<String, Object?>.from(row)));
    }
    return result;
  }

  Future<ProtocoleModel> _hydrate(DatabaseExecutor db, Map<String, Object?> row, {bool inclureCorbeille = true}) async {
    final id = (row['id'] as num).toInt();
    final formuleRows = await db.query('formules_calcul', where: 'essai_id = ?', whereArgs: [id], orderBy: 'ordre_execution ASC');
    final critereRows = await db.query('criteres_conformite', where: 'essai_id = ?', whereArgs: [id], orderBy: 'cle_variable ASC');
    final feuilleRows = await db.query('feuilles_excel', where: 'essai_id = ?', whereArgs: [id], orderBy: 'ordre ASC');
    final recapRows = await db.query('recapitulatif_agregats', where: 'essai_id = ?', whereArgs: [id]);

    final feuilles = <FeuilleExcelModel>[];
    for (final feuilleRow in feuilleRows) {
      final feuilleId = (feuilleRow['id'] as num).toInt();
      final variableRows = await db.query('variables_excel', where: 'feuille_id = ?', whereArgs: [feuilleId], orderBy: 'offset_colonne ASC, offset_ligne ASC');
      final relaisRows = await db.query('relais_excel', where: 'feuille_id = ?', whereArgs: [feuilleId]);
      final briqueRows = await db.query('briques_algorithme', where: 'feuille_id = ?', whereArgs: [feuilleId]);
      feuilles.add(FeuilleExcelModel.fromMap(
        Map<String, Object?>.from(feuilleRow),
        variables: variableRows.map((item) => VariableExcelModel.fromMap(Map<String, Object?>.from(item))).toList(growable: false),
        relais: relaisRows.map((item) => RelaisExcelModel.fromMap(Map<String, Object?>.from(item))).toList(growable: false),
        briques: briqueRows.map((item) => BriqueAlgorithmeModel.fromMap(Map<String, Object?>.from(item))).toList(growable: false),
      ));
    }

    return ProtocoleModel.fromMap(
      row,
      formules: formuleRows.map((item) => FormuleModel.fromMap(Map<String, Object?>.from(item))).toList(growable: false),
      criteres: critereRows.map((item) => CritereModel.fromMap(Map<String, Object?>.from(item))).toList(growable: false),
      feuillesExcel: feuilles,
      recapitulatif: recapRows.map((item) => RecapitulatifAgregatModel.fromMap(Map<String, Object?>.from(item))).toList(growable: false),
    );
  }

  Future<void> _insertChildren(DatabaseExecutor txn, int essaiId, ProtocoleModel model) async {
    for (var index = 0; index < model.formules.length; index++) {
      final formule = model.formules[index].copyWith(essaiId: essaiId, ordreExecution: index + 1);
      await txn.insert('formules_calcul', formule.toMap());
    }
    for (final critere in model.criteres) {
      await txn.insert('criteres_conformite', critere.copyWith(essaiId: essaiId).toMap());
    }
    for (var index = 0; index < model.feuillesExcel.length; index++) {
      final feuille = model.feuillesExcel[index].copyWith(essaiId: essaiId, ordre: index + 1);
      final feuilleId = await txn.insert('feuilles_excel', feuille.toMap());
      for (var vIndex = 0; vIndex < feuille.variables.length; vIndex++) {
        final variable = feuille.variables[vIndex].copyWith(feuilleId: feuilleId);
        await txn.insert('variables_excel', variable.toMap());
      }
      for (final relais in feuille.relais) {
        await txn.insert('relais_excel', relais.copyWith(feuilleId: feuilleId).toMap());
      }
      for (final brique in feuille.briques) {
        await txn.insert('briques_algorithme', brique.copyWith(feuilleId: feuilleId).toMap());
      }
    }
    for (final agregat in model.recapitulatif) {
      await txn.insert('recapitulatif_agregats', agregat.copyWith(essaiId: essaiId).toMap());
    }
  }
}
