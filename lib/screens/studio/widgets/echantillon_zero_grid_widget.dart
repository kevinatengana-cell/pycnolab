import 'package:flutter/material.dart';

import '../../../models/variable_excel_model.dart';

const double _largeurCellule = 90;
const double _hauteurCellule = 36;

/// Résultat de la désignation d'un bloc-type par le technicien :
/// dimensions du rectangle choisi + les variables qu'il contient,
/// repérées par offset relatif au coin supérieur gauche du rectangle.
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
              'Glissez d’abord pour sélectionner le rectangle de l’échantillon-type.'),
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
        origine: estFormule ? OrigineVariable.calculee : OrigineVariable.brute,
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