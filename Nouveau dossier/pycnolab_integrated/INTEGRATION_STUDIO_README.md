# Intégration du Studio dans PycnoLab

Cette copie rassemble l’application Flutter existante et le moteur Python sous une structure cohérente.

## Arborescence

```text
pycnolab_integrated/
├── flutter_app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── config_essai_screen.dart
│   │   │   ├── import_screen.dart
│   │   │   ├── resultats_screen.dart
│   │   │   ├── compare_screen.dart
│   │   │   ├── protocole_runner_screen.dart
│   │   │   └── studio/
│   │   │       ├── studio_main_screen.dart
│   │   │       └── widgets/
│   │   ├── models/
│   │   ├── database/
│   │   └── services/
│   │       └── studio_protocol_runtime_service.dart
│   └── pubspec.yaml
└── python_engine/
    ├── main.py
    └── moteur_python/
        ├── modeles/
        ├── calculs/
        ├── import_excel/
        └── export_excel/
```

## Flux Studio intégré

`HomeScreen` ouvre maintenant la route `/studio`. `StudioMainScreen` collecte les métadonnées, les formules et les critères, puis sauvegarde un `ProtocoleModel` dans SQLite avec `ProtocoleDao`.

`ProtocoleRunnerScreen` ne lit plus exclusivement le dossier JSON historique. Il appelle `ProtocoleDao.lister(corbeille: false)`, affiche les protocoles actifs du Studio, puis `StudioProtocolRuntimeService` transforme temporairement le protocole SQLite en JSON compatible avec `MoteurProtocole`.

Le JSON temporaire est transmis par `PythonEngineService.executerProtocole` à :

```text
POST /protocoles/executer
```

Le backend lit le fichier Excel, reconstruit une `Gamme`, exécute `MoteurProtocole`, sérialise un `ResultatGamme`, puis Flutter l’ajoute à `HistoryService` et l’affiche dans `ResultatsScreen`.

## Démarrage desktop en développement

Depuis `flutter_app`, créez d’abord l’environnement Python :

```bash
cd ../python_engine
python -m venv .venv
# Windows
.venv/Scripts/pip install fastapi uvicorn pydantic pandas openpyxl simpleeval
# Linux/macOS
.venv/bin/pip install fastapi uvicorn pydantic pandas openpyxl simpleeval
```

Lancez ensuite Flutter depuis `flutter_app` :

```bash
flutter pub get
flutter run -d windows
```

Le lanceur cherche `../python_engine/.venv/Scripts/python.exe` sous Windows ou `../python_engine/.venv/bin/python` sous Linux/macOS, puis lance `uvicorn main:app --host 127.0.0.1 --port 8123`.

## Points à vérifier dans l’IDE

Le code Python de cette copie ne contient plus les marqueurs de conflit Git qui étaient présents dans le `main.py` fourni. Il faut néanmoins exécuter les tests scientifiques avec de vrais fichiers Excel représentatifs.

Le démarrage automatique par sous-processus est conçu pour desktop. Android et iOS nécessitent une stratégie native différente : serveur local embarqué, extension native, ou exécution du moteur compilé dans un processus compatible avec la plateforme.

La table SQLite `resultats_lots` existe dans le schéma du Studio, mais `HistoryService` reste actuellement une liste mémoire. Une prochaine étape devra persister les résultats dans cette table si l’historique doit survivre à la fermeture de l’application.
