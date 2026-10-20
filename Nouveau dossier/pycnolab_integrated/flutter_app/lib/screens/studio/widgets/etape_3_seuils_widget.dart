import 'package:flutter/material.dart';

import '../../../models/critere_model.dart';
import '../../../models/formule_model.dart';

class Etape3SeuilsWidget extends StatefulWidget {
  const Etape3SeuilsWidget({super.key, required this.formules, required this.criteres, required this.onChanged});

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
    _createControllers();
  }

  @override
  void didUpdateWidget(covariant Etape3SeuilsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.formules != widget.formules || oldWidget.criteres != widget.criteres) {
      _criteres = _normalise(widget.formules, widget.criteres);
      _createControllers();
    }
  }

  List<CritereModel> _normalise(List<FormuleModel> formules, List<CritereModel> criteres) {
    final byKey = {for (final item in criteres) item.cleVariable: item};
    return formules.where((formula) => formula.cleVariable.trim().isNotEmpty).map((formula) => byKey[formula.cleVariable] ?? CritereModel(cleVariable: formula.cleVariable)).toList();
  }

  void _createControllers() {
    for (final controller in _minControllers.values) controller.dispose();
    for (final controller in _maxControllers.values) controller.dispose();
    _minControllers.clear();
    _maxControllers.clear();
    for (final criterion in _criteres) {
      _minControllers[criterion.cleVariable] = TextEditingController(text: criterion.seuilMin?.toString() ?? '');
      _maxControllers[criterion.cleVariable] = TextEditingController(text: criterion.seuilMax?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final controller in _minControllers.values) controller.dispose();
    for (final controller in _maxControllers.values) controller.dispose();
    super.dispose();
  }

  void _emit() {
    _criteres = _criteres.map((criterion) {
      final minText = _minControllers[criterion.cleVariable]!.text.trim().replaceAll(',', '.');
      final maxText = _maxControllers[criterion.cleVariable]!.text.trim().replaceAll(',', '.');
      return criterion.copyWith(
        seuilMin: double.tryParse(minText),
        seuilMax: double.tryParse(maxText),
        clearSeuilMin: minText.isEmpty,
        clearSeuilMax: maxText.isEmpty,
      );
    }).toList();
    widget.onChanged(List.unmodifiable(_criteres));
  }

  @override
  Widget build(BuildContext context) {
    if (_criteres.isEmpty) {
      return const Center(child: Text('Ajoutez au moins une formule à l’étape précédente pour définir des seuils.'));
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Seuils de conformité', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Les champs sont optionnels. Un seuil vide ne sera pas contrôlé.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        Card(
          clipBehavior: Clip.antiAlias,
          child: DataTable(
            columnSpacing: 28,
            columns: const [DataColumn(label: Text('Variable calculée')), DataColumn(label: Text('Seuil minimum')), DataColumn(label: Text('Seuil maximum'))],
            rows: _criteres.map((criterion) => DataRow(cells: [
              DataCell(Text(criterion.cleVariable, style: const TextStyle(fontFamily: 'monospace'))),
              DataCell(_thresholdField(_minControllers[criterion.cleVariable]!, 'Valeur min')),
              DataCell(_thresholdField(_maxControllers[criterion.cleVariable]!, 'Valeur max')),
            ])).toList(),
          ),
        ),
      ],
    );
  }

  Widget _thresholdField(TextEditingController controller, String hint) {
    return SizedBox(width: 150, child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => _emit(), decoration: InputDecoration(hintText: hint, isDense: true, border: const OutlineInputBorder())));
  }
}
