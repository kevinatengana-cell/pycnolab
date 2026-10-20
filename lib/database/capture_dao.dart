import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/capture_essai_model.dart';
import 'db_helper.dart';

class CaptureDao {
  CaptureDao({DbHelper? dbHelper}) : _dbHelper = dbHelper ?? DbHelper.instance;

  final DbHelper _dbHelper;

  Future<int> creerCapture({
    required String typeEssai,
    required String origine,
    required Map<String, Object?> donneesMoteur,
    String? nomFichier,
    String? cheminSource,
    Map<String, Object?> configuration = const {},
  }) async {
    final gammes = donneesMoteur['gammes'];
    if (gammes is! List || gammes.isEmpty) {
      throw FormatException(
          'Le classeur ne contient aucune gamme exploitable.');
    }

    final db = await _dbHelper.database;
    return db.transaction<int>((txn) async {
      final captureId = await txn.insert('captures', {
        'type_essai': typeEssai,
        'origine': origine,
        'nom_fichier': nomFichier,
        'chemin_source': cheminSource,
        'date_creation': DateTime.now().toIso8601String(),
        'configuration_json': jsonEncode(configuration),
      });

      for (var gammeIndex = 0; gammeIndex < gammes.length; gammeIndex++) {
        final gamme = _stringMap(gammes[gammeIndex], 'gamme');
        final nomGamme = gamme['nom_gamme'];
        final echantillons = gamme['echantillons'];
        if (nomGamme is! String || echantillons is! List) {
          throw const FormatException('Structure de gamme invalide.');
        }
        final donneesGamme = Map<String, Object?>.from(gamme)
          ..remove('echantillons');
        final gammeId = await txn.insert('gammes_capture', {
          'capture_id': captureId,
          'ordre': gammeIndex,
          'nom_gamme': nomGamme,
          'donnees_json': jsonEncode(donneesGamme),
        });

        for (var sampleIndex = 0;
            sampleIndex < echantillons.length;
            sampleIndex++) {
          final sample = _stringMap(echantillons[sampleIndex], 'échantillon');
          final identifiant = sample['identifiant'];
          final points = sample['points_courbe'] ?? const [];
          if (identifiant is! String || points is! List) {
            throw const FormatException('Structure d’échantillon invalide.');
          }
          final donneesEchantillon = Map<String, Object?>.from(sample)
            ..remove('points_courbe');
          final echantillonId = await txn.insert('echantillons_capture', {
            'gamme_id': gammeId,
            'ordre': sampleIndex,
            'identifiant': identifiant,
            'l0_mm': _num(sample['l0_mm']),
            'section_mm2': _num(sample['section_mm2']),
            'largeur_mm': _num(sample['largeur_mm']),
            'epaisseur_mm': _num(sample['epaisseur_mm']),
            'diametre_mm': _num(sample['diametre_mm']),
            'diametre_moyen_mm': _num(sample['diametre_moyen_mm']),
            'diametres_json': sample['diametres_mm'] == null
                ? null
                : jsonEncode(sample['diametres_mm']),
            'force_rupture_newton': _num(sample['force_rupture_newton']),
            'deplacement_rupture_mm': _num(sample['deplacement_rupture_mm']),
            'donnees_json': jsonEncode(donneesEchantillon),
          });

          for (var pointIndex = 0; pointIndex < points.length; pointIndex++) {
            final point = _stringMap(points[pointIndex], 'point de courbe');
            final deplacement = _num(point['deplacement_mm']);
            final force = _num(point['force_newton']);
            if (deplacement == null || force == null) {
              throw const FormatException('Point de courbe incomplet.');
            }
            await txn.insert('points_courbe', {
              'echantillon_id': echantillonId,
              'ordre': pointIndex,
              'deplacement_mm': deplacement,
              'force_newton': force,
            });
          }
        }
      }
      return captureId;
    });
  }

  Future<void> enregistrerGeometrie(
    int captureId,
    Map<String, Object?> geometrie,
  ) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final captureRows = await txn.query(
        'captures',
        columns: ['type_essai'],
        where: 'id = ?',
        whereArgs: [captureId],
        limit: 1,
      );
      if (captureRows.isEmpty) {
        throw StateError('La capture $captureId est introuvable.');
      }

      final geometryRows = await txn.query(
        'geometries_capture',
        columns: ['geometrie_json'],
        where: 'capture_id = ?',
        whereArgs: [captureId],
        limit: 1,
      );
      final previousGeometry = geometryRows.isEmpty
          ? <String, Object?>{}
          : _decodeMap(geometryRows.first['geometrie_json'] as String);
      final effectiveGeometry = <String, Object?>{
        ...previousGeometry,
        ...geometrie,
      };
      final newDimensions = geometrie['dimensions_par_echantillon'];
      if (newDimensions is Map) {
        if (captureRows.first['type_essai'] == 'flexion') {
          // En flexion, la géométrie par échantillon est un état complet :
          // une map vide signifie que l'utilisateur est repassé en mode global.
          effectiveGeometry['dimensions_par_echantillon'] =
              _stringMap(newDimensions, 'dimensions par échantillon');
        } else {
          final mergedDimensions = <String, Object?>{
            ..._stringMap(
              previousGeometry['dimensions_par_echantillon'] ?? {},
              'dimensions précédentes',
            ),
          };
          for (final gammeEntry in newDimensions.entries) {
            final oldSamples = _stringMap(
              mergedDimensions[gammeEntry.key] ?? {},
              'dimensions gamme précédentes',
            );
            mergedDimensions[gammeEntry.key.toString()] = {
              ...oldSamples,
              ..._stringMap(gammeEntry.value, 'dimensions gamme'),
            };
          }
          effectiveGeometry['dimensions_par_echantillon'] = mergedDimensions;
        }
      } else if (geometrie.isNotEmpty &&
          captureRows.first['type_essai'] == 'compression') {
        effectiveGeometry.remove('dimensions_par_echantillon');
      }

      await txn.insert(
        'geometries_capture',
        {
          'capture_id': captureId,
          'l0_mm': _num(effectiveGeometry['l0_mm']),
          'section_mm2': _num(effectiveGeometry['section_mm2']),
          'portee_mm': _num(effectiveGeometry['portee_mm']),
          'base_mm': _num(effectiveGeometry['base_mm']),
          'hauteur_mm': _num(effectiveGeometry['hauteur_mm']),
          'geometrie_json': jsonEncode(effectiveGeometry),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final typeEssai = captureRows.first['type_essai'] as String;
      if (typeEssai != 'compression') return;
      final dimensionsParEchantillon = _stringMap(
          effectiveGeometry['dimensions_par_echantillon'] ?? {}, 'dimensions');
      final gammes = await txn.query(
        'gammes_capture',
        columns: ['id', 'nom_gamme'],
        where: 'capture_id = ?',
        whereArgs: [captureId],
      );
      for (final gamme in gammes) {
        final gammeId = (gamme['id'] as num).toInt();
        final nomGamme = gamme['nom_gamme'] as String;
        final parEchantillon = _stringMap(
            dimensionsParEchantillon[nomGamme] ?? {}, 'dimensions gamme');
        final echantillons = await txn.query(
          'echantillons_capture',
          columns: ['id', 'identifiant'],
          where: 'gamme_id = ?',
          whereArgs: [gammeId],
        );
        for (final echantillon in echantillons) {
          final identifiant = echantillon['identifiant'] as String;
          final dimensions = _stringMap(
              parEchantillon[identifiant] ?? {}, 'dimensions échantillon');
          final updatedDimensions = <String, Object?>{};
          final l0 =
              _num(dimensions['l0_mm']) ?? _num(effectiveGeometry['l0_mm']);
          final section = _num(dimensions['section_mm2']) ??
              _num(effectiveGeometry['section_mm2']);
          if (l0 != null) updatedDimensions['l0_mm'] = l0;
          if (section != null) updatedDimensions['section_mm2'] = section;
          if (updatedDimensions.isNotEmpty) {
            await txn.update(
              'echantillons_capture',
              updatedDimensions,
              where: 'id = ?',
              whereArgs: [(echantillon['id'] as num).toInt()],
            );
          }
        }
      }
    });
  }

  Future<void> enregistrerResultat({
    required int captureId,
    required Map<String, Object?> geometrie,
    required Map<String, Object?> resultat,
  }) async {
    final db = await _dbHelper.database;
    await db.insert('resultats_capture', {
      'capture_id': captureId,
      'calcule_le': DateTime.now().toIso8601String(),
      'geometrie_json': jsonEncode(geometrie),
      'donnees_json': jsonEncode(resultat),
    });
  }

  Future<List<Map<String, Object?>>> listerResultatsEnregistres() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT c.id AS capture_id, c.type_essai, r.calcule_le, r.donnees_json
      FROM captures c
      JOIN resultats_capture r ON r.capture_id = c.id
      WHERE r.id = (
        SELECT r2.id
        FROM resultats_capture r2
        WHERE r2.capture_id = c.id
        ORDER BY r2.calcule_le DESC, r2.id DESC
        LIMIT 1
      )
      ORDER BY r.calcule_le DESC, r.id DESC
    ''');
    return rows
        .map((row) => <String, Object?>{
              'capture_id': row['capture_id'],
              'type_essai': row['type_essai'],
              'calcule_le': row['calcule_le'],
              'donnees': _decodeMap(row['donnees_json'] as String),
            })
        .toList(growable: false);
  }

  Future<Map<String, Object?>?> lireDernierResultat(int captureId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'resultats_capture',
      where: 'capture_id = ?',
      whereArgs: [captureId],
      orderBy: 'calcule_le DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeMap(rows.first['donnees_json'] as String);
  }

  Future<CaptureEssai?> lireCapture(int captureId) async {
    final db = await _dbHelper.database;
    final captureRows = await db.query(
      'captures',
      where: 'id = ?',
      whereArgs: [captureId],
      limit: 1,
    );
    if (captureRows.isEmpty) return null;
    final capture = captureRows.first;
    final geometryRows = await db.query(
      'geometries_capture',
      where: 'capture_id = ?',
      whereArgs: [captureId],
      limit: 1,
    );
    final geometrie = geometryRows.isEmpty
        ? <String, Object?>{}
        : _decodeMap(geometryRows.first['geometrie_json'] as String);
    final donnees = <String, Object?>{
      'type_essai': capture['type_essai'],
      'source': capture['chemin_source'] ?? 'capture:$captureId',
      'gammes': <Map<String, Object?>>[],
    };

    final gammes = await db.query(
      'gammes_capture',
      where: 'capture_id = ?',
      whereArgs: [captureId],
      orderBy: 'ordre ASC',
    );
    final donneesGammes = donnees['gammes'] as List<Map<String, Object?>>;
    for (final gamme in gammes) {
      final gammeData = _decodeMap(gamme['donnees_json'] as String)
        ..['nom_gamme'] = gamme['nom_gamme'];
      gammeData['echantillons'] = <Map<String, Object?>>[];
      final donneesEchantillons =
          gammeData['echantillons'] as List<Map<String, Object?>>;
      final echantillons = await db.query(
        'echantillons_capture',
        where: 'gamme_id = ?',
        whereArgs: [(gamme['id'] as num).toInt()],
        orderBy: 'ordre ASC',
      );
      for (final echantillon in echantillons) {
        final sample = _decodeMap(echantillon['donnees_json'] as String)
          ..['identifiant'] = echantillon['identifiant'];
        for (final field in const [
          'l0_mm',
          'section_mm2',
          'largeur_mm',
          'epaisseur_mm',
          'diametre_mm',
          'diametre_moyen_mm',
          'force_rupture_newton',
          'deplacement_rupture_mm',
        ]) {
          final value = echantillon[field];
          if (value != null) sample[field] = value;
        }
        final diametres = echantillon['diametres_json'];
        if (diametres != null) {
          sample['diametres_mm'] = jsonDecode(diametres as String);
        }
        final points = await db.query(
          'points_courbe',
          where: 'echantillon_id = ?',
          whereArgs: [(echantillon['id'] as num).toInt()],
          orderBy: 'ordre ASC',
        );
        sample['points_courbe'] = points
            .map((point) => <String, Object?>{
                  'deplacement_mm': point['deplacement_mm'],
                  'force_newton': point['force_newton'],
                })
            .toList(growable: false);
        donneesEchantillons.add(sample);
      }
      donneesGammes.add(gammeData);
    }
    if (capture['type_essai'] == 'flexion' && geometrie.isNotEmpty) {
      donnees['geometrie_flexion'] = geometrie;
    }

    return CaptureEssai(
      id: captureId,
      typeEssai: capture['type_essai'] as String,
      origine: capture['origine'] as String,
      dateCreation: DateTime.parse(capture['date_creation'] as String),
      nomFichier: capture['nom_fichier'] as String?,
      cheminSource: capture['chemin_source'] as String?,
      donneesMoteur: donnees,
      geometrie: geometrie,
      configuration: _decodeMap(capture['configuration_json'] as String),
    );
  }

  Future<void> supprimerCapture(int captureId) async {
    final db = await _dbHelper.database;
    await db.delete('captures', where: 'id = ?', whereArgs: [captureId]);
  }

  static Map<String, Object?> _stringMap(Object? value, String field) {
    if (value is! Map) throw FormatException('Champ $field invalide.');
    return Map<String, Object?>.from(value);
  }

  static Map<String, Object?> _decodeMap(String value) =>
      Map<String, Object?>.from(jsonDecode(value) as Map);

  static double? _num(Object? value) => value is num ? value.toDouble() : null;
}
