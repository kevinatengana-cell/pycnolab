import 'package:flutter/material.dart';

import '../../../models/feuille_excel_model.dart';
import '../../../models/recapitulatif_agregat_model.dart';
import '../../../models/variable_excel_model.dart';

const double _largeurCellule = 90;
const double _hauteurCellule = 36;

// =============================================================================
// WIDGET PRINCIPAL DE L'ÉTAPE 4
// =============================================================================

class Etape4StructureExcelWidget extends StatefulWidget {
  const Etape4StructureExcelWidget({
    super.key,
    required this.feuilles,
    required this.recapitulatif,
    required this.onFeuillesChanged,
    required this.onRecapitulatifChanged,
  });

  final List<FeuilleExcelModel> feuilles;
  final List<RecapitulatifAgregatModel> recapitulatif;
  final ValueChanged<List<FeuilleExcelModel>> onFeuillesChanged;
  final ValueChanged<List<RecapitulatifAgregatModel>> onRecapitulatifChanged;

  @override
  State<Etape4StructureExcelWidget> createState() =>
      _Etape4StructureExcelWidgetState();
}

class _Etape4StructureExcelWidgetState
    extends State<Etape4StructureExcelWidget> {
  late List<FeuilleExcelModel> _feuilles;
  late List<RecapitulatifAgregatModel> _recapitulatif;
  int _indexActif = 0;

  @override
  void initState() {
    super.initState();
    _feuilles = List.of(widget.feuilles);
    _recapitulatif = List.of(widget.recapitulatif);
  }

  void _notifierFeuilles() =>
      widget.onFeuillesChanged(List.unmodifiable(_feuilles));

  void _notifierRecap() =>
      widget.onRecapitulatifChanged(List.unmodifiable(_recapitulatif));

  void _ajouterFeuille() {
    setState(() {
      _feuilles = [
        ..._feuilles,
        FeuilleExcelModel(
          ordre: _feuilles.length + 1,
          nomFeuille: 'Feuille${_feuilles.length + 1}',
          gabarit: GabaritExcel.blocHorizontalRepete,
        ),
      ];
      _indexActif = _feuilles.length - 1;
    });
    _notifierFeuilles();
  }

  void _supprimerFeuille(int index) {
    setState(() {
      _feuilles = [..._feuilles]..removeAt(index);
      if (_indexActif >= _feuilles.length) {
        _indexActif = _feuilles.isEmpty ? 0 : _feuilles.length - 1;
      }
    });
    _notifierFeuilles();
  }

  void _majFeuille(int index, FeuilleExcelModel feuille) {
    setState(() {
      final copie = [..._feuilles];
      copie[index] = feuille;
      _feuilles = copie;
    });
    _notifierFeuilles();
  }

  void _ajouterRecap() {
    if (_feuilles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez d\'abord une feuille.')),
      );
      return;
    }
    setState(() {
      _recapitulatif = [
        ..._recapitulatif,
        RecapitulatifAgregatModel(
          feuilleSource: _feuilles.first.nomFeuille,
          variableSource: '',
          fonction: FonctionAgregat.moyenne,
        ),
      ];
    });
    _notifierRecap();
  }

  void _supprimerRecap(int index) {
    setState(() => _recapitulatif = [..._recapitulatif]..removeAt(index));
    _notifierRecap();
  }

  void _majRecap(int index, RecapitulatifAgregatModel rec) {
    setState(() {
      final copie = [..._recapitulatif];
      copie[index] = rec;
      _recapitulatif = copie;
    });
    _notifierRecap();
  }

  @override
  Widget build(BuildContext context) {
    if (_feuilles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Aucune feuille Excel définie.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _ajouterFeuille,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une feuille'),
            ),
          ],
        ),
      );
    }

    final indexActif = _indexActif.clamp(0, _feuilles.length - 1);
    final feuilleActive = _feuilles[indexActif];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _feuilles.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: InputChip(
                            label: Text(_feuilles[i].nomFeuille.isEmpty
                                ? 'Sans nom'
                                : _feuilles[i].nomFeuille),
                            selected: i == indexActif,
                            onSelected: (_) =>
                                setState(() => _indexActif = i),
                            onDeleted: () => _supprimerFeuille(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Ajouter une feuille',
                onPressed: _ajouterFeuille,
                icon: const Icon(Icons.add_box_outlined),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _construireFeuille(indexActif, feuilleActive),
          ),
        ),
      ],
    );
  }

  Widget _construireFeuille(int index, FeuilleExcelModel feuille) {
    return Column(
      key: ValueKey('feuille_$index'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: feuille.nomFeuille,
                decoration: const InputDecoration(
                  labelText: 'Nom de la feuille',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) =>
                    _majFeuille(index, feuille.copyWith(nomFeuille: v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<GabaritExcel>(
                initialValue: feuille.gabarit,
                decoration: const InputDecoration(
                  labelText: 'Gabarit',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: GabaritExcel.values
                    .map((g) =>
                        DropdownMenuItem(value: g, child: Text(g.name)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  _majFeuille(index, feuille.copyWith(gabarit: v));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (feuille.gabarit != GabaritExcel.colonnesParEchantillon)
          TextFormField(
            initialValue: feuille.nomTableEch0 ?? '',
            decoration: const InputDecoration(
              labelText: 'Nom du Tableau structuré Éch0',
              helperText:
                  'Nom exact du tableau dans le fichier Échantillon Zéro.',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => _majFeuille(
              index,
              v.trim().isEmpty
                  ? feuille.copyWith(clearNomTableEch0: true)
                  : feuille.copyWith(nomTableEch0: v),
            ),
          ),
        const SizedBox(height: 16),
        Text('Variables (${feuille.variables.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (feuille.variables.isEmpty)
          const Text('Aucune variable — définissez un bloc-type ci-dessous.')
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < feuille.variables.length; i++)
                  ListTile(
                    dense: true,
                    leading: Text('${i + 1}'),
                    title: Text(feuille.variables[i].nomTechnique),
                    subtitle: Text(
                      '${feuille.variables[i].portee.name} • '
                      '${feuille.variables[i].origine.name}'
                      '${feuille.variables[i].formule != null ? ' • ${feuille.variables[i].formule}' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        final liste = [...feuille.variables]..removeAt(i);
                        _majFeuille(index,
                            feuille.copyWith(variables: liste));
                      },
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text('Échantillon Zéro',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 320,
          child: EchantillonZeroGridWidget(
            key: ValueKey('ech0_$index'),
            nbLignesInitial: 4,
            nbColonnesInitial: 6,
            onBlocTypeDefini: (bloc) => _majFeuille(
              index,
              feuille.copyWith(variables: bloc.variables),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Récapitulatif',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _ajouterRecap,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une agrégation'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _recapitulatif.length; i++)
          _ligneRecap(i, _recapitulatif[i]),
      ],
    );
  }

  Widget _ligneRecap(int index, RecapitulatifAgregatModel rec) {
    final feuilleValide =
        _feuilles.any((f) => f.nomFeuille == rec.feuilleSource);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: feuilleValide ? rec.feuilleSource : null,
              decoration: const InputDecoration(
                labelText: 'Feuille',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _feuilles
                  .map((f) => DropdownMenuItem(
                        value: f.nomFeuille,
                        child: Text(f.nomFeuille),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                _majRecap(index, rec.copyWith(feuilleSource: v));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: rec.variableSource,
              decoration: const InputDecoration(
                labelText: 'Variable (nom technique)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) =>
                  _majRecap(index, rec.copyWith(variableSource: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<FonctionAgregat>(
              initialValue: rec.fonction,
              decoration: const InputDecoration(
                labelText: 'Fonction',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: FonctionAgregat.values
                  .map((f) =>
                      DropdownMenuItem(value: f, child: Text(f.name)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                _majRecap(index, rec.copyWith(fonction: v));
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _supprimerRecap(index),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// BLOC-TYPE DÉFINI PAR LE TECHNICIEN
// =============================================================================

/// Résultat de la désignation d'un bloc-type par le technicien :
/// dimensions du rectangle choisi + les variables qu'il contient.
class BlocTypeDefini {
  const BlocTypeDefini({
    required this.hauteurBloc,
    required this.largeurBloc,
    required this.variables,
  });

  final int hauteurBloc;
  final int largeurBloc;
  final List<VariableExcelModel> variables;
}

// =============================================================================
// GRILLE ÉCHANTILLON ZÉRO
// =============================================================================

class EchantillonZeroGridWidget extends StatefulWidget {
  const EchantillonZeroGridWidget({
    super.key,
    required this.onBlocTypeDefini,
    this.onCelluleActiveChanged,
    this.nbLignesInitial = 4,
    this.nbColonnesInitial = 6,
  });

  final ValueChanged<BlocTypeDefini> onBlocTypeDefini;
  final void Function(String reference, TextEditingController controller)?
      onCelluleActiveChanged;
  final int nbLignesInitial;
  final int nbColonnesInitial;

  @override
  State<EchantillonZeroGridWidget> createState() =>
      _EchantillonZeroGridWidgetState();
}

class _EchantillonZeroGridWidgetState
    extends State<EchantillonZeroGridWidget> {
  late int _nbLignes;
  late int _nbColonnes;
  final Map<String, TextEditingController> _controllers = {};

  bool _modeSelection = false;
  int? _selDebutLigne;
  int? _selDebutColonne;
  int? _selFinLigne;
  int? _selFinColonne;

  @override
  void initState() {
    super.initState();
    _nbLignes = widget.nbLignesInitial;
    _nbColonnes = widget.nbColonnesInitial;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _cle(int ligne, int colonne) => '${ligne}_$colonne';

  TextEditingController _controllerPour(int ligne, int colonne) =>
      _controllers.putIfAbsent(
          _cle(ligne, colonne), () => TextEditingController());

  String _contenu(int ligne, int colonne) =>
      _controllers[_cle(ligne, colonne)]?.text ?? '';

  String _referenceExcel(int ligne, int colonne) {
    var n = colonne;
    var lettres = '';
    do {
      lettres = String.fromCharCode(65 + (n % 26)) + lettres;
      n = n ~/ 26 - 1;
    } while (n >= 0);
    return '$lettres${ligne + 1}';
  }

  void _ajouterLigne() => setState(() => _nbLignes++);
  void _ajouterColonne() => setState(() => _nbColonnes++);

  void _effacerSelection() {
    setState(() {
      _selDebutLigne = null;
      _selDebutColonne = null;
      _selFinLigne = null;
      _selFinColonne = null;
    });
  }

  int _ligneDepuisY(double y) =>
      (y / _hauteurCellule).floor().clamp(0, _nbLignes - 1);
  int _colonneDepuisX(double x) =>
      (x / _largeurCellule).floor().clamp(0, _nbColonnes - 1);

  void _onPanStart(DragStartDetails details) {
    final ligne = _ligneDepuisY(details.localPosition.dy);
    final colonne = _colonneDepuisX(details.localPosition.dx);
    setState(() {
      _selDebutLigne = ligne;
      _selDebutColonne = colonne;
      _selFinLigne = ligne;
      _selFinColonne = colonne;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_selDebutLigne == null) return;
    setState(() {
      _selFinLigne = _ligneDepuisY(details.localPosition.dy);
      _selFinColonne = _colonneDepuisX(details.localPosition.dx);
    });
  }

  bool _dansSelection(int ligne, int colonne) {
    if (_selDebutLigne == null ||
        _selDebutColonne == null ||
        _selFinLigne == null ||
        _selFinColonne == null) {
      return false;
    }
    final ligneMin =
        _selDebutLigne! < _selFinLigne! ? _selDebutLigne! : _selFinLigne!;
    final ligneMax =
        _selDebutLigne! > _selFinLigne! ? _selDebutLigne! : _selFinLigne!;
    final colMin = _selDebutColonne! < _selFinColonne!
        ? _selDebutColonne!
        : _selFinColonne!;
    final colMax = _selDebutColonne! > _selFinColonne!
        ? _selDebutColonne!
        : _selFinColonne!;
    return ligne >= ligneMin &&
        ligne <= ligneMax &&
        colonne >= colMin &&
        colonne <= colMax;
  }

  void _definirBlocType() {
    if (_selDebutLigne == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Glissez d\'abord pour sélectionner le rectangle de l\'échantillon-type.'),
        ),
      );
      return;
    }
    final ligneMin =
        _selDebutLigne! < _selFinLigne! ? _selDebutLigne! : _selFinLigne!;
    final ligneMax =
        _selDebutLigne! > _selFinLigne! ? _selDebutLigne! : _selFinLigne!;
    final colMin = _selDebutColonne! < _selFinColonne!
        ? _selDebutColonne!
        : _selFinColonne!;
    final colMax = _selDebutColonne! > _selFinColonne!
        ? _selDebutColonne!
        : _selFinColonne!;

    final hauteurBloc = ligneMax - ligneMin + 1;
    final largeurBloc = colMax - colMin + 1;

    if (hauteurBloc < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Le bloc-type doit contenir au moins 2 lignes (nom + formule).'),
        ),
      );
      return;
    }

    final variables = <VariableExcelModel>[];
    for (var colonne = colMin; colonne <= colMax; colonne++) {
      final nom = _contenu(ligneMin, colonne).trim();
      if (nom.isEmpty) continue;
      final formuleTexte = _contenu(ligneMin + 1, colonne).trim();
      final estFormule = formuleTexte.startsWith('=');
      variables.add(VariableExcelModel(
        offsetLigne: 0,
        offsetColonne: colonne - colMin,
        nomTechnique: nom,
        portee: PorteeVariable.point,
        origine:
            estFormule ? OrigineVariable.calculee : OrigineVariable.brute,
        formule: estFormule ? formuleTexte : null,
      ));
    }

    if (variables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Aucun nom technique trouvé sur la 1re ligne du bloc sélectionné.'),
        ),
      );
      return;
    }

    widget.onBlocTypeDefini(BlocTypeDefini(
      hauteurBloc: hauteurBloc,
      largeurBloc: largeurBloc,
      variables: variables,
    ));
    _effacerSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Mode :'),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Édition'),
              selected: !_modeSelection,
              onSelected: (_) => setState(() => _modeSelection = false),
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              label: const Text('Sélection'),
              selected: _modeSelection,
              onSelected: (_) => setState(() => _modeSelection = true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: SizedBox(
                width: _largeurCellule * _nbColonnes,
                height: _hauteurCellule * _nbLignes,
                child: Stack(
                  children: [
                    _construireCellules(),
                    if (_modeSelection)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _ajouterLigne,
              icon: const Icon(Icons.add),
              label: const Text('Ligne'),
            ),
            OutlinedButton.icon(
              onPressed: _ajouterColonne,
              icon: const Icon(Icons.add),
              label: const Text('Colonne'),
            ),
            if (_modeSelection)
              TextButton(
                onPressed: _effacerSelection,
                child: const Text('Effacer la sélection'),
              ),
            FilledButton.icon(
              onPressed: _definirBlocType,
              icon: const Icon(Icons.crop_free),
              label: const Text('Définir comme bloc-type'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _construireCellules() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var ligne = 0; ligne < _nbLignes; ligne++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var colonne = 0; colonne < _nbColonnes; colonne++)
                _celluleWidget(ligne, colonne),
            ],
          ),
      ],
    );
  }

  Widget _celluleWidget(int ligne, int colonne) {
    final selectionnee = _dansSelection(ligne, colonne);
    return Container(
      width: _largeurCellule,
      height: _hauteurCellule,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        color: selectionnee
            ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IgnorePointer(
        ignoring: _modeSelection,
        child: TextField(
          controller: _controllerPour(ligne, colonne),
          style: const TextStyle(fontSize: 12),
          decoration:
              const InputDecoration(border: InputBorder.none, isDense: true),
          onTap: () => widget.onCelluleActiveChanged?.call(
            _referenceExcel(ligne, colonne),
            _controllerPour(ligne, colonne),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }
}