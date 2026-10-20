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

  /// Nombre maximal de tentatives de démarrage en cas d'échec transitoire.
  static const int _maxStartupRetries = 3;

  /// Délai maximal pour que le backend publie son port (PORT_BOUND:xxxx).
  /// Laisse davantage de marge aux démarrages froids sur les postes lents.
  static const _startupTimeout = Duration(seconds: 90);

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
  String? _dernierExecutableLance;
  List<String> _derniersArguments = <String>[];
  String? _dernierRepertoireTravail;
  int? _dernierCodeSortie;
  bool _portPublie = false;

  /// Tampon circulaire des derniers logs backend, pour diagnostic en cas
  /// d'échec. Limité à 50 lignes.
  final List<String> _derniersLogs = [];
  static const _maxLogs = 50;

  Future<void> demarrer({void Function(String message)? onStatus}) {
    final currentStart = _demarrageEnCours;
    if (currentStart != null) return currentStart;

    late final Future<void> trackedStart;
    trackedStart = _demarrerAvecSecurite(onStatus: onStatus).whenComplete(() {
      if (identical(_demarrageEnCours, trackedStart)) {
        _demarrageEnCours = null;
      }
    });
    _demarrageEnCours = trackedStart;
    return trackedStart;
  }

  /// Ne réessaie que les délais d'attente : une sortie immédiate du processus
  /// est signalée telle quelle, sans boucle de redémarrage inutile.
  Future<void> _demarrerAvecSecurite({
    void Function(String message)? onStatus,
  }) async {
    _onStatus = onStatus;

    for (int attempt = 1; attempt <= _maxStartupRetries; attempt++) {
      try {
        _status('Tentative de lancement du moteur ($attempt/$_maxStartupRetries)...');
        await _demarrerInterne();
        return;
      } catch (error, stackTrace) {
        _status('Échec de la tentative $attempt : $error');
        final journalPath = await _journaliserDiagnostic(
          'Échec de démarrage, tentative $attempt/$_maxStartupRetries',
          error,
        );
        await arreter();

        final retryable = error is TimeoutException;
        if (!retryable || attempt == _maxStartupRetries) {
          if (!retryable) {
            _status('Échec immédiat : aucune nouvelle tentative automatique.');
          }
          final message = journalPath == null
              ? '$error'
              : '$error\nJournal de diagnostic : $journalPath';
          Error.throwWithStackTrace(StateError(message), stackTrace);
        }

        final attente = Duration(seconds: 2 * attempt);
        _status('Échec temporaire : nouvelle tentative dans ${attente.inSeconds} s.');
        await Future.delayed(attente);
      }
    }
  }

  Future<void> _demarrerInterne() async {
    _derniersLogs.clear();
    _portPublie = false;
    _dernierCodeSortie = null;
    _status('Interface Flutter prête. Démarrage du backend...');

    if (_process != null) {
      await arreter();
    }

    _portBound = Completer<int>();
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
  }

  void _status(String message) {
    _derniersLogs.add(message);
    if (_derniersLogs.length > _maxLogs) {
      _derniersLogs.removeAt(0);
    }
    _onStatus?.call(message);
  }

  Directory _repertoireDiagnostic() {
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return Directory(path.join(localAppData, 'PycnoLab', 'logs'));
      }
    }
    final stateHome = Platform.environment['XDG_STATE_HOME'];
    if (stateHome != null && stateHome.isNotEmpty) {
      return Directory(path.join(stateHome, 'pycnolab', 'logs'));
    }
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(path.join(home, '.local', 'state', 'pycnolab'));
    }
    return Directory(path.join(Directory.systemTemp.path, 'pycnolab', 'logs'));
  }

  Future<String?> _journaliserDiagnostic(String contexte, Object erreur) async {
    try {
      final directory = _repertoireDiagnostic();
      await directory.create(recursive: true);
      final journal = File(path.join(directory.path, 'backend_launcher.log'));
      if (await journal.exists() && await journal.length() > 1024 * 1024) {
        final sauvegarde = File('${journal.path}.1');
        if (await sauvegarde.exists()) await sauvegarde.delete();
        await journal.rename(sauvegarde.path);
      }

      final lignes = <String>[
        '',
        '=== ${DateTime.now().toIso8601String()} ===',
        'Contexte : $contexte',
        'Exécutable : ${_dernierExecutableLance ?? '(non défini)'}',
        'Arguments : ${_derniersArguments.join(' ')}',
        'Dossier courant : ${_dernierRepertoireTravail ?? Directory.current.path}',
        'Erreur : $erreur',
        'Derniers messages :',
        ..._derniersLogs,
      ];
      await journal.writeAsString(
        '${lignes.join('\n')}\n',
        mode: FileMode.append,
        flush: true,
      );
      _status('Journal de diagnostic : ${journal.path}');
      return journal.path;
    } on Object catch (e) {
      _status('Écriture du journal de diagnostic impossible : $e');
      return null;
    }
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
      if (_process == null && _dernierCodeSortie != null) {
        throw BackendProcessExitException(
          _dernierCodeSortie!,
          '\nLe processus s’est arrêté pendant le contrôle de santé.',
        );
      }
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
    _dernierExecutableLance = executablePath;
    _derniersArguments = <String>[];
    _dernierRepertoireTravail = Directory.current.path;
    _dernierCodeSortie = null;

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
    final arguments = <String>[scriptPath];
    _dernierExecutableLance = pythonPath;
    _derniersArguments = arguments;
    _dernierRepertoireTravail = backendRoot;
    _dernierCodeSortie = null;
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
      arguments,
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
    
    // Tampon local pour capturer l'intégralité des erreurs stderr du processus Python
    final List<String> errorLines = [];

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
            _portPublie = true;
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
        if (line.trim().isNotEmpty) {
          if (errorLines.length >= _maxLogs) errorLines.removeAt(0);
          errorLines.add(line.trim());
          _status('ERR: ${line.trim()}');
      }
    });

    unawaited(
      process.exitCode.then((code) {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
        final portEtaitPublie = _portPublie;
        _dernierCodeSortie = code;
        if (!portBound.isCompleted) {
          // Remonte les erreurs exactes de stderr si le backend plante au démarrage
          final details = errorLines.isNotEmpty
              ? '\nDétails de l’erreur Python :\n${errorLines.join('\n')}'
              : '\nDerniers logs :\n$derniersLogs';

          portBound.completeError(
            BackendProcessExitException(
              code,
              '\nLe backend s’est arrêté avant de publier son port.$details',
            ),
          );
        }
        if (identical(_process, process)) {
          BackendApiEndpoint.clearPort();
          _process = null;
          final erreur = BackendProcessExitException(
            code,
            '\nLe processus backend s’est terminé après son lancement.',
          );
          _status('Le backend s’est arrêté (${erreur.codeFormate}).');
          if (portEtaitPublie) {
            unawaited(
              _journaliserDiagnostic('Arrêt du moteur après lancement', erreur)
                  .then<void>((_) {}),
            );
          }
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

class BackendProcessExitException implements Exception {
  const BackendProcessExitException(this.code, this.details);

  final int code;
  final String details;

  String get codeFormate {
    final unsigned = code & 0xffffffff;
    final hexadecimal = unsigned.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '$code, 0x$hexadecimal';
  }

  @override
  String toString() =>
      'Le backend s’est arrêté (code $codeFormate).$details';
}
