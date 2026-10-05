import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:path/path.dart' as p;

// =============================================================================
// MODÈLES DE DONNÉES & CLASSES EN AUXILIAIRE
// =============================================================================

class VariableEntree {
  String key;
  String label;
  String unite;
  double? valeurDefaut;

  VariableEntree({
    required this.key,
    required this.label,
    required this.unite,
    this.valeurDefaut,
  });
}

class ProtocoleTemplate {
  final String titre;
  final String codeNorme;
  final String categorie;
  final IconData icon;
  final Color couleur;

  ProtocoleTemplate({
    required this.titre,
    required this.codeNorme,
    required this.categorie,
    required this.icon,
    required this.couleur,
  });

  static List<ProtocoleTemplate> templates = [
    ProtocoleTemplate(
      titre: 'Résistance Béton',
      codeNorme: 'NF EN 12390-3',
      categorie: 'Béton',
      icon: Icons.foundation,
      couleur: Colors.blue,
    ),
    ProtocoleTemplate(
      titre: 'Traction Acier',
      codeNorme: 'ISO 6892-1',
      categorie: 'Métal',
      icon: Icons.architecture,
      couleur: Colors.orange,
    ),
    ProtocoleTemplate(
      titre: 'Analyse Sol',
      codeNorme: 'NF P94-051',
      categorie: 'Géotechnique',
      icon: Icons.landscape,
      couleur: Colors.green,
    ),
  ];
}

class SyntaxValidationResult {
  final bool isValid;
  final String? message;

  SyntaxValidationResult({required this.isValid, this.message});
}

class EvaluationResult {
  final bool isSuccess;
  final double? value;
  final String? errorMessage;

  EvaluationResult.success(this.value)
      : isSuccess = true,
        errorMessage = null;

  EvaluationResult.failure(this.errorMessage)
      : isSuccess = false,
        value = null;
}

// =============================================================================
// WIDGET PRINCIPAL
// =============================================================================

class FormulaireProtocoleScreen extends StatefulWidget {
  const FormulaireProtocoleScreen({super.key});

  @override
  State<FormulaireProtocoleScreen> createState() =>
      _FormulaireProtocoleScreenState();
}

class _FormulaireProtocoleScreenState extends State<FormulaireProtocoleScreen> {
  int _currentStep = 0;
  final int _precisionResultat = 2;

  // Contrôleurs Formulaire Étape 1 & 3
  final TextEditingController _codeNormeCtrl = TextEditingController();
  final TextEditingController _categorieCtrl = TextEditingController();
  final TextEditingController _nomProtocoleCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _nomResultatCtrl = TextEditingController();
  final TextEditingController _uniteResultatCtrl = TextEditingController();
  final TextEditingController _formuleExprCtrl = TextEditingController();

  // Étape 2 : Variables
  final List<VariableEntree> _variables = [
    VariableEntree(key: 'force_f', label: 'Force maximale F', unite: 'kN', valeurDefaut: 450.0),
    VariableEntree(key: 'section_a', label: 'Section A', unite: 'mm²', valeurDefaut: 150.0),
  ];

  // Étape 4 : Sandbox & Validation
  final Map<String, double> _sandboxValues = {};
  SyntaxValidationResult _syntaxValidation =
      SyntaxValidationResult(isValid: true, message: 'Expression valide');
  EvaluationResult? _sandboxResult;

  @override
  void initState() {
    super.initState();
    _nomResultatCtrl.text = 'Résistance à la compression';
    _uniteResultatCtrl.text = 'MPa';
    _formuleExprCtrl.text = '(force_f * 1000) / section_a';
    
    _initSandboxValues();
    _validerFormuleEnTempsReel();
  }

  void _initSandboxValues() {
    for (var v in _variables) {
      if (v.valeurDefaut != null) {
        _sandboxValues[v.key] = v.valeurDefaut!;
      }
    }
  }

  String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâ]'), 'a')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  void _appliquerTemplate(ProtocoleTemplate template) {
    setState(() {
      _codeNormeCtrl.text = template.codeNorme;
      _categorieCtrl.text = template.categorie;
      _nomProtocoleCtrl.text = template.titre;
    });
  }

  void _ajouterVariable() {
    setState(() {
      final index = _variables.length + 1;
      final newVar = VariableEntree(
        key: 'var_$index',
        label: 'Nouvelle Variable $index',
        unite: 'unit',
        valeurDefaut: 1.0,
      );
      _variables.add(newVar);
      _sandboxValues[newVar.key] = 1.0;
      _validerFormuleEnTempsReel();
    });
  }

  void _supprimerVariable(int index) {
    setState(() {
      final removed = _variables.removeAt(index);
      _sandboxValues.remove(removed.key);
      _validerFormuleEnTempsReel();
    });
  }

  void _insererJetonFormule(String jeton) {
    final text = _formuleExprCtrl.text;
    final selection = _formuleExprCtrl.selection;
    
    final newText = text.replaceRange(
      selection.start < 0 ? text.length : selection.start,
      selection.end < 0 ? text.length : selection.end,
      jeton,
    );
    
    _formuleExprCtrl.text = newText;
    _formuleExprCtrl.selection = TextSelection.collapsed(
      offset: (selection.start < 0 ? text.length : selection.start) + jeton.length,
    );
    
    _validerFormuleEnTempsReel();
  }

  void _effacerDernierJeton() {
    if (_formuleExprCtrl.text.isNotEmpty) {
      _formuleExprCtrl.text =
          _formuleExprCtrl.text.substring(0, _formuleExprCtrl.text.length - 1);
      _validerFormuleEnTempsReel();
    }
  }

  void _validerFormuleEnTempsReel() {
    final expr = _formuleExprCtrl.text.trim();
    if (expr.isEmpty) {
      setState(() {
        _syntaxValidation = SyntaxValidationResult(isValid: false, message: 'La formule est vide');
        _sandboxResult = EvaluationResult.failure('Formule vide');
      });
      return;
    }

    // 1. Contrôle de parité des parenthèses
    int parentheses = 0;
    for (var char in expr.runes) {
      if (String.fromCharCode(char) == '(') parentheses++;
      if (String.fromCharCode(char) == ')') parentheses--;
      if (parentheses < 0) break;
    }
    if (parentheses != 0) {
      setState(() {
        _syntaxValidation = SyntaxValidationResult(
          isValid: false,
          message: 'Parenthèses mal fermées ou déséquilibrées',
        );
        _sandboxResult = EvaluationResult.failure('Erreur de parenthèses');
      });
      return;
    }

    // 2. Vérification des tokens inconnus (variables non définies)
    final definedKeys = _variables.map((v) => v.key).toSet();
    final knownFunctions = {'sqrt', 'abs', 'min', 'max', 'pi', 'e'};
    // Extrait tous les identificateurs alphabétiques de la formule
    final identifiers = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*').allMatches(expr).map((m) => m.group(0)!).toSet();
    final unknownIds = identifiers.difference(definedKeys).difference(knownFunctions);
    if (unknownIds.isNotEmpty) {
      setState(() {
        _syntaxValidation = SyntaxValidationResult(
          isValid: false,
          message: 'Variable(s) inconnue(s) : ${unknownIds.join(', ')}',
        );
        _sandboxResult = EvaluationResult.failure('Variable(s) inconnue(s) : ${unknownIds.join(', ')}');
      });
      return;
    }

    // 3. Essai de parsing via math_expressions
    try {
      final parser = GrammarParser();
      parser.parse(expr); // lève une exception si syntaxe invalide
    } catch (e) {
      setState(() {
        _syntaxValidation = SyntaxValidationResult(
          isValid: false,
          message: 'Syntaxe invalide : $e',
        );
        _sandboxResult = EvaluationResult.failure('Syntaxe invalide');
      });
      return;
    }

    setState(() {
      _syntaxValidation = SyntaxValidationResult(isValid: true, message: 'Expression valide ✓');
    });

    _calculerSandboxAutomatique();
  }

  void _calculerSandboxAutomatique() {
    if (!_syntaxValidation.isValid) return;

    final exprText = _formuleExprCtrl.text.trim();
    if (exprText.isEmpty) return;

    try {
      // Remplace ^ par ** pour math_expressions
      final exprNormalisee = exprText.replaceAll('^', '**');

      final parser = GrammarParser();
      final Expression parsedExpr = parser.parse(exprNormalisee);

      // Construit le contexte d'évaluation à partir des sandboxValues dynamiques
      final contextModel = ContextModel();
      for (final entry in _sandboxValues.entries) {
        contextModel.bindVariable(
          Variable(entry.key),
          Number(entry.value),
        );
      }
      // Constantes mathématiques
      contextModel.bindVariable(Variable('pi'), Number(3.141592653589793));
      contextModel.bindVariable(Variable('e'), Number(2.718281828459045));

      final double result = parsedExpr.evaluate(EvaluationType.REAL, contextModel) as double;

      if (result.isInfinite) {
        setState(() {
          _sandboxResult = EvaluationResult.failure('Division par zéro');
        });
      } else if (result.isNaN) {
        setState(() {
          _sandboxResult = EvaluationResult.failure('Résultat indéfini (NaN)');
        });
      } else {
        setState(() {
          _sandboxResult = EvaluationResult.success(result);
        });
      }
    } catch (e) {
      setState(() {
        _sandboxResult = EvaluationResult.failure('Erreur de calcul : $e');
      });
    }
  }

  Future<void> _sauvegarderProtocole() async {
    if (_nomProtocoleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner la désignation du protocole avant de sauvegarder.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Construction du JSON de protocole
    final protocole = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'created_at': DateTime.now().toIso8601String(),
      'metadata': {
        'nom': _nomProtocoleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'code_norme': _codeNormeCtrl.text.trim(),
        'categorie': _categorieCtrl.text.trim(),
      },
      'variables': _variables
          .map((v) => {
                'key': v.key,
                'label': v.label,
                'unite': v.unite,
                'valeur_defaut': v.valeurDefaut,
              })
          .toList(),
      'calcul': {
        'nom_resultat': _nomResultatCtrl.text.trim(),
        'unite_resultat': _uniteResultatCtrl.text.trim(),
        'formule': _formuleExprCtrl.text.trim(),
      },
      'validation': {
        'formule_valide': _syntaxValidation.isValid,
        'resultat_sandbox': _sandboxResult?.isSuccess == true
            ? _sandboxResult!.value
            : null,
      },
    };

    try {
      // Dossier de sauvegarde : même répertoire que l'exécutable (ou Documents)
      final exeDir = File(Platform.resolvedExecutable).parent;
      final protocoleDir = Directory(p.join(exeDir.path, 'protocoles'));
      if (!await protocoleDir.exists()) {
        await protocoleDir.create(recursive: true);
      }

      final slug = _nomProtocoleCtrl.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      final fichier = File(
        p.join(protocoleDir.path, '${slug}_${DateTime.now().millisecondsSinceEpoch}.json'),
      );
      await fichier.writeAsString(
        const JsonEncoder.withIndent('  ').convert(protocole),
        encoding: utf8,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Protocole sauvegardé : ${fichier.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de sauvegarde : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _codeNormeCtrl.dispose();
    _categorieCtrl.dispose();
    _nomProtocoleCtrl.dispose();
    _descriptionCtrl.dispose();
    _nomResultatCtrl.dispose();
    _uniteResultatCtrl.dispose();
    _formuleExprCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créateur de Protocole de Test'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Configuration des normes, paramètres et expressions',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
      body: Theme(
        data: theme.copyWith(
          colorScheme: colorScheme.copyWith(
            primary: colorScheme.primary,
          ),
        ),
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepTapped: (step) => setState(() => _currentStep = step),
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() => _currentStep += 1);
            } else {
              _sauvegarderProtocole();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            }
          },
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == 3;
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: details.onStepContinue,
                    icon: Icon(isLastStep ? Icons.check_circle : Icons.arrow_forward),
                    label: Text(isLastStep ? 'Terminer et Valider' : 'Suivant'),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Retour'),
                    ),
                ],
              ),
            );
          },
          steps: [
            // =================================================================
            // ÉTAPE 1 : RÉFÉRENTIEL & NORME
            // =================================================================
            Step(
              title: const Text('Norme'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.editing,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Modèles pré-configurés', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ProtocoleTemplate.templates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final t = ProtocoleTemplate.templates[index];
                        return ActionChip(
                          avatar: Icon(t.icon, color: t.couleur),
                          label: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.titre, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(t.codeNorme, style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                          onPressed: () => _appliquerTemplate(t),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codeNormeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code de la Norme (ex: NF EN 12390-3)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.gavel),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _categorieCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie de Matériau',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nomProtocoleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Désignation du Protocole',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.assignment),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description / Notes d\'application',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                ],
              ),
            ),

            // =================================================================
            // ÉTAPE 2 : VARIABLES D'ENTRÉE
            // =================================================================
            Step(
              title: const Text('Variables'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : (_currentStep == 1 ? StepState.editing : StepState.indexed),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Variables de mesure (${_variables.length})', style: theme.textTheme.titleMedium),
                      IconButton.filledTonal(
                        onPressed: _ajouterVariable,
                        icon: const Icon(Icons.add),
                        tooltip: 'Ajouter une variable',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._variables.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final v = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue: v.label,
                                    decoration: const InputDecoration(labelText: 'Nom de la variable', isDense: true),
                                    onChanged: (val) {
                                      // Correction bug : mettre à jour _sandboxValues avec la nouvelle clé
                                      final ancienneKey = v.key;
                                      final ancienneValeur = _sandboxValues[ancienneKey];
                                      v.label = val;
                                      v.key = _slugify(val);
                                      // Migrer la valeur existante vers la nouvelle clé
                                      _sandboxValues.remove(ancienneKey);
                                      _sandboxValues[v.key] = ancienneValeur ?? v.valeurDefaut ?? 0.0;
                                      _validerFormuleEnTempsReel();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: v.unite,
                                    decoration: const InputDecoration(labelText: 'Unité', isDense: true),
                                    onChanged: (val) => v.unite = val,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _supprimerVariable(idx),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: v.valeurDefaut?.toString() ?? '',
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Valeur par défaut / Test', isDense: true),
                                    onChanged: (val) {
                                      final numVal = double.tryParse(val) ?? 0.0;
                                      v.valeurDefaut = numVal;
                                      _sandboxValues[v.key] = numVal;
                                      _calculerSandboxAutomatique();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Chip(
                                  label: Text('Clé : ${v.key}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                                  backgroundColor: colorScheme.surfaceContainerHigh,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // =================================================================
            // ÉTAPE 3 : FORMULE DE CALCUL
            // =================================================================
            Step(
              title: const Text('Formule'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : (_currentStep == 2 ? StepState.editing : StepState.indexed),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nomResultatCtrl,
                          decoration: const InputDecoration(labelText: 'Nom du Résultat Finale', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _uniteResultatCtrl,
                          decoration: const InputDecoration(labelText: 'Unité', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _formuleExprCtrl,
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Expression de Calcul',
                      hintText: '(v1 * 1000) / v2',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.backspace_outlined),
                        onPressed: _effacerDernierJeton,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _syntaxValidation.isValid ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _syntaxValidation.isValid ? Colors.green : Colors.red),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _syntaxValidation.isValid ? Icons.check_circle : Icons.error,
                          color: _syntaxValidation.isValid ? Colors.green.shade700 : Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _syntaxValidation.message ?? '',
                            style: TextStyle(
                              color: _syntaxValidation.isValid ? Colors.green.shade900 : Colors.red.shade900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Variables disponibles (cliquez pour insérer) :', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: _variables.map((v) {
                      return ActionChip(
                        label: Text(v.key, style: const TextStyle(fontFamily: 'monospace')),
                        onPressed: () => _insererJetonFormule(v.key),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text('Opérateurs & Fonctions :', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: ['+', '-', '*', '/', '^', '(', ')', 'sqrt', 'abs', 'min', 'max', 'pi'].map((op) {
                      return ChoiceChip(
                        selected: false,
                        label: Text(op, style: const TextStyle(fontWeight: FontWeight.bold)),
                        onSelected: (_) => _insererJetonFormule(op),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // =================================================================
            // ÉTAPE 4 : APERÇU LIVE & SANDBOX
            // =================================================================
            Step(
              title: const Text('Test Live'),
              isActive: _currentStep >= 3,
              state: _currentStep == 3 ? StepState.editing : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nomProtocoleCtrl.text.isEmpty ? 'Nouveau Protocole' : _nomProtocoleCtrl.text,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_codeNormeCtrl.text} • ${_categorieCtrl.text}',
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onPrimaryContainer),
                          ),
                          const Divider(),
                          Text(
                            'Formule : ${_formuleExprCtrl.text}',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Résultat du Calcul Sandbox :', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _nomResultatCtrl.text.isEmpty ? 'Résultat' : _nomResultatCtrl.text,
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        if (_sandboxResult != null && _sandboxResult!.isSuccess)
                          Text(
                            '${_sandboxResult!.value!.toStringAsFixed(_precisionResultat)} ${_uniteResultatCtrl.text}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          Text(
                            _sandboxResult?.errorMessage ?? 'Calcul impossible',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}