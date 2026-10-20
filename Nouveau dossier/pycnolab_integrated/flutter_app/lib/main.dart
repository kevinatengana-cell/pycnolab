import 'package:flutter/material.dart';

import 'screens/config_essai_screen.dart';
import 'screens/editeur_protocole_screen.dart';
import 'screens/home_screen.dart';
import 'screens/protocole_runner_screen.dart';
import 'screens/test_pont_screen.dart';
import 'screens/studio/studio_main_screen.dart';
import 'services/backend_launcher_service.dart';

const bool _modeTestPont = false;

BackendLauncherService? backendLauncher;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  backendLauncher = BackendLauncherService();
  runApp(const PycnoLabApp());
}

class PycnoLabApp extends StatefulWidget {
  const PycnoLabApp({super.key});

  @override
  State<PycnoLabApp> createState() => _PycnoLabAppState();
}

class _PycnoLabAppState extends State<PycnoLabApp> {
  @override
  void dispose() {
    backendLauncher?.arreter();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PycnoLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3B82F6),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
      ),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/studio': (_) => const StudioMainScreen(),
        '/editeur-protocole': (_) => const StudioMainScreen(),
        '/runner-protocole': (_) => const ProtocoleRunnerScreen(),
        '/traction': (_) => const ConfigEssaiScreen(typeEssai: 'traction'),
        '/compression': (_) => const ConfigEssaiScreen(typeEssai: 'compression'),
      },
      home: _modeTestPont ? const TestPontScreen() : const _EcranDemarrage(),
    );
  }
}

class _EcranDemarrage extends StatefulWidget {
  const _EcranDemarrage();

  @override
  State<_EcranDemarrage> createState() => _EcranDemarrageState();
}

class _EcranDemarrageState extends State<_EcranDemarrage> {
  String? _erreur;
  final List<String> _etapes = ['Interface Flutter chargée.'];

  @override
  void initState() {
    super.initState();
    _demarrerBackend();
  }

  Future<void> _demarrerBackend() async {
    final launcher = backendLauncher;
    if (launcher == null) {
      setState(() => _erreur = 'Service backend Python indisponible.');
      return;
    }

    try {
      await launcher.demarrer(onStatus: (message) {
        if (mounted) setState(() => _etapes.add(message));
      });
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } catch (error) {
      if (mounted) {
        setState(() {
          _erreur = error.toString();
          _etapes.add('Échec de connexion au moteur Python.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._etapes.map((etape) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(etape),
                  )),
              const SizedBox(height: 16),
              if (_erreur == null)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Démarrage du moteur...'),
                  ],
                )
              else
                FilledButton(onPressed: _demarrerBackend, child: const Text('Réessayer')),
            ],
          ),
        ),
      ),
    );
  }
}
