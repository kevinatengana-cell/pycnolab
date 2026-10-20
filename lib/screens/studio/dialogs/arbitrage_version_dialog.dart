import 'package:flutter/material.dart';

class ArbitrageVersionChoice {
  const ArbitrageVersionChoice({required this.creerVersion});

  final bool creerVersion;
}

class ArbitrageVersionDialog {
  const ArbitrageVersionDialog._();

  static Future<ArbitrageVersionChoice?> show(
    BuildContext context, {
    required String codeNorme,
    required int versionExistante,
  }) {
    return showDialog<ArbitrageVersionChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Norme déjà existante'),
        content: Text('La norme $codeNorme possède déjà la version $versionExistante.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, const ArbitrageVersionChoice(creerVersion: false)),
            child: const Text('Remplacer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, const ArbitrageVersionChoice(creerVersion: true)),
            child: const Text('Créer une version'),
          ),
        ],
      ),
    );
  }
}
