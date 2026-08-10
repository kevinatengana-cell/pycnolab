import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/test_pont_screen.dart'; // TEMPORAIRE - preuve du pont Flutter-Python
import 'services/backend_launcher_service.dart';

// TEMPORAIRE : passer à false une fois le pont confirmé, pour revenir
// au flux normal (HomeScreen directement).
const bool _modeTestPont = true;

BackendLauncherService? backendLauncher;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    backendLauncher = BackendLauncherService();
  } catch (e, st) {
    print('Erreur d\'initialisation du BackendLauncherService : $e');
    print(st);
  }

  try {
    runApp(const PycnoLabApp());
  } catch (e, st) {
    print('Erreur lors de runApp : $e');
    print(st);
  }
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
        colorSchemeSeed: const Color(0xFF3B82F6), // Blue accent
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate-900
        cardColor: const Color(0xFF1E293B), // Slate-800
      ),
      home: const _EcranDemarrage(),
    );
  }
}

/// Ecran affiché pendant le démarrage du backend Python. Une fois le
/// backend prêt (ou déjà actif en dev), redirige automatiquement vers
/// HomeScreen. Ne possède PAS le service backend (voir backendLauncher
/// global ci-dessus) - il l'utilise seulement, donc sa propre disparition
/// (dispose) n'a plus d'effet sur le processus Python.
class _EcranDemarrage extends StatefulWidget {
  const _EcranDemarrage();

  @override
  State<_EcranDemarrage> createState() => _EcranDemarrageState();
}

class _EcranDemarrageState extends State<_EcranDemarrage> {
  String? _erreur;
  final List<String> _etapes = ["Interface Flutter chargée."];

  @override
  void initState() {
    super.initState();
    _demarrerBackend();
  }

  Future<void> _demarrerBackend() async {
    if (backendLauncher == null) {
      if (mounted) {
        setState(() {
          _erreur = 'Impossible d\'initialiser le service backend Python.';
          _etapes.add('❌ BackendLauncher introuvable.');
        });
      }
      return;
    }

    try {
      await backendLauncher!.demarrer(
        onStatus: (message) {
          if (mounted) setState(() => _etapes.add(message));
        },
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _modeTestPont ? const TestPontScreen() : const HomeScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erreur = e.toString();
          _etapes.add("❌ Échec de connexion au moteur Python.");
        });
      }
    }
  }

  // PLUS de dispose() qui tue le backend ici - voir commentaire sur
  // backendLauncher plus haut. Le processus Python continue de vivre
  // tant que l'app entière n'est pas fermée.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              ..._etapes.map(
                (etape) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        etape.startsWith("❌") ? Icons.error : Icons.check_circle,
                        size: 16,
                        color: etape.startsWith("❌") ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(etape, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_erreur == null)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text("En cours..."),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _erreur!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _erreur = null;
                          _etapes.clear();
                          _etapes.add("Interface Flutter chargée.");
                        });
                        _demarrerBackend();
                      },
                      child: const Text("Réessayer"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}