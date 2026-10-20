import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../services/backend_launcher_service.dart';

/// Écran de transition/vérification du pont Flutter-Python avec la charte PycnoLab.
class TestPontScreen extends StatefulWidget {
  const TestPontScreen({super.key});

  @override
  State<TestPontScreen> createState() => _TestPontScreenState();
}

class _TestPontScreenState extends State<TestPontScreen> {
  final BackendLauncherService _launcherService = BackendLauncherService();

  double _progressValue = 0.0;
  String _statusMessage = 'Initialisation du pont de communication...';
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _lancerProcessusConnexion();
  }

  Future<void> _lancerProcessusConnexion() async {
    try {
      setState(() {
        _hasError = false;
        _progressValue = 0.1;
        _statusMessage = 'Nettoyage des processus et préparation...';
      });
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _progressValue = 0.4;
        _statusMessage = 'Démarrage du moteur Python...';
      });

      // Lancement réel via votre service robuste
      await _launcherService.demarrer(onStatus: (message) {
        if (mounted) {
          setState(() {
            _statusMessage = message;
          });
        }
      });

      setState(() {
        _progressValue = 0.8;
        _statusMessage = 'Vérification de l’état de santé (/health)...';
      });
      await Future.delayed(const Duration(milliseconds: 400));

      setState(() {
        _progressValue = 1.0;
        _statusMessage = 'Moteur Python opérationnel !';
      });
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = error.toString();
          _statusMessage = 'Échec de la connexion au backend.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int pourcentage = (_progressValue * 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        title: const Text(
          'PycnoLab — Connexion Système',
          style: TextStyle(
            color: Color(0xFF1B5E20),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.02),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo officiel PycnoLab
                Image.asset(
                  'assets/images/LOGOS.jpg',
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.science_outlined,
                      size: 48,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Indicateur circulaire avec compteur de pourcentage au centre
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _hasError ? 0.0 : _progressValue,
                        strokeWidth: 6,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _hasError ? Colors.red : const Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        _hasError ? 'ERR' : '$pourcentage%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _hasError ? Colors.red : const Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  _hasError ? 'Erreur de lancement' : 'Moteur Python Opérationnel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _hasError ? Colors.red[700] : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),

                // Affichage du message d'état ou des détails de l'erreur
                Text(
                  _hasError ? _errorMessage : _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _hasError ? Colors.red[400] : const Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Bouton dynamique : Réessayer en cas d'erreur, ou Accès direct à l'accueil
                if (_hasError)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _lancerProcessusConnexion,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text(
                        'Réessayer le lancement',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _progressValue >= 1.0
                          ? () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const HomeScreen()),
                              );
                            }
                          : null, // Désactivé tant que le chargement n'est pas complet
                      icon: const Icon(Icons.dashboard_rounded, size: 20),
                      label: const Text(
                        'Accéder à l’accueil',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}