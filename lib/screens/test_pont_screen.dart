import 'package:flutter/material.dart';

import 'home_screen.dart';

/// Écran temporaire utilisé pour vérifier que le backend Python est prêt.
class TestPontScreen extends StatelessWidget {
  const TestPontScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pont Flutter-Python'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Connexion au moteur Python établie.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Le backend Python a démarré correctement et Flutter peut aller à l’interface principale.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
              child: const Text('Aller à l’accueil'),
            ),
          ],
        ),
      ),
    );
  }
}
