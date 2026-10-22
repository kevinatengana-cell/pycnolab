import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbHelper {
  DbHelper._([this._inMemory = false]);

  DbHelper.forTesting() : this._(true);

  static final DbHelper instance = DbHelper._();
  static const String _databaseName = 'pycnolab_studio.sqlite';
  // v2 : ajout des tables de structure Excel (étape 4).
  // v3 : ajout de la colonne manifestation_gamme sur feuilles_excel (n).
  // v4 : grille libre — hauteur_bloc/largeur_bloc sur feuilles_excel
  //      (remplace le calcul largeurBlocDeduite) ; offset_ligne/
  //      offset_colonne sur variables_excel (remplace ordre, dont la
  //      position était implicite selon le gabarit). La colonne `ordre`
  //      existante sur variables_excel est laissée en place (inoffensive,
  //      plus utilisée par le code) plutôt que supprimée : DROP COLUMN
  //      n'est fiable qu'à partir de SQLite 3.35, version non confirmée
  //      ici pour sqflite_common_ffi.
  // v5 : captures brutes, géométries saisies, points de courbe et résultats.
  static const int _databaseVersion = 5;

  final bool _inMemory;
  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) return current;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final path = _inMemory
        ? inMemoryDatabasePath
        : await _databaseFilePath();
    _database = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // CREATE TABLE IF NOT EXISTS ne modifie jamais une table déjà
          // présente : il faut une vraie migration pour une base créée
          // avant cette colonne.
          await _createSchema(db);
          if (oldVersion < 3) {
            try {
              await db.execute(
                  "ALTER TABLE feuilles_excel ADD COLUMN manifestation_gamme TEXT NOT NULL DEFAULT 'uneFeuilleParGamme'");
            } catch (_) {
              // Colonne déjà présente (ex. base déjà créée directement en v3) — sans danger.
            }
          }
          if (oldVersion < 4) {
            try {
              await db.execute(
                  'ALTER TABLE feuilles_excel ADD COLUMN hauteur_bloc INTEGER');
            } catch (_) {
              // Colonne déjà présente — sans danger.
            }
            try {
              await db.execute(
                  'ALTER TABLE feuilles_excel ADD COLUMN largeur_bloc INTEGER');
            } catch (_) {
              // Colonne déjà présente — sans danger.
            }
            try {
              await db.execute(
                  'ALTER TABLE variables_excel ADD COLUMN offset_ligne INTEGER NOT NULL DEFAULT 0');
            } catch (_) {
              // Colonne déjà présente — sans danger.
            }
            try {
              await db.execute(
                  'ALTER TABLE variables_excel ADD COLUMN offset_colonne INTEGER NOT NULL DEFAULT 0');
            } catch (_) {
              // Colonne déjà présente — sans danger.
            }
          }
        },
      ),
    );
    return _database!;
  }

  Future<String> _databaseFilePath() async {
    if (!Platform.isWindows) {
      final databasesPath = await databaseFactory.getDatabasesPath();
      await Directory(databasesPath).create(recursive: true);
      return p.join(databasesPath, _databaseName);
    }

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.trim().isEmpty) {
      throw StateError('Windows ne fournit pas le dossier LOCALAPPDATA.');
    }

    final newDirectory = Directory(
      p.join(localAppData, 'PycnoLab', 'data'),
    );
    await newDirectory.create(recursive: true);
    final newPath = p.join(newDirectory.path, _databaseName);

    // Conserver les donnees existantes si la base se trouvait a l'ancien endroit.
    final oldDatabasesPath = await databaseFactory.getDatabasesPath();
    final oldPath = p.join(oldDatabasesPath, _databaseName);
    final normalizedOldPath = p.normalize(oldPath).toLowerCase();
    final normalizedNewPath = p.normalize(newPath).toLowerCase();
    final samePath = normalizedOldPath == normalizedNewPath;

    if (!samePath &&
        !await File(newPath).exists() &&
        await File(oldPath).exists()) {
      await File(oldPath).copy(newPath);

      // Recuperer les ecritures SQLite non checkpointed si le mode WAL est actif.
      final oldWal = File('$oldPath-wal');
      if (await oldWal.exists()) {
        await oldWal.copy('$newPath-wal');
      }
    }

    return newPath;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  static Future<void> _createSchema(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE IF NOT EXISTS essais_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code_norme TEXT NOT NULL,
        titre TEXT NOT NULL,
        categorie TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        description TEXT,
        est_valide INTEGER NOT NULL DEFAULT 1,
        est_dans_corbeille INTEGER NOT NULL DEFAULT 0,
        date_creation TEXT NOT NULL,
        date_suppression TEXT
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS formules_calcul (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        essai_id INTEGER NOT NULL,
        ordre_execution INTEGER NOT NULL,
        cle_variable TEXT NOT NULL,
        libelle TEXT NOT NULL,
        unite TEXT NOT NULL,
        expression TEXT NOT NULL,
        FOREIGN KEY (essai_id) REFERENCES essais_config(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS criteres_conformite (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        essai_id INTEGER NOT NULL,
        cle_variable TEXT NOT NULL,
        seuil_min REAL,
        seuil_max REAL,
        FOREIGN KEY (essai_id) REFERENCES essais_config(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS resultats_lots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        essai_id INTEGER NOT NULL,
        nom_materiau TEXT NOT NULL,
        horodatage TEXT NOT NULL,
        statut_conformite TEXT NOT NULL,
        chemin_excel_source TEXT NOT NULL,
        donnees_json_brutes TEXT NOT NULL,
        est_dans_corbeille INTEGER NOT NULL DEFAULT 0,
        date_suppression TEXT,
        FOREIGN KEY (essai_id) REFERENCES essais_config(id) ON DELETE CASCADE
      )
    ''');

    // --- Étape 4 : structure Excel (Échantillon Zéro) ---
    batch.execute('''
      CREATE TABLE IF NOT EXISTS feuilles_excel (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        essai_id INTEGER NOT NULL,
        ordre INTEGER NOT NULL,
        nom_feuille TEXT NOT NULL,
        gabarit TEXT NOT NULL,
        manifestation_gamme TEXT NOT NULL DEFAULT 'uneFeuilleParGamme',
        hauteur_bloc INTEGER,
        largeur_bloc INTEGER,
        nom_table_ech0 TEXT,
        FOREIGN KEY (essai_id) REFERENCES essais_config(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS variables_excel (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feuille_id INTEGER NOT NULL,
        offset_ligne INTEGER NOT NULL DEFAULT 0,
        offset_colonne INTEGER NOT NULL DEFAULT 0,
        nom_technique TEXT NOT NULL,
        portee TEXT NOT NULL,
        origine TEXT NOT NULL,
        formule TEXT,
        FOREIGN KEY (feuille_id) REFERENCES feuilles_excel(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS relais_excel (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feuille_id INTEGER NOT NULL,
        nom_technique TEXT NOT NULL,
        feuille_source TEXT NOT NULL,
        variable_source TEXT NOT NULL,
        FOREIGN KEY (feuille_id) REFERENCES feuilles_excel(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS briques_algorithme (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feuille_id INTEGER NOT NULL,
        nom_technique TEXT NOT NULL,
        brique TEXT NOT NULL,
        parametres_json TEXT NOT NULL,
        variable_x TEXT,
        variable_y TEXT,
        FOREIGN KEY (feuille_id) REFERENCES feuilles_excel(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS recapitulatif_agregats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        essai_id INTEGER NOT NULL,
        feuille_source TEXT NOT NULL,
        variable_source TEXT NOT NULL,
        fonction TEXT NOT NULL,
        FOREIGN KEY (essai_id) REFERENCES essais_config(id) ON DELETE CASCADE
      )
    ''');
    await batch.commit(noResult: true);
    await _createCaptureSchema(db);
  }

  static Future<void> _createCaptureSchema(DatabaseExecutor db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE IF NOT EXISTS captures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type_essai TEXT NOT NULL,
        origine TEXT NOT NULL,
        nom_fichier TEXT,
        chemin_source TEXT,
        date_creation TEXT NOT NULL,
        configuration_json TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS geometries_capture (
        capture_id INTEGER PRIMARY KEY,
        l0_mm REAL,
        section_mm2 REAL,
        portee_mm REAL,
        base_mm REAL,
        hauteur_mm REAL,
        geometrie_json TEXT NOT NULL DEFAULT '{}',
        FOREIGN KEY (capture_id) REFERENCES captures(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS gammes_capture (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        capture_id INTEGER NOT NULL,
        ordre INTEGER NOT NULL,
        nom_gamme TEXT NOT NULL,
        donnees_json TEXT NOT NULL DEFAULT '{}',
        UNIQUE (capture_id, ordre),
        UNIQUE (capture_id, nom_gamme),
        FOREIGN KEY (capture_id) REFERENCES captures(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS echantillons_capture (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gamme_id INTEGER NOT NULL,
        ordre INTEGER NOT NULL,
        identifiant TEXT NOT NULL,
        l0_mm REAL,
        section_mm2 REAL,
        largeur_mm REAL,
        epaisseur_mm REAL,
        diametre_mm REAL,
        diametre_moyen_mm REAL,
        diametres_json TEXT,
        force_rupture_newton REAL,
        deplacement_rupture_mm REAL,
        donnees_json TEXT NOT NULL DEFAULT '{}',
        UNIQUE (gamme_id, ordre),
        UNIQUE (gamme_id, identifiant),
        FOREIGN KEY (gamme_id) REFERENCES gammes_capture(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS points_courbe (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        echantillon_id INTEGER NOT NULL,
        ordre INTEGER NOT NULL,
        deplacement_mm REAL NOT NULL,
        force_newton REAL NOT NULL,
        UNIQUE (echantillon_id, ordre),
        FOREIGN KEY (echantillon_id) REFERENCES echantillons_capture(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE IF NOT EXISTS resultats_capture (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        capture_id INTEGER NOT NULL,
        calcule_le TEXT NOT NULL,
        geometrie_json TEXT NOT NULL,
        donnees_json TEXT NOT NULL,
        FOREIGN KEY (capture_id) REFERENCES captures(id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_gammes_capture_capture ON gammes_capture(capture_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_echantillons_capture_gamme ON echantillons_capture(gamme_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_points_courbe_echantillon ON points_courbe(echantillon_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_resultats_capture_date ON resultats_capture(capture_id, calcule_le)');
    await batch.commit(noResult: true);
  }
}
