import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pycnolab/database/capture_dao.dart';
import 'package:pycnolab/database/db_helper.dart';

void main() {
  late DbHelper dbHelper;
  late CaptureDao dao;

  setUp(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dbHelper = DbHelper.forTesting();
    dao = CaptureDao(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  test('persists raw curves and entered compression dimensions', () async {
    final captureId = await dao.creerCapture(
      typeEssai: 'compression',
      origine: 'excel',
      nomFichier: 'mesures.xlsx',
      donneesMoteur: {
        'type_essai': 'compression',
        'gammes': [
          {
            'nom_gamme': 'F0',
            'echantillons': [
              {
                'identifiant': 'ECH1',
                'points_courbe': [
                  {'deplacement_mm': 0.1, 'force_newton': 10.0},
                  {'deplacement_mm': 0.2, 'force_newton': 20.0},
                ],
              },
              {
                'identifiant': 'ECH2',
                'points_courbe': [
                  {'deplacement_mm': 0.3, 'force_newton': 30.0},
                ],
              },
            ],
          },
        ],
      },
    );
    await dao.enregistrerGeometrie(captureId, {
      'l0_mm': 20.0,
      'section_mm2': 100.0,
      'dimensions_par_echantillon': {
        'F0': {
          'ECH2': {'l0_mm': 22.0, 'section_mm2': 120.0},
        },
      },
    });

    final capture = await dao.lireCapture(captureId);
    expect(capture, isNotNull);
    final gammes = capture!.donneesMoteur['gammes'] as List;
    final echantillons = (gammes.single as Map)['echantillons'] as List;
    expect((echantillons[0] as Map)['l0_mm'], 20.0);
    expect((echantillons[0] as Map)['section_mm2'], 100.0);
    expect((echantillons[1] as Map)['l0_mm'], 22.0);
    expect((echantillons[1] as Map)['section_mm2'], 120.0);
    expect((echantillons[0] as Map)['points_courbe'], [
      {'deplacement_mm': 0.1, 'force_newton': 10.0},
      {'deplacement_mm': 0.2, 'force_newton': 20.0},
    ]);
    expect(capture.nomFichier, 'mesures.xlsx');

    await dao.enregistrerGeometrie(captureId, {});

    final captureAfterEmptyUpdate = await dao.lireCapture(captureId);
    final gammesAfterEmptyUpdate =
        captureAfterEmptyUpdate!.donneesMoteur['gammes'] as List;
    final echantillonsAfterEmptyUpdate =
        (gammesAfterEmptyUpdate.single as Map)['echantillons'] as List;
    expect((echantillonsAfterEmptyUpdate[0] as Map)['section_mm2'], 100.0);
    expect((echantillonsAfterEmptyUpdate[1] as Map)['section_mm2'], 120.0);
    expect(
      captureAfterEmptyUpdate.geometrie['dimensions_par_echantillon'],
      capture.geometrie['dimensions_par_echantillon'],
    );
  });

  test('allows an in-app capture and deletes child rows by cascade', () async {
    final captureId = await dao.creerCapture(
      typeEssai: 'flexion',
      origine: 'saisie',
      donneesMoteur: {
        'type_essai': 'flexion',
        'gammes': [
          {
            'nom_gamme': 'Saisie manuelle',
            'echantillons': [
              {
                'identifiant': 'E1',
                'points_courbe': [
                  {'deplacement_mm': 0.5, 'force_newton': 50.0},
                ],
              },
            ],
          },
        ],
      },
    );
    await dao.enregistrerGeometrie(captureId, {
      'portee_mm': 100.0,
      'base_mm': 40.0,
      'hauteur_mm': 20.0,
    });
    await dao.enregistrerResultat(
      captureId: captureId,
      geometrie: {'portee_mm': 100.0},
      resultat: {'type_essai': 'flexion', 'gammes': []},
    );

    final capture = await dao.lireCapture(captureId);
    expect(capture!.origine, 'saisie');
    expect(capture.donneesMoteur['geometrie_flexion'], {
      'portee_mm': 100.0,
      'base_mm': 40.0,
      'hauteur_mm': 20.0,
    });

    await dao.supprimerCapture(captureId);
    final db = await dbHelper.database;
    expect(await db.query('gammes_capture'), isEmpty);
    expect(await db.query('echantillons_capture'), isEmpty);
    expect(await db.query('points_courbe'), isEmpty);
    expect(await db.query('resultats_capture'), isEmpty);
    expect(await db.query('captures'), isEmpty);
  });

  test('lists the latest saved calculation for the dashboard', () async {
    final captureId = await dao.creerCapture(
      typeEssai: 'traction',
      origine: 'excel',
      donneesMoteur: {
        'type_essai': 'traction',
        'gammes': [
          {
            'nom_gamme': 'Lot durable',
            'echantillons': [
              {'identifiant': 'ECH1', 'points_courbe': []},
            ],
          },
        ],
      },
    );
    await dao.enregistrerResultat(
      captureId: captureId,
      geometrie: {'l0_mm': 20.0},
      resultat: {
        'gammes': [
          {
            'nom_gamme': 'Lot durable',
            'resistance_moyenne_mpa': 10.0,
            'echantillons': [],
          },
        ],
      },
    );
    await dao.enregistrerResultat(
      captureId: captureId,
      geometrie: {'l0_mm': 20.0},
      resultat: {
        'gammes': [
          {
            'nom_gamme': 'Lot durable',
            'resistance_moyenne_mpa': 25.0,
            'echantillons': [],
          },
        ],
      },
    );

    final history = await dao.listerResultatsEnregistres();
    expect(history, hasLength(1));
    expect(history.single['capture_id'], captureId);
    final result = (history.single['donnees'] as Map)['gammes'] as List;
    expect((result.single as Map)['resistance_moyenne_mpa'], 25.0);
    final latest = await dao.lireDernierResultat(captureId);
    expect(
      ((latest!['gammes'] as List).single as Map)['resistance_moyenne_mpa'],
      25.0,
    );
  });
}
