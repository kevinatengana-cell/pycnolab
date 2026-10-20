import 'package:flutter/material.dart';

import '../../../models/critere_model.dart';
import '../../../models/formule_model.dart';

class Etape3SeuilsWidget extends StatefulWidget {
  const Etape3SeuilsWidget({
    super.key,
    required this.formules,
    required this.criteres,
    required this.onChanged,
  });

  final List<FormuleModel> formules;
  final List<CritereModel> criteres;
  final ValueChanged<List<CritereModel>> onChanged;

  @override
  State<Etape3SeuilsWidget> createState() => _Etape3SeuilsWidgetState();
}

class _Etape3SeuilsWidgetState extends State<Etape3SeuilsWidget> {
  final Map<String, TextEditingController> _minControllers = {};
  final Map<String, TextEditingController> _maxControllers = {};
  late List<CritereModel> _criteres;

  @override
  void initState() {
    super.initState();
    _criteres = _normalise(widget.formules, widget.criteres);
    _synchroniserControllers();
  }

  @override
  void didUpdateWidget(covariant Etape3SeuilsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Les champs de seuils se modifient à chaque frappe. Le parent reçoit donc
    // une nouvelle liste de critères à chaque caractère. Il ne faut surtout pas
    // recréer les contrôleurs dans ce cas, sinon le champ perd son focus.
    if (!_memesClesDeFormules(oldWidget.formules, widget.formules)) {
      _criteres = _normalise(widget.formules, widget.criteres);
      _synchroniserControllers();
    }
  }

  bool _memesClesDeFormules(
    List<FormuleModel> anciennes,
    List<FormuleModel> nouvelles,
  ) {
    final anciennesCles = anciennes
        .map((formula) => formula.cleVariable.trim())
        .where((key) => key.isNotEmpty)
        .toList();
    final nouvellesCles = nouvelles
        .map((formula) => formula.cleVariable.trim())
        .where((key) => key.isNotEmpty)
        .toList();

    if (anciennesCles.length != nouvellesCles.length) return false;
    for (var index = 0; index < anciennesCles.length; index++) {
      if (anciennesCles[index] != nouvellesCles[index]) return false;
    }
    return true;
  }

  List<CritereModel> _normalise(
    List<FormuleModel> formules,
    List<CritereModel> criteres,
  ) {
    final byKey = {
      for (final item in criteres) item.cleVariable.trim(): item,
    };

    return formules
        .map((formula) => formula.cleVariable.trim())
        .where((key) => key.isNotEmpty)
        .map(
          (key) => byKey[key] ?? CritereModel(cleVariable: key),
        )
        .toList();
  }

  void _synchroniserControllers() {
    final keys = _criteres.map((criterion) => criterion.cleVariable).toSet();

    final minKeysToRemove = _minControllers.keys
        .where((key) => !keys.contains(key))
        .toList();
    for (final key in minKeysToRemove) {
      _minControllers.remove(key)?.dispose();
    }

    final maxKeysToRemove = _maxControllers.keys
        .where((key) => !keys.contains(key))
        .toList();
    for (final key in maxKeysToRemove) {
      _maxControllers.remove(key)?.dispose();
    }

    for (final criterion in _criteres) {
      _minControllers.putIfAbsent(
        criterion.cleVariable,
        () => TextEditingController(
          text: criterion.seuilMin?.toString() ?? '',
        ),
      );
      _maxControllers.putIfAbsent(
        criterion.cleVariable,
        () => TextEditingController(
          text: criterion.seuilMax?.toString() ?? '',
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _minControllers.values) {
      controller.dispose();
    }
    for (final controller in _maxControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final updated = _criteres.map((criterion) {
      final minText = _minControllers[criterion.cleVariable]!.text.trim().replaceAll(',', '.');
      final maxText = _maxControllers[criterion.cleVariable]!.text.trim().replaceAll(',', '.');

      return criterion.copyWith(
        seuilMin: double.tryParse(minText),
        seuilMax: double.tryParse(maxText),
        clearSeuilMin: minText.isEmpty,
        clearSeuilMax: maxText.isEmpty,
      );
    }).toList();

    // On met à jour la valeur métier sans recréer les TextEditingController.
    _criteres = updated;
    widget.onChanged(List.unmodifiable(updated));
  }

  @override
  Widget build(BuildContext context) {
    if (_criteres.isEmpty) {
      return const Center(
        child: Text(
          'Ajoutez au moins une formule à l’étape précédente pour définir des seuils.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Seuils de conformité',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Les champs sont optionnels. Un seuil vide ne sera pas contrôlé.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 28,
              columns: const [
                DataColumn(label: Text('Variable calculée')),
                DataColumn(label: Text('Seuil minimum')),
                DataColumn(label: Text('Seuil maximum')),
              ],
              rows: _criteres
                  .map(
                    (criterion) => DataRow(
                      cells: [
                        DataCell(
                          Text(
                            criterion.cleVariable,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        DataCell(
                          _thresholdField(
                            _minControllers[criterion.cleVariable]!,
                            'Valeur min',
                          ),
                        ),
                        DataCell(
                          _thresholdField(
                            _maxControllers[criterion.cleVariable]!,
                            'Valeur max',
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thresholdField(
    TextEditingController controller,
    String hint,
  ) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        onChanged: (_) => _emit(),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
