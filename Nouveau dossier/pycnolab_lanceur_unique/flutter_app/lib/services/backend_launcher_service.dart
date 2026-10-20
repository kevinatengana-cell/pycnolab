import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class BackendLauncherService {
  static const _healthUrl = 'http://127.0.0.1:8123/health';
  static const _serviceName = 'pycnolab-engine';
  static const _protocolVersion = '1';
  Process? _process;
  Future<void>? _demarrageEnCours;

  Future<bool> _estDejaActif() async {
    try {
      final response = await http
          .get(Uri.parse(_healthUrl))
          .timeout(const Duration(seconds: 1));
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body);
      return body is Map &&
          body['status'] == 'ok' &&
          body['service'] == _serviceName &&
          body['protocol'] == _protocolVersion;
    } catch (_) {
      return false;
    }
  }

  Future<void> demarrer({void Function(String message)? onStatus}) {
    final dejaEnCours = _demarrageEnCours;
    if (dejaEnCours != null) return dejaEnCours;

    final future = _demarrerInterne(onStatus: onStatus);
    _demarrageEnCours = future;
    future.whenComplete(() {
      if (identical(_demarrageEnCours, future)) {
        _demarrageEnCours = null;
      }
    });
    return future;
  }

  Future<void> _demarrerInterne({void Function(String message)? onStatus}) async {
    void status(String message) => onStatus?.call(message);
    status('Interface Flutter prête. Connexion au moteur Python...');
    if (await _estDejaActif()) {
      status('Moteur Python déjà actif.');
      return;
    }
    if (await _portEstOccupe()) {
      throw StateError(
        'Le port 8123 est occupé par un autre processus qui ne répond pas comme PycnoLab.',
      );
    }
    if (kDebugMode) {
      status('Lancement du moteur Python...');
      await _demarrerEnDev(onStatus: status);
    } else {
      status('Lancement du backend embarqué...');
      await _demarrerEnProd();
    }
    await _attendrePret(onStatus: status);
    status('Connexion établie avec le moteur Python.');
  }

  Future<bool> _portEstOccupe() async {
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        8123,
        timeout: const Duration(milliseconds: 300),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _demarrerEnDev({required void Function(String) onStatus}) async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      throw UnsupportedError('Le lancement local par sous-processus est réservé au desktop.');
    }
    final candidat = _trouverBackend();
    if (candidat == null) {
      throw Exception(
        'Python introuvable. Emplacements vérifiés :\n'
        '${_cheminsPossibles().join('\n')}\n\n'
        'Créez .venv dans le dossier du moteur et installez les dépendances.',
      );
    }
    onStatus('Moteur trouvé : ${candidat.racine}');
    _process = await Process.start(
      candidat.python,
      ['-m', 'uvicorn', candidat.module, '--host', '127.0.0.1', '--port', '8123'],
      workingDirectory: candidat.racine,
      runInShell: false,
    );
    _process!.stdout.transform(SystemEncoding().decoder).listen((chunk) {
      if (chunk.trim().isNotEmpty) onStatus(chunk.trim());
    });
    _process!.stderr.transform(SystemEncoding().decoder).listen((chunk) {
      if (chunk.trim().isNotEmpty) onStatus(chunk.trim());
    });
  }

  _BackendCandidate? _trouverBackend() {
    for (final candidat in _candidats()) {
      if (File(candidat.python).existsSync() &&
          File(path.join(candidat.racine, candidat.fichierApi)).existsSync()) {
        return candidat;
      }
    }
    return null;
  }

  List<_BackendCandidate> _candidats() {
    final current = Directory.current.path;
    // Architecture unique retenue pour l'installation Windows actuelle.
    // Ne jamais chercher un second backend `python_engine` : cela pouvait
    // lancer une copie différente du moteur et provoquer des incohérences.
    final roots = <String>[
      path.join(current, 'pycno_core'),
      path.join(current, '..', 'pycno_core'),
      path.join(current, '..', '..', 'pycno_core'),
    ];
    return roots.map(path.normalize).toSet().map((root) {
      final python = Platform.isWindows
          ? path.join(root, '.venv', 'Scripts', 'python.exe')
          : path.join(root, '.venv', 'bin', 'python');
      return _BackendCandidate(
        racine: root,
        python: python,
        fichierApi: path.join('moteur_python', 'api', 'main.py'),
        module: 'moteur_python.api.main:app',
      );
    }).toList();
  }

  List<String> _cheminsPossibles() => _candidats().map((c) => c.python).toSet().toList();

  Future<void> _demarrerEnProd() async {
    final backendDir = path.join(path.dirname(Platform.resolvedExecutable), 'backend');
    final executable = Platform.isWindows ? 'pycnolab_engine.exe' : 'pycnolab_engine';
    final executablePath = path.join(backendDir, executable);
    if (!File(executablePath).existsSync()) {
      throw Exception('Backend embarqué introuvable : $executablePath');
    }
    _process = await Process.start(executablePath, [], runInShell: false);
  }

  Future<void> _attendrePret({required void Function(String) onStatus}) async {
    for (var attempt = 1; attempt <= 30; attempt++) {
      if (await _estDejaActif()) return;
      onStatus('En attente du moteur Python... ($attempt/30)');
      await Future.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException('Le moteur Python n’a pas répondu après 15 secondes.');
  }

  Future<void> arreter() async {
    final process = _process;
    _process = null;
    if (process == null) return;
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }
}

class _BackendCandidate {
  const _BackendCandidate({
    required this.racine,
    required this.python,
    required this.fichierApi,
    required this.module,
  });

  final String racine;
  final String python;
  final String fichierApi;
  final String module;
}
