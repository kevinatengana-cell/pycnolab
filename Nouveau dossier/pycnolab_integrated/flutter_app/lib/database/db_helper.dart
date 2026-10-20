import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DbHelper {
  DbHelper._();

  static final DbHelper instance = DbHelper._();
  static const String _databaseName = 'pycnolab_studio.sqlite';
  static const int _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) return current;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final databasesPath = await databaseFactory.getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);
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
          await _createSchema(db);
        },
      ),
    );
    return _database!;
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
    await batch.commit(noResult: true);
  }
}
