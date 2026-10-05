import 'package:flutter/material.dart';

import 'screens/config_essai_screen.dart';
import 'screens/home_screen.dart';
import 'screens/informations_screen.dart';
import 'screens/protocole_runner_screen.dart';
import 'screens/studio/studio_main_screen.dart';
import 'screens/test_pont_screen.dart';
import 'services/backend_launcher_service.dart';
import 'widgets/license_gate.dart';

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
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),

        // Palette de couleurs inspirée du logo PycnoLab
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1B5E20),
          secondary: Color(0xFF2E7D32),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF1A1A1A),
        ),

        // Style des cartes (Corrigé)
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),

        // Style des barres d'en-tête (AppBar)
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Style des champs de saisie
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 1.5),
          ),
        ),

        // Style des boutons principaux
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/informations': (_) => const InformationsScreen(),
        '/studio': (_) => const StudioMainScreen(),
        '/editeur-protocole': (_) => const StudioMainScreen(),
        '/runner-protocole': (_) => const ProtocoleRunnerScreen(),
        '/traction': (_) => const ConfigEssaiScreen(typeEssai: 'traction'),
        '/compression': (_) =>
            const ConfigEssaiScreen(typeEssai: 'compression'),
        '/flexion': (_) => const ConfigEssaiScreen(typeEssai: 'flexion'),
      },
      home: LicenseGate(
        child: _modeTestPont ? const TestPontScreen() : const _EcranDemarrage(),
      ),
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
  final List<String> _etapes = ['Interface PycnoLab initialisée.'];

  @override
  void initState() {
    super.initState();
    _demarrerBackend();
  }

  Future<void> _demarrerBackend() async {
    final launcher = backendLauncher;
    if (launcher == null) {
      if (mounted) {
        setState(() => _erreur = 'Service backend Python indisponible.');
      }
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo PycnoLab
                      Image.asset(
                        'assets/images/LOGOS.jpg',
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.science_rounded,
                          size: 72,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'PycnoLab',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Chargement du moteur d\'analyse...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5F6368),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Journal d'initialisation
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._etapes.map(
                              (etape) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        etape,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (_erreur == null)
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Initialisation en cours...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF5F6368),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: SelectableText(
                            _erreur!,
                            style: const TextStyle(
                              color: Color(0xFFC62828),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _demarrerBackend,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Réessayer'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
