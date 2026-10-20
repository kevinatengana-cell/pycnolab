import 'package:flutter/material.dart';

import '../../database/protocole_dao.dart';
import '../../models/critere_model.dart';
import '../../models/formule_model.dart';
import '../../models/protocole_model.dart';
import 'dialogs/arbitrage_version_dialog.dart';
import 'widgets/etape_1_meta_widget.dart';
import 'widgets/etape_2_formules_widget.dart';
import 'widgets/etape_3_seuils_widget.dart';
import 'widgets/etape_4_structure_excel_widget.dart';

class StudioMainScreen extends StatefulWidget {
  const StudioMainScreen({super.key, this.dao});

  final ProtocoleDao? dao;

  @override
  State<StudioMainScreen> createState() => _StudioMainScreenState();
}

class _StudioMainScreenState extends State<StudioMainScreen> {
  late final ProtocoleDao _dao;
  int _currentStep = 0;
  String _codeNorme = '';
  String _titre = '';
  String _categorie = '';
  String _description = '';
  List<FormuleModel> _formules = const [];
  List<CritereModel> _criteres = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dao = widget.dao ?? ProtocoleDao();
  }

  void _onMetaChanged(MetaProtocoleData data) {
    _codeNorme = data.codeNorme;
    _titre = data.titre;
    _categorie = data.categorie;
    _description = data.description;
  }

  bool _metaIsValid() {
    if (_codeNorme.isNotEmpty && _titre.isNotEmpty) return true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez renseigner le code norme et le titre.')));
    return false;
  }

  void _next() {
    if (_currentStep == 0 && !_metaIsValid()) return;
    if (_currentStep == 1 && !_validateFormulas()) return;
    setState(() => _currentStep = (_currentStep + 1).clamp(0, 2));
  }

  void _back() {
    if (_currentStep == 0) return;
    setState(() => _currentStep--);
  }

  bool _validateFormulas() {
    final invalid = _formules.any((formula) => formula.cleVariable.trim().isEmpty || formula.libelle.trim().isEmpty || formula.unite.trim().isEmpty || formula.expression.trim().isEmpty);
    if (invalid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chaque formule doit avoir une clé, un libellé, une unité et une expression.')));
      return false;
    }
    final keys = _formules.map((formula) => formula.cleVariable.trim()).toList();
    if (keys.toSet().length != keys.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Les clés variables doivent être uniques.')));
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (_saving || !_metaIsValid() || !_validateFormulas()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final model = ProtocoleModel(
        codeNorme: _codeNorme,
        titre: _titre,
        categorie: _categorie.isEmpty ? 'Autre' : _categorie,
        description: _description.isEmpty ? null : _description,
        dateCreation: now,
        formules: _formules,
        criteres: _criteres,
      );
      final existing = await _dao.findByCodeNorme(model.codeNorme, inclureCorbeille: false);
      if (!mounted) return;
      if (existing == null) {
        await _dao.saveNouveauProtocole(model);
      } else {
        final choice = await ArbitrageVersionDialog.show(context, codeNorme: existing.codeNorme, versionExistante: existing.version);
        if (!mounted || choice == null) return;
        if (choice.creerVersion) {
          await _dao.creerNouvelleVersion(model.copyWith(id: existing.id, version: existing.version));
        } else {
          await _dao.remplacerProtocole(model.copyWith(id: existing.id, version: existing.version, estValide: existing.estValide, estDansCorbeille: existing.estDansCorbeille));
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Protocole enregistré avec succès.')));
      Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec de l’enregistrement : $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      Step(title: const Text('Métadonnées'), isActive: _currentStep >= 0, state: _currentStep > 0 ? StepState.complete : StepState.indexed, content: SizedBox(height: 560, child: Etape1MetaWidget(codeNorme: _codeNorme, titre: _titre, categorie: _categorie, description: _description, onChanged: _onMetaChanged))),
      Step(title: const Text('Formules'), isActive: _currentStep >= 1, state: _currentStep > 1 ? StepState.complete : StepState.indexed, content: SizedBox(height: 560, child: Etape2FormulesWidget(formules: _formules, onChanged: (value) => setState(() => _formules = value)))),
      Step(title: const Text('Seuils'), isActive: _currentStep >= 2, state: StepState.indexed, content: SizedBox(height: 560, child: Etape3SeuilsWidget(formules: _formules, criteres: _criteres, onChanged: (value) => setState(() => _criteres = value)))),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Studio de création de normes'), centerTitle: false),
      body: Stepper(
        currentStep: _currentStep,
        type: StepperType.horizontal,
        onStepTapped: (step) {
          if (step < _currentStep) setState(() => _currentStep = step);
        },
        controlsBuilder: (context, details) {
          final isLast = _currentStep == steps.length - 1;
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Row(children: [
              if (!isLast) FilledButton(onPressed: details.onStepContinue, child: const Text('Continuer')) else FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: const Text('ENREGISTRER LE PROTOCOLE')),
              if (_currentStep > 0) ...[const SizedBox(width: 12), TextButton(onPressed: details.onStepCancel, child: const Text('Retour'))],
            ]),
          );
        },
        onStepContinue: _next,
        onStepCancel: _back,
        steps: steps,
      ),
    );
  }
}
