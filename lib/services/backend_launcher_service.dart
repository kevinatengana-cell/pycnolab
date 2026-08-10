import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Service responsable du cycle de vie du backend Python.
///
/// Comportement :
/// - En dev (kDebugMode) : lance directement `python -m uvicorn` depuis
///   le venv du projet (pycno_core/.venv). Plus besoin d'ouvrir un
///   deuxième terminal pour uvicorn : `flutter run` suffit.
/// - En prod (livré au labo, build release) : démarre le backend packagé
///   (main.exe, via PyInstaller) comme sous-processus, invisible pour
///   l'utilisateur.
/// - Dans les deux cas : si /health répond déjà (backend lancé
///   manuellement par ailleurs), ne relance rien.
class BackendLauncherService {
  static const String _healthUrl = "http://127.0.0.1:8123/health";

  Process? _process;

  Future<bool> _estDejaActif() async {
    try {
      final reponse =
          await http.get(Uri.parse(_healthUrl)).timeout(const Duration(seconds: 1));
      return reponse.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// A appeler une seule fois, au démarrage de l'app.
  /// [onStatus] est appelé à chaque étape, pour affichage en temps réel
  /// côté Flutter (écran de démarrage).
  /// Lève une exception explicite si le backend ne démarre pas à temps.
  Future<void> demarrer({void Function(String)? onStatus}) async {
    void statut(String message) => onStatus?.call(message);

    statut("Interface Flutter prête. Connexion au moteur Python...");

    if (await _estDejaActif()) {
      statut("Moteur Python déjà actif (mode dev avec serveur externe).");
      return;
    }

    if (kDebugMode) {
      statut("Lancement du moteur Python (venv local)...");
      await _demarrerEnDev();
    } else {
      statut("Lancement du moteur Python (backend embarqué)...");
      await _demarrerEnProd();
    }

    statut("Moteur Python lancé. En attente de sa réponse...");
    await _attendrePret(onStatus: statut);
    statut("Connexion établie avec le moteur Python.");
  }

  /// Dev : lance `python -m uvicorn` depuis le venv du sous-projet
  /// pycno_core, en supposant la structure de dossier suivante :
  ///   <racine_projet_flutter>/
  ///     pycno_core/
  ///       .venv/Scripts/python.exe   (Windows)
  ///       moteur_python/api/main.py
  Future<void> _demarrerEnDev() async {
    final racineProjet = Directory.current.path; // racine du projet Flutter
    final dossierPycnoCore = path.join(racineProjet, 'pycno_core');
    final pythonExe = path.join(dossierPycnoCore, '.venv', 'Scripts', 'python.exe');

    if (!File(pythonExe).existsSync()) {
      throw Exception(
        "Python (venv) introuvable à :\n$pythonExe\n\n"
        "Vérifiez que pycno_core/.venv existe (créé via 'python -m venv .venv' "
        "puis 'pip install -r requirements.txt' dans ce dossier), et que "
        "'flutter run' est lancé depuis la racine du projet Flutter.",
      );
    }

    await _libererPort8123();

    _process = await Process.start(
      pythonExe,
      ['-m', 'uvicorn', 'moteur_python.api.main:app', '--port', '8123'],
      workingDirectory: dossierPycnoCore,
    );

    _process!.stdout.listen((data) => stdout.add(data));
    _process!.stderr.listen((data) => stderr.add(data));
  }

  Future<void> _libererPort8123() async {
    try {
      if (Platform.isWindows) {
        // Désactivé temporairement : éviter d'exécuter des commandes système
        // au démarrage pour vérifier si c'est cette étape qui provoque un
        // plantage du runner Windows.
        // final result = await Process.run(
        //   'cmd',
        //   ['/C', 'netstat -ano | findstr :8123'],
        //   runInShell: true,
        // );
        // if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        //   final lignes = result.stdout.toString().trim().split(RegExp(r'\r?\n'));
        //   final pids = <String>{};
        //   for (final ligne in lignes) {
        //     final parts = ligne.trim().split(RegExp(r'\s+'));
        //     if (parts.length >= 5) {
        //       pids.add(parts.last);
        //     }
        //   }
        //   for (final pid in pids) {
        //     await Process.run('taskkill', ['/F', '/PID', pid], runInShell: true);
        //   }
        // }
      } else if (Platform.isLinux || Platform.isMacOS) {
        // Désactivé temporairement pour le même motif.
        // final result = await Process.run(
        //   'sh',
        //   ['-c', 'lsof -ti tcp:8123 || true'],
        //   runInShell: true,
        // );
        // final stdout = result.stdout.toString().trim();
        // if (stdout.isNotEmpty) {
        //   final pids = stdout.split(RegExp(r'\r?\n')).where((e) => e.isNotEmpty);
        //   for (final pid in pids) {
        //     await Process.run('kill', ['-9', pid], runInShell: true);
        //   }
        // }
      }
    } catch (_) {
      // Ne pas bloquer le démarrage si la libération échoue.
    }
  }

  /// Prod : lance l'exécutable packagé par PyInstaller, placé dans un
  /// dossier 'backend' à côté de l'exécutable Flutter compilé.
  Future<void> _demarrerEnProd() async {
    final dossierExe =
        path.join(path.dirname(Platform.resolvedExecutable), 'backend');
    final cheminExe = path.join(dossierExe, 'main.exe');

    if (!File(cheminExe).existsSync()) {
      throw Exception(
        "Backend introuvable à l'emplacement attendu :\n$cheminExe\n\n"
        "Vérifiez que le dossier 'backend' (contenant main.exe, généré par "
        "PyInstaller) est bien placé à côté de l'exécutable de l'application.",
      );
    }

    _process = await Process.start(cheminExe, []);
    _process!.stdout.listen((data) {});
    _process!.stderr.listen((data) {});
  }

  Future<void> _attendrePret({
    int tentativesMax = 30,
    void Function(String)? onStatus,
  }) async {
    for (int i = 0; i < tentativesMax; i++) {
      if (await _estDejaActif()) return;
      onStatus?.call("En attente du moteur Python... (${i + 1}/$tentativesMax)");
      await Future.delayed(const Duration(milliseconds: 500));
    }
    throw Exception(
      "Le moteur de calcul n'a pas démarré à temps "
      "(${(tentativesMax * 500 / 1000).toStringAsFixed(0)}s d'attente). "
      "Réessayez, ou contactez le support si le problème persiste.",
    );
  }

  /// A appeler à la fermeture de l'application pour éviter qu'un
  /// processus Python reste actif en tâche de fond après la fermeture
  /// de la fenêtre.
  void arreter() {
    _process?.kill();
    _process = null;
  }
}