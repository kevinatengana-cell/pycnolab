import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:path/path.dart' as p;

// =============================================================================
// MODÈLES DE DONNÉES & CLASSES AUXILIAIRES
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

  ProtocoleTemplate({
    required this.titre,
    required this.codeNorme,
    required this.categorie,
    required this.icon,
  });

  static List<ProtocoleTemplate> templates = [
    ProtocoleTemplate(
      titre: 'Résistance Béton',
      codeNorme: 'NF EN 12390-3',
      categorie: 'Béton',
      icon: Icons.foundation_rounded,
    ),
    ProtocoleTemplate(
      titre: 'Traction Acier',
      codeNorme: 'ISO 6892-1',
      categorie: 'Métal',
      icon: Icons.architecture_rounded,
    ),
    ProtocoleTemplate(
      titre: 'Analyse Sol',
      codeNorme: 'NF P94-051',
      categorie: 'Géotechnique',
      icon: Icons.landscape_rounded,
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

  final TextEditingController _codeNormeCtrl = TextEditingController();
  final TextEditingController _categorieCtrl = TextEditingController();
  final TextEditingController _nomProtocoleCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _nomResultatCtrl = TextEditingController();
  final TextEditingController _uniteResultatCtrl = TextEditingController();
  final TextEditingController _formuleExprCtrl = TextEditingController();

  final List<VariableEntree> _variables = [
    VariableEntree(
      key: 'force_f',
      label: 'Force maximale F',
      unite: 'kN',
      valeurDefaut: 450.0,
    ),
    VariableEntree(
      key: 'section_a',
      label: 'Section A',
      unite: 'mm²',
      valeurDefaut: 150.0,
    ),
  ];

  final Map<String, double> _sandboxValues = {};
  SyntaxValidationResult _syntaxValidation =
      SyntaxValidationResult(isValid: true, message: 'Expression valide ✓');
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

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    final newText = text.replaceRange(start, end, jeton);

    _formuleExprCtrl.text = newText;
    _formuleExprCtrl.selection = TextSelection.collapsed(
      offset: start + jeton.length,
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
        _syntaxValidation = SyntaxValidationResult(
          isValid: false,
          message: 'La formule est vide',
        );
        _sandboxResult = EvaluationResult.failure('Formule vide');
      });
      return;
    }

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

    final definedKeys = _variables.map((v) => v.key).toSet();
    final knownFunctions = {'sqrt', 'abs', 'min', 'max', 'pi', 'e'};
    final identifiers = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*')
        .allMatches(expr)
        .map((m) => m.group(0)!)
        .toSet();
    final unknownIds =
        identifiers.difference(definedKeys).difference(knownFunctions);
    if (unknownIds.isNotEmpty) {
      setState(() {
        _syntaxValidation = SyntaxValidationResult(
          isValid: false,
          message: 'Variable(s) inconnue(s) : ${unknownIds.join(', ')}',
        );
        _sandboxResult = EvaluationResult.failure(
          'Variable(s) inconnue(s) : ${unknownIds.join(', ')}',
        );
      });
      return;
    }

    try {
      final parser = Parser();
      parser.parse(expr.replaceAll('^', '**'));
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
      _syntaxValidation = SyntaxValidationResult(
        isValid: true,
        message: 'Expression valide ✓',
      );
    });

    _calculerSandboxAutomatique();
  }

  void _calculerSandboxAutomatique() {
    if (!_syntaxValidation.isValid) return;

    final exprText = _formuleExprCtrl.text.trim();
    if (exprText.isEmpty) return;

    try {
      final exprNormalisee = exprText.replaceAll('^', '**');

      final parser = Parser();
      final Expression parsedExpr = parser.parse(exprNormalisee);

      final contextModel = ContextModel();
      for (final entry in _sandboxValues.entries) {
        contextModel.bindVariable(
          Variable(entry.key),
          Number(entry.value),
        );
      }
      contextModel.bindVariable(Variable('pi'), Number(3.141592653589793));
      contextModel.bindVariable(Variable('e'), Number(2.718281828459045));

      final double result =
          parsedExpr.evaluate(EvaluationType.REAL, contextModel) as double;

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
          content: Text(
            'Veuillez renseigner la désignation du protocole avant de sauvegarder.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
        p.join(
          protocoleDir.path,
          '${slug}_${DateTime.now().millisecondsSinceEpoch}.json',
        ),
      );
      await fichier.writeAsString(
        const JsonEncoder.withIndent('  ').convert(protocole),
        encoding: utf8,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Protocole sauvegardé : ${fichier.path}'),
            backgroundColor: const Color(0xFF1B5E20),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de sauvegarde : $e'),
            backgroundColor: Colors.red.shade700,
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

  InputDecoration _inputDecoration(
    String label, {
    IconData? prefixIcon,
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: const Color(0xFF6B7280), size: 20)
          : null,
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Créateur de Protocole de Test',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                fontSize: 18,
                color: Color(0xFF1B5E20),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Configuration des normes, paramètres d\'essai et expressions mathématiques',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF374151)),
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        elevation: 0,
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
            padding: const EdgeInsets.only(top: 28.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_currentStep > 0) ...[
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Retour'),
                  ),
                  const SizedBox(width: 12),
                ],
                FilledButton.icon(
                  onPressed: details.onStepContinue,
                  icon: Icon(
                    isLastStep
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: Text(
                    isLastStep ? 'Terminer et Enregistrer' : 'Suivant',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Norme'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
            content: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "MODÈLES PRÉ-CONFIGURÉS",
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ProtocoleTemplate.templates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final t = ProtocoleTemplate.templates[index];
                        return ActionChip(
                          elevation: 0,
                          backgroundColor: const Color(0xFFF9FAFB),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          avatar: Icon(
                            t.icon,
                            color: const Color(0xFF1B5E20),
                            size: 18,
                          ),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  t.titre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t.codeNorme,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF1B5E20),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onPressed: () => _appliquerTemplate(t),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeNormeCtrl,
                          decoration: _inputDecoration(
                            'Code de la Norme',
                            prefixIcon: Icons.gavel_rounded,
                            hintText: 'ex: NF EN 12390-3',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _categorieCtrl,
                          decoration: _inputDecoration(
                            'Catégorie de Matériau',
                            prefixIcon: Icons.category_rounded,
                            hintText: 'ex: Béton, Métal',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nomProtocoleCtrl,
                    decoration: _inputDecoration(
                      'Désignation du Protocole',
                      prefixIcon: Icons.assignment_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionCtrl,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      'Description / Notes d\'application',
                      prefixIcon: Icons.description_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Variables'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1
                ? StepState.complete
                : (_currentStep == 1
                    ? StepState.editing
                    : StepState.indexed),
            content: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Variables de mesure (${_variables.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _ajouterVariable,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Ajouter une variable'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE8F5E9),
                          foregroundColor: const Color(0xFF1B5E20),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._variables.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final v = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: v.label,
                                  decoration: _inputDecoration(
                                    'Nom de la variable',
                                  ),
                                  onChanged: (val) {
                                    final ancienneKey = v.key;
                                    final ancienneValeur =
                                        _sandboxValues[ancienneKey];
                                    v.label = val;
                                    v.key = _slugify(val);
                                    _sandboxValues.remove(ancienneKey);
                                    _sandboxValues[v.key] = ancienneValeur ??
                                        v.valeurDefaut ??
                                        0.0;
                                    _validerFormuleEnTempsReel();
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: v.unite,
                                  decoration: _inputDecoration('Unité'),
                                  onChanged: (val) => v.unite = val,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFEF4444),
                                ),
                                onPressed: () => _supprimerVariable(idx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue:
                                      v.valeurDefaut?.toString() ?? '',
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    'Valeur par défaut / Test',
                                  ),
                                  onChanged: (val) {
                                    final numVal = double.tryParse(val) ?? 0.0;
                                    v.valeurDefaut = numVal;
                                    _sandboxValues[v.key] = numVal;
                                    _calculerSandboxAutomatique();
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Clé : ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    Text(
                                      v.key,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1B5E20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Formule'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2
                ? StepState.complete
                : (_currentStep == 2
                    ? StepState.editing
                    : StepState.indexed),
            content: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nomResultatCtrl,
                          decoration: _inputDecoration('Nom du Résultat Final'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 140,
                        child: TextFormField(
                          controller: _uniteResultatCtrl,
                          decoration: _inputDecoration('Unité'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _formuleExprCtrl,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    decoration: _inputDecoration(
                      'Expression de Calcul',
                      hintText: '(force_f * 1000) / section_a',
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.backspace_outlined,
                          size: 20,
                        ),
                        onPressed: _effacerDernierJeton,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _syntaxValidation.isValid
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _syntaxValidation.isValid
                            ? const Color(0xFFA5D6A7)
                            : const Color(0xFFFCA5A5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _syntaxValidation.isValid
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: _syntaxValidation.isValid
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFFDC2626),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _syntaxValidation.message ?? '',
                            style: TextStyle(
                              color: _syntaxValidation.isValid
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFF991B1B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Variables disponibles :',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _variables.map((v) {
                      return ActionChip(
                        elevation: 0,
                        backgroundColor: const Color(0xFFF3F4F6),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        label: Text(
                          v.key,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _insererJetonFormule(v.key),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Opérateurs & Fonctions :',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      '+',
                      '-',
                      '*',
                      '/',
                      '^',
                      '(',
                      ')',
                      'sqrt',
                      'abs',
                      'min',
                      'max',
                      'pi',
                    ].map((op) {
                      return ActionChip(
                        elevation: 0,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        label: Text(
                          op,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF374151),
                          ),
                        ),
                        onPressed: () => _insererJetonFormule(op),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Test Live'),
            isActive: _currentStep >= 3,
            state: _currentStep == 3 ? StepState.editing : StepState.indexed,
            content: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nomProtocoleCtrl.text.isEmpty
                              ? 'Nouveau Protocole'
                              : _nomProtocoleCtrl.text,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_codeNormeCtrl.text.isEmpty ? 'Sans norme' : _codeNormeCtrl.text} • ${_categorieCtrl.text.isEmpty ? 'Général' : _categorieCtrl.text}',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                        const Divider(height: 24, color: Color(0xFFE5E7EB)),
                        Row(
                          children: [
                            const Text(
                              'Formule : ',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _formuleExprCtrl.text,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Résultat du Calcul Sandbox',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _nomResultatCtrl.text.isEmpty
                              ? 'Résultat'
                              : _nomResultatCtrl.text,
                          style: const TextStyle(
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_sandboxResult != null && _sandboxResult!.isSuccess)
                          Text(
                            '${_sandboxResult!.value!.toStringAsFixed(_precisionResultat)} ${_uniteResultatCtrl.text}',
                            style: const TextStyle(
                              color: Color(0xFF1B5E20),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          )
                        else
                          Text(
                            _sandboxResult?.errorMessage ?? 'Calcul impossible',
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}