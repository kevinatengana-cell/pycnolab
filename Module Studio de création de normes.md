# Module Studio de création de normes

Ce dossier contient les fichiers Dart du module Studio pour PycnoLab. Copiez le contenu de `lib/` dans le dossier `lib/` de votre projet Flutter.

## Dépendances requises

Ajoutez au `pubspec.yaml` du projet principal les dépendances suivantes, puis exécutez `flutter pub get` :

```yaml
dependencies:
  flutter:
    sdk: flutter
  path: ^1.9.0
  sqflite_common_ffi: ^2.3.3
```

Initialisez la base au démarrage de l’application ou laissez `DbHelper.instance.database` effectuer l’initialisation paresseuse. Sur Windows, l’application doit être construite avec le support Desktop Flutter activé.

## Fichiers fournis

| Domaine | Fichier |
|---|---|
| Modèle | `lib/models/protocole_model.dart` |
| Modèle | `lib/models/formule_model.dart` |
| Modèle | `lib/models/critere_model.dart` |
| SQLite | `lib/database/db_helper.dart` |
| DAO | `lib/database/protocole_dao.dart` |
| Écran | `lib/screens/studio/studio_main_screen.dart` |
| Widget | `lib/screens/studio/widgets/etape_1_meta_widget.dart` |
| Widget | `lib/screens/studio/widgets/etape_2_formules_widget.dart` |
| Widget | `lib/screens/studio/widgets/etape_3_seuils_widget.dart` |
| Dialogue | `lib/screens/studio/dialogs/arbitrage_version_dialog.dart` |
| Dialogue | `lib/screens/studio/dialogs/confirmation_corbeille_dialog.dart` |

Exemple de route :

```dart
MaterialPageRoute<void>(builder: (_) => const StudioMainScreen())
```

Le DAO est injectable dans `StudioMainScreen(dao: monDao)` afin de faciliter les tests d’intégration et les tests unitaires.
