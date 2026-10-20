import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class BackendLauncherService {
  static const String _healthUrl = 'http://127.0.0.1:8123/health';

  Process? _process;

  Future<bool> _estDejaActif() async {
    try {
      final response = await http
          .get(Uri.parse(_healthUrl))
          .timeout(const Duration(seconds: 1));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> demarrer({void Function(String message)? onStatus}) async {
    void status(String message) => onStatus?.call(message);

    status('Interface Flutter prête. Connexion au moteur Python...');

    if (await _estDejaActif()) {
      status('Moteur Python déjà actif.');
      return;
    }

    if (kDebugMode) {
      status('Lancement du moteur Python depuis pycno_core...');
      await _demarrerEnDev();
    } else {
      status('Lancement du backend embarqué...');
      await _demarrerEnProd();
    }

    await _attendrePret(onStatus: status);
    status('Connexion établie avec le moteur Python.');
  }

  Future<void> _demarrerEnDev() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      throw UnsupportedError(
        'Le lancement local du moteur Python est réservé au desktop.',
      );
    }

    final current = Directory.current;
    final candidats = <Directory>[
      Directory(path.join(current.path, 'pycno_core')),
      Directory(path.join(current.path, '..', 'pycno_core')),
      Directory(path.join(current.path, '..', '..', 'pycno_core')),
    ];

    Directory? dossierTrouve;
    String? pythonTrouve;

    for (final candidat in candidats) {
      final python = Platform.isWindows
          ? path.join(candidat.path, '.venv', 'Scripts', 'python.exe')
          : path.join(candidat.path, '.venv', 'bin', 'python');
      final api = path.join(
        candidat.path,
        'moteur_python',
        'api',
        'main.py',
      );

      if (File(python).existsSync() && File(api).existsSync()) {
        dossierTrouve = candidat;
        pythonTrouve = python;
        break;
      }
    }

    final dossierPycnoCore = dossierTrouve;
    final pythonExe = pythonTrouve;

    if (dossierPycnoCore == null || pythonExe == null) {
      throw Exception(
        'Backend Python introuvable. Chemins attendus :\n'
        'pycno_core/.venv/Scripts/python.exe\n'
        'pycno_core/moteur_python/api/main.py',
      );
    }

    _process = await Process.start(
      pythonExe,
      <String>[
        '-m',
        'uvicorn',
        'moteur_python.api.main:app',
        '--host',
        '127.0.0.1',
        '--port',
        '8123',
      ],
      workingDirectory: dossierPycnoCore.path,
      runInShell: false,
    );

    _process!.stdout.listen(stdout.add);
    _process!.stderr.listen(stderr.add);
  }

  Future<void> _demarrerEnProd() async {
    final backendDirectory = path.join(
      path.dirname(Platform.resolvedExecutable),
      'backend',
    );
    final executableName = Platform.isWindows
        ? 'pycnolab_engine.exe'
        : 'pycnolab_engine';
    final executable = path.join(backendDirectory, executableName);

    if (!File(executable).existsSync()) {
      throw Exception('Backend embarqué introuvable : $executable');
    }

    _process = await Process.start(executable, <String>[], runInShell: false);
  }

  Future<void> _attendrePret({required void Function(String) onStatus}) async {
    for (var tentative = 1; tentative <= 30; tentative++) {
      if (await _estDejaActif()) {
        return;
      }
      onStatus('En attente du moteur Python... ($tentative/30)');
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    throw TimeoutException(
      'Le moteur Python n’a pas répondu après 15 secondes.',
    );
  }

  void arreter() {
    _process?.kill();
    _process = null;
  }
}
