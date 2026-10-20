import 'package:flutter/material.dart';

import '../../../excel_toolkit/catalogue_fonctions_excel.dart';
import '../../../excel_toolkit/excel_function_picker.dart';

/// Les 8 fonctions déjà retenues comme raccourcis rapides (étiquette
/// française, insertion du nom anglais — principe déjà acté ailleurs
/// dans le projet). Le catalogue complet reste accessible via le bouton
/// "Plus de fonctions..." pour ne pas se limiter à ces 8.
const List<String> _fonctionsRapides = [
  'SUM', 'AVERAGE', 'IF', 'VLOOKUP', 'COUNTIF', 'CONCAT', 'TODAY', 'ROUND',
];

/// Barre de formule pour l'Étape 4 : affiche/édite le contenu de la
/// cellule actuellement active dans EchantillonZeroGridWidget (même
/// TextEditingController, donc la saisie est synchronisée dans les deux
/// sens). N'affiche rien tant qu'aucune cellule n'est active.
class BarreFormuleWidget extends StatelessWidget {
  const BarreFormuleWidget({
    super.key,
    required this.referenceActive,
    required this.controllerActif,
  });

  /// Référence Excel de la cellule active, ex. "B2" — null si aucune
  /// cellule n'a encore été touchée.
  final String? referenceActive;
  final TextEditingController? controllerActif;

  void _inserer(String texteAInserer) {
    final controller = controllerActif;
    if (controller == null) return;
    final selection = controller.selection;
    final texte = controller.text;
    final position = selection.start >= 0 ? selection.start : texte.length;
    final prefixe = texte.startsWith('=') ? '' : '=';
    final nouveauTexte = prefixe.isEmpty
        ? texte.replaceRange(position, position, texteAInserer)
        : '=$texteAInserer';
    controller.value = TextEditingValue(
      text: nouveauTexte,
      selection: TextSelection.collapsed(offset: nouveauTexte.length),
    );
  }

  Future<void> _ouvrirCatalogueComplet(BuildContext context) async {
    final fonction = await ExcelFunctionPickerDialog.show(context);
    if (fonction != null) _inserer('${fonction.nom}()');
  }

  @override
  Widget build(BuildContext context) {
    final actif = controllerActif != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    referenceActive ?? '—',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const VerticalDivider(),
                Expanded(
                  child: TextField(
                    controller: controllerActif,
                    enabled: actif,
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      hintText: actif
                          ? 'Saisissez une valeur ou une formule débutant par \'=\''
                          : 'Sélectionnez une cellule dans la grille',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final nomFonction in _fonctionsRapides)
                  OutlinedButton(
                    onPressed: actif ? () => _inserer('$nomFonction()') : null,
                    child: Text(nomFonction, style: const TextStyle(fontSize: 12)),
                  ),
                OutlinedButton.icon(
                  onPressed: actif ? () => _ouvrirCatalogueComplet(context) : null,
                  icon: const Icon(Icons.functions, size: 16),
                  label: const Text('Plus de fonctions...'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
