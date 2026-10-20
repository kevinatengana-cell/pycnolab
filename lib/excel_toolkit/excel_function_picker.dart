import 'package:flutter/material.dart';

import 'catalogue_fonctions_excel.dart';

/// Fenêtre modale listant toutes les fonctions du catalogue, avec
/// recherche par nom et filtre par catégorie — l'équivalent réduit de
/// la boîte "Insérer une fonction" d'Excel. Module autonome : ne dépend
/// que du catalogue, pas des modèles PycnoLab.
///
/// Retourne la fonction choisie (Navigator.pop(context, fonction)),
/// à charge pour l'appelant d'insérer sa syntaxe dans le champ actif.
class ExcelFunctionPickerDialog extends StatefulWidget {
  const ExcelFunctionPickerDialog({super.key});

  static Future<FonctionExcelInfo?> show(BuildContext context) {
    return showDialog<FonctionExcelInfo>(
      context: context,
      builder: (_) => const ExcelFunctionPickerDialog(),
    );
  }

  @override
  State<ExcelFunctionPickerDialog> createState() => _ExcelFunctionPickerDialogState();
}

class _ExcelFunctionPickerDialogState extends State<ExcelFunctionPickerDialog> {
  String _recherche = '';
  CategorieFonctionExcel? _categorieFiltre;

  @override
  Widget build(BuildContext context) {
    final resultats = catalogueFonctionsExcel.where((fonction) {
      final correspondCategorie = _categorieFiltre == null || fonction.categorie == _categorieFiltre;
      final correspondRecherche = _recherche.isEmpty ||
          fonction.nom.toLowerCase().contains(_recherche.toLowerCase()) ||
          fonction.description.toLowerCase().contains(_recherche.toLowerCase());
      return correspondCategorie && correspondRecherche;
    }).toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Insérer une fonction', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher une fonction...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _recherche = value),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chipCategorie(null, 'Toutes'),
                    for (final categorie in CategorieFonctionExcel.values)
                      _chipCategorie(categorie, categorie.libelle),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: resultats.isEmpty
                    ? const Center(child: Text('Aucune fonction trouvée.'))
                    : ListView.separated(
                        itemCount: resultats.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final fonction = resultats[index];
                          return ListTile(
                            dense: true,
                            title: Text(fonction.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${fonction.syntaxe}\n${fonction.description}'),
                            isThreeLine: true,
                            trailing: fonction.supportTest == SupportTestEstime.incertain
                                ? const Tooltip(
                                    message: 'Support "Tester la formule" non confirmé — la formule reste'
                                        ' valide dans le fichier Excel final quoi qu’il arrive.',
                                    child: Icon(Icons.help_outline, size: 18),
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(fonction),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipCategorie(CategorieFonctionExcel? categorie, String libelle) {
    final selectionnee = _categorieFiltre == categorie;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(libelle, style: const TextStyle(fontSize: 12)),
        selected: selectionnee,
        onSelected: (_) => setState(() => _categorieFiltre = categorie),
      ),
    );
  }
}
