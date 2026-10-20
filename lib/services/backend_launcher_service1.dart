import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'backend_api_endpoint.dart';

class BackendLauncherService {
  static const _serviceName = 'pycnolab-engine';
  static const _protocolVersion = '3';
  static const _heartbeatInterval = Duration(seconds: 2);
  static const _backendExecutableName = 'backend.exe';

  /// Délai maximal pour que le backend publie son port (PORT_BOUND:xxxx).
  /// Porté à 60 s : un démarrage à froid avec pandas / openpyxl / fastapi
  /// peut dépasser 30 s sur un poste lent.
  static const _startupTimeout = Duration(seconds: 60);

  /// Délai maximal pour que /health réponde après le PORT_BOUND.
  static const _healthTimeout = Duration(seconds: 1);

  /// Nombre d'essais et intervalle pour _attendrePret.
  static const _healthAttempts = 60;
  static const _healthInterval = Duration(milliseconds: 500);

  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Timer? _heartbeatTimer;
  Completer<int>? _portBound;
  Future<void>? _demarrageEnCours;
  void Function(String)? _onStatus;

  /// Tampon circulaire des derniers logs backend, pour diagnostic en cas
  /// d'échec. Limité à 50 lignes.
  final List<String> _derniersLogs = [];
  static const _maxLogs = 50;

  Future<void> demarrer({void Function(String message)? onStatus}) {
    final currentStart = _demarrageEnCours;
    if (currentStart != null) return currentStart;

    late final Future<void> trackedStart;
    trackedStart = _demarrerInterne(onStatus: onStatus).whenComplete(() {
      if (identical(_demarrageEnCours, trackedStart)) {
        _demarrageEnCours = null;
      }
    });
    _demarrageEnCours = trackedStart;
    return trackedStart;
  }

  Future<void> _demarrerInterne({
    void Function(String message)? onStatus,
  }) async {
    _onStatus = onStatus;
    _derniersLogs.clear();
    _status('Interface Flutter prête. Démarrage du backend...');

    if (_process != null) {
      await arreter();
    }

    _portBound = Completer<int>();
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        _status('Lancement de backend.exe...');
        await _demarrerBackend();
      } else {
        throw UnsupportedError(
          'Le lancement local du backend est réservé aux plateformes desktop.',
        );
      }

      final port = await _portBound!.future.timeout(_startupTimeout);
      await _attendrePret(port);
      _status('Connexion établie avec le backend sur le port $port.');
    } catch (error) {
      await arreter();
      rethrow;
    }
  }

  void _status(String message) {
    _derniersLogs.add(message);
    if (_derniersLogs.length > _maxLogs) {
      _derniersLogs.removeAt(0);
    }
    _onStatus?.call(message);
  }

  /// Renvoie les derniers logs pour inclusion dans un message d'erreur.
  String get derniersLogs => _derniersLogs.join('\n');

  // ---------------------------------------------------------------------
  // Health check
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>?> _lireEtatMoteur() async {
    try {
      final response = await http
          .get(Uri.parse('${BackendApiEndpoint.baseUrl}/health'))
          .timeout(_healthTimeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['service'] != _serviceName ||
          body['protocol'] != _protocolVersion) {
        return null;
      }
      return body;
    } catch (_) {
      return null;
    }
  }

  Future<void> _attendrePret(int port) async {
    for (var attempt = 1; attempt <= _healthAttempts; attempt++) {
      final body = await _lireEtatMoteur();
      if (body?['status'] == 'ok') return;
      if (attempt % 4 == 0) {
        _status('En attente du moteur Python... '
            '($attempt/$_healthAttempts)');
      }
      await Future.delayed(_healthInterval);
    }
    throw TimeoutException(
      'Le moteur Python n’a pas répondu après le démarrage sur le port $port.',
    );
  }

  // ---------------------------------------------------------------------
  // Démarrage du backend embarqué
  // ---------------------------------------------------------------------

  Future<void> _demarrerBackend() async {
    if (kDebugMode && Platform.isWindows) {
      await _demarrerBackendDepuisSources();
      return;
    }

    final executableDirectory = path.dirname(Platform.resolvedExecutable);
    final backendDirectory = path.join(executableDirectory, 'backend');
    final executableName =
        Platform.isWindows ? _backendExecutableName : 'backend';
    final executablePath = path.join(backendDirectory, executableName);

    if (!File(executablePath).existsSync()) {
      throw StateError(
        'Backend installé introuvable : $executablePath\n'
        'Reconstruisez le bundle Release avec '
        'scripts\\build_windows_release.ps1.',
      );
    }
    final process = await Process.start(executablePath, [], runInShell: false);
    _attacherAuProcessus(process);
  }

  Future<void> _demarrerBackendDepuisSources() async {
    final projectRoot = _trouverRacineProjet();
    if (projectRoot == null) {
      throw StateError(
        'Sources du backend introuvables. Lancez PycnoLab avec '
        'scripts\\run_windows.ps1 depuis la racine du projet.',
      );
    }

    final backendRoot = path.join(projectRoot, 'pycno_core');
    final pythonPath = path.join(
      backendRoot,
      '.venv',
      'Scripts',
      'python.exe',
    );
    final scriptPath = path.join(backendRoot, 'pycnolab_engine.py');
    if (!File(scriptPath).existsSync()) {
      throw StateError('Point d’entrée du backend introuvable : $scriptPath');
    }
    if (!File(pythonPath).existsSync()) {
      throw StateError(
        'Python du backend introuvable : $pythonPath\n'
        'Initialisez l’environnement depuis la racine du projet :\n'
        'py -m venv pycno_core\\.venv\n'
        'pycno_core\\.venv\\Scripts\\python.exe -m pip install '
        '-r pycno_core\\requirements.txt',
      );
    }

    _status('Lancement du backend Python depuis les sources...');
    final process = await Process.start(
      pythonPath,
      [scriptPath],
      workingDirectory: backendRoot,
      runInShell: false,
    );
    _attacherAuProcessus(process);
  }

  String? _trouverRacineProjet() {
    final starts = [
      Directory.current.path,
      path.dirname(Platform.resolvedExecutable),
    ];
    for (final start in starts) {
      var candidate = path.normalize(start);
      while (true) {
        if (File(
          path.join(candidate, 'pycno_core', 'pycnolab_engine.py'),
        ).existsSync()) {
          return candidate;
        }
        final parent = path.dirname(candidate);
        if (parent == candidate) break;
        candidate = parent;
      }
    }
    return null;
  }

  void _attacherAuProcessus(Process process) {
    _process = process;
    final portBound = _portBound!;
    _stdoutSubscription = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
      (line) {
        final match = RegExp(r'^PORT_BOUND:(\d+)$').firstMatch(line.trim());
        if (match != null) {
          final port = int.tryParse(match.group(1)!);
          if (port == null || port < 1 || port > 65535) {
            if (!portBound.isCompleted) {
              portBound.completeError(
                StateError('Port backend invalide : ${match.group(1)}'),
              );
            }
            return;
          }
          if (!portBound.isCompleted) {
            BackendApiEndpoint.bindPort(port);
            portBound.complete(port);
            _lancerHeartbeat();
          }
          return;
        }
        if (line.trim().isNotEmpty) _status(line.trim());
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!portBound.isCompleted) {
          portBound.completeError(error, stackTrace);
        }
        _status('Erreur stdout du backend : $error');
      },
    );
    _stderrSubscription = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isNotEmpty) _status(line.trim());
    });

    unawaited(
      process.exitCode.then((code) {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
        if (!portBound.isCompleted) {
          portBound.completeError(
            StateError(
              'Le backend s’est arrêté avant de publier son port (code $code).',
            ),
          );
        }
        if (identical(_process, process)) {
          BackendApiEndpoint.clearPort();
          _process = null;
          _status('Le backend s’est arrêté (code $code).');
        }
      }),
    );
  }

  void _lancerHeartbeat() {
    _heartbeatTimer?.cancel();
    unawaited(_envoyerHeartbeat());
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => unawaited(_envoyerHeartbeat()),
    );
  }

  Future<void> _envoyerHeartbeat() async {
    if (_process == null || BackendApiEndpoint.port == null) return;
    try {
      final response = await http
          .post(Uri.parse('${BackendApiEndpoint.baseUrl}/internal/heartbeat'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 204) {
        _status('Heartbeat backend refusé (${response.statusCode}).');
      }
    } on Object catch (error) {
      _status('Heartbeat backend indisponible : $error');
    }
  }

  // ---------------------------------------------------------------------
  // Arrêt
  // ---------------------------------------------------------------------

  Future<void> arreter() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final port = BackendApiEndpoint.port;
    BackendApiEndpoint.clearPort(port);

    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;

    final process = _process;
    _process = null;
    if (process == null) return;

    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
  }
}
