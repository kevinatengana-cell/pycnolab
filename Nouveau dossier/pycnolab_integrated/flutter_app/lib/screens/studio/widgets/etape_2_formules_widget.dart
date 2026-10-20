import 'package:flutter/material.dart';

import '../../../models/formule_model.dart';

class Etape2FormulesWidget extends StatefulWidget {
  const Etape2FormulesWidget({super.key, required this.formules, required this.onChanged});

  final List<FormuleModel> formules;
  final ValueChanged<List<FormuleModel>> onChanged;

  @override
  State<Etape2FormulesWidget> createState() => _Etape2FormulesWidgetState();
}

class _Etape2FormulesWidgetState extends State<Etape2FormulesWidget> {
  static const variablesEntree = <String>[
    'largeur_mm',
    'epaisseur_mm',
    'force_rupture_N',
    'allongement_mm',
    'longueur_utile_mm',
  ];
  late List<FormuleModel> _formules;
  int _activeExpression = 0;

  @override
  void initState() {
    super.initState();
    _formules = widget.formules.isEmpty ? <FormuleModel>[_emptyFormula(1)] : List.of(widget.formules);
  }

  static FormuleModel _emptyFormula(int order) => FormuleModel(ordreExecution: order, cleVariable: '', libelle: '', unite: '', expression: '');

  List<String> get variablesDisponibles => [...variablesEntree, ..._formules.map((item) => item.cleVariable.trim()).where((item) => item.isNotEmpty)];

  void _emit() => widget.onChanged(List.unmodifiable(_formules.asMap().entries.map((entry) => entry.value.copyWith(ordreExecution: entry.key + 1)).toList()));

  void _update(int index, FormuleModel value) {
    setState(() => _formules[index] = value);
    _emit();
  }

  void _add() {
    setState(() {
      _formules.add(_emptyFormula(_formules.length + 1));
      _activeExpression = _formules.length - 1;
    });
    _emit();
  }

  void _remove(int index) {
    if (_formules.length == 1) {
      _update(index, _emptyFormula(1));
      return;
    }
    setState(() {
      _formules.removeAt(index);
      _activeExpression = _activeExpression.clamp(0, _formules.length - 1);
    });
    _emit();
  }

  void _insertVariable(String variable) {
    final current = _formules[_activeExpression];
    _update(_activeExpression, current.copyWith(expression: '${current.expression}$variable'));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 235, child: _buildVariablePanel(context)),
        const VerticalDivider(width: 1),
        Expanded(child: _buildFormulaList(context)),
      ],
    );
  }

  Widget _buildVariablePanel(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Variables disponibles', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Cliquez sur une variable pour l’insérer dans l’expression active.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ...variablesEntree.map((variable) => _variableTile(variable, Icons.input)),
          if (_formules.any((item) => item.cleVariable.trim().isNotEmpty)) ...[
            const Divider(height: 24),
            Text('Variables calculées', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            ..._formules.map((item) => item.cleVariable.trim()).where((item) => item.isNotEmpty).toSet().map((variable) => _variableTile(variable, Icons.functions)),
          ],
        ],
      ),
    );
  }

  Widget _variableTile(String variable, IconData icon) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 18),
      title: Text(variable, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      onTap: () => _insertVariable(variable),
    );
  }

  Widget _buildFormulaList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          Expanded(child: Text('Atelier de formules', style: Theme.of(context).textTheme.headlineSmall)),
          FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Ajouter une formule')),
        ]),
        const SizedBox(height: 8),
        Text('Les formules sont exécutées dans l’ordre affiché.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        ..._formules.asMap().entries.map((entry) => _formulaCard(context, entry.key, entry.value)),
      ],
    );
  }

  Widget _formulaCard(BuildContext context, int index, FormuleModel formula) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 16, child: Text('${index + 1}')),
            const SizedBox(width: 12),
            Expanded(child: Text('Formule ${index + 1}', style: Theme.of(context).textTheme.titleMedium)),
            IconButton(tooltip: 'Supprimer', onPressed: () => _remove(index), icon: const Icon(Icons.delete_outline)),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 650;
            final fields = [
              _textField('Clé variable *', formula.cleVariable, (value) => _update(index, formula.copyWith(cleVariable: value)), 'section_mm2'),
              _textField('Libellé *', formula.libelle, (value) => _update(index, formula.copyWith(libelle: value)), 'Section transversale'),
              _textField('Unité *', formula.unite, (value) => _update(index, formula.copyWith(unite: value)), 'mm²'),
            ];
            return Flex(direction: wide ? Axis.horizontal : Axis.vertical, crossAxisAlignment: CrossAxisAlignment.start, children: fields.map((field) => Expanded(flex: 1, child: Padding(padding: EdgeInsets.only(right: wide ? 10 : 0, bottom: wide ? 0 : 10), child: field))).toList());
          }),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: formula.expression),
            onTap: () => setState(() => _activeExpression = index),
            onChanged: (value) => _update(index, formula.copyWith(expression: value)),
            decoration: const InputDecoration(labelText: 'Expression mathématique *', hintText: 'largeur_mm * epaisseur_mm', prefixIcon: Icon(Icons.functions), border: OutlineInputBorder()),
          ),
        ]),
      ),
    );
  }

  Widget _textField(String label, String value, ValueChanged<String> onChanged, String hint) {
    return TextField(controller: TextEditingController(text: value), onChanged: onChanged, decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()));
  }
}
