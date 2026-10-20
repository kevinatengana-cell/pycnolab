import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/capture_dao.dart';
import '../services/history_service.dart';
import '../services/python_engine_service.dart';
import 'resultats_screen.dart';

/// Écran intercalé entre la sélection du fichier brut et le calcul final :
/// demande les variables géométriques propres à l'essai (L0 et Forme pour la
/// traction, L0+Section pour la compression, portée/base/hauteur pour la
/// flexion), puis lance le calcul et l'export du fichier Excel complet.
class DimensionsEssaiScreen extends StatefulWidget {
  const DimensionsEssaiScreen({
    super.key,
    required this.typeEssai,
    required this.cheminFichier,
    required this.nomFichier,
    this.captureId,
  });

  final String typeEssai;
  final String cheminFichier;
  final String nomFichier;
  final int? captureId;

  @override
  State<DimensionsEssaiScreen> createState() => _DimensionsEssaiScreenState();
}

enum _ModeSaisieCompression { global, parEchantillon }
enum _ModeSaisieFlexion { global, parEchantillon }

class _DimensionsEssaiScreenState extends State<DimensionsEssaiScreen> {
  final PythonEngineService _pythonService = PythonEngineService();
  final CaptureDao _captureDao = CaptureDao();

  // Traction & Forme
  final TextEditingController _l0TractionCtrl =
      TextEditingController(text: '20.0');
  String _formeSelectionnee = 'cylindre';

  final List<Map<String, String>> _formesDisponibles = [
    {'valeur': 'cylindre', 'libelle': 'Cylindre'},
    {'valeur': 'rectangle', 'libelle': 'Rectangle'},
    {'valeur': 'carre', 'libelle': 'Carré'},
    {'valeur': 'tube_circulaire', 'libelle': 'Tube Circ.'},
    {'valeur': 'tube_rectangulaire', 'libelle': 'Tube Rect.'},
    {'valeur': 'surface', 'libelle': 'Surface'},
  ];

  // Compression — mode global
  _ModeSaisieCompression _modeCompression = _ModeSaisieCompression.global;
  final TextEditingController _l0CompressionGlobalCtrl =
      TextEditingController();
  final TextEditingController _sectionCompressionGlobalCtrl =
      TextEditingController();

  // Compression — mode par échantillon
  bool _echantillonsCharges = false;
  bool _chargementEchantillons = false;
  String? _erreurChargementEchantillons;
  final Map<String, Map<String, TextEditingController>> _l0ParEchCtrl = {};
  final Map<String, Map<String, TextEditingController>> _sectionParEchCtrl = {};
  List<Map<String, dynamic>> _gammesDetectees = [];

  // Flexion
  final TextEditingController _porteeCtrl =
      TextEditingController(text: '100.0');
  final TextEditingController _baseCtrl = TextEditingController(text: '40.0');
  final TextEditingController _hauteurCtrl =
      TextEditingController(text: '40.0');
  _ModeSaisieFlexion _modeFlexion = _ModeSaisieFlexion.global;
  final Map<String, Map<String, TextEditingController>> _porteeParEchCtrl = {};
  final Map<String, Map<String, TextEditingController>> _baseParEchCtrl = {};
  final Map<String, Map<String, TextEditingController>> _hauteurParEchCtrl = {};

  bool _isBusy = false;
  String? _resumeResultat;
  String? _erreur;

  @override
  void dispose() {
    _l0TractionCtrl.dispose();
    _l0CompressionGlobalCtrl.dispose();
    _sectionCompressionGlobalCtrl.dispose();
    for (final parGamme in [
      ..._l0ParEchCtrl.values,
      ..._sectionParEchCtrl.values,
      ..._porteeParEchCtrl.values,
      ..._baseParEchCtrl.values,
      ..._hauteurParEchCtrl.values,
    ]) {
      for (final c in parGamme.values) {
        c.dispose();
      }
    }
    _porteeCtrl.dispose();
    _baseCtrl.dispose();
    _hauteurCtrl.dispose();
    super.dispose();
  }

  String get _titre {
    switch (widget.typeEssai) {
      case 'compression':
        return 'Dimensions — Essai de Compression';
      case 'flexion':
        return 'Dimensions — Essai de Flexion';
      default:
        return 'Dimensions — Essai de Traction';
    }
  }

  double? _lireDouble(TextEditingController ctrl) {
    final texte = ctrl.text.trim().replaceAll(',', '.');
    if (texte.isEmpty) return null;
    return double.tryParse(texte);
  }

  Map<String, dynamic> _mapOuVide(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};

  String _texteDimension(Object? value) =>
      value is num ? value.toString() : '';

  Future<void> _basculerModeCompression(_ModeSaisieCompression mode) async {
    setState(() => _modeCompression = mode);
    if (mode == _ModeSaisieCompression.parEchantillon &&
        !_echantillonsCharges) {
      await _chargerEchantillons();
    }
  }

  Future<void> _basculerModeFlexion(_ModeSaisieFlexion mode) async {
    setState(() => _modeFlexion = mode);
    if (mode == _ModeSaisieFlexion.parEchantillon &&
        !_echantillonsCharges) {
      await _chargerEchantillons();
    }
  }

  Future<void> _chargerEchantillons() async {
    setState(() {
      _chargementEchantillons = true;
      _erreurChargementEchantillons = null;
    });
    try {
      final captureId = widget.captureId;
      final capture =
          captureId == null ? null : await _captureDao.lireCapture(captureId);
      final gammes = capture == null
          ? List<Map<String, dynamic>>.from(
              ((await _pythonService.listerEchantillons(
                typeEssai: widget.typeEssai,
                cheminFichier: widget.cheminFichier,
              ))['gammes'] as List)
                  .map((g) => Map<String, dynamic>.from(g as Map)),
            )
          : (capture.donneesMoteur['gammes'] as List).map((gamme) {
              final map = Map<String, dynamic>.from(gamme as Map);
              return <String, dynamic>{
                'nom_gamme': map['nom_gamme'],
                'echantillons': (map['echantillons'] as List)
                    .map((sample) => (sample
                        as Map<String, dynamic>)['identifiant'] as String)
                    .toList(),
              };
            }).toList();
      final geometrieCapture = capture?.geometrie ?? <String, Object?>{};
      final dimensionsFlexion = _mapOuVide(
        geometrieCapture['dimensions_par_echantillon'],
      );
      if (widget.typeEssai == 'flexion' && dimensionsFlexion.isNotEmpty) {
        _modeFlexion = _ModeSaisieFlexion.parEchantillon;
      }
      for (final gamme in gammes) {
        final nomGamme = gamme['nom_gamme'] as String;
        final echantillons = List<String>.from(gamme['echantillons'] as List);
        _l0ParEchCtrl[nomGamme] = {
          for (final ech in echantillons) ech: TextEditingController()
        };
        _sectionParEchCtrl[nomGamme] = {
          for (final ech in echantillons) ech: TextEditingController()
        };
        if (widget.typeEssai != 'flexion') continue;
        final dimensionsGamme = _mapOuVide(dimensionsFlexion[nomGamme]);
        _porteeParEchCtrl[nomGamme] = {};
        _baseParEchCtrl[nomGamme] = {};
        _hauteurParEchCtrl[nomGamme] = {};
        for (final ech in echantillons) {
          final dimensionsEch = _mapOuVide(dimensionsGamme[ech]);
          _porteeParEchCtrl[nomGamme]![ech] = TextEditingController(
            text: _texteDimension(dimensionsEch['portee_mm']),
          );
          _baseParEchCtrl[nomGamme]![ech] = TextEditingController(
            text: _texteDimension(dimensionsEch['base_mm']),
          );
          _hauteurParEchCtrl[nomGamme]![ech] = TextEditingController(
            text: _texteDimension(dimensionsEch['hauteur_mm']),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _gammesDetectees = gammes;
        _echantillonsCharges = true;
        _chargementEchantillons = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementEchantillons = false;
        _erreurChargementEchantillons = 'Impossible de lire le fichier : $e';
      });
    }
  }

  Map<String, dynamic>? _construireGeometrieCompression() {
    if (widget.typeEssai != 'compression') return null;

    final geometrie = <String, dynamic>{};
    final l0Global = _lireDouble(_l0CompressionGlobalCtrl);
    final sectionGlobal = _lireDouble(_sectionCompressionGlobalCtrl);
    if (l0Global != null) geometrie['l0_mm'] = l0Global;
    if (sectionGlobal != null) geometrie['section_mm2'] = sectionGlobal;

    if (_modeCompression == _ModeSaisieCompression.parEchantillon) {
      final dimensionsParEchantillon =
          <String, Map<String, Map<String, double>>>{};
      for (final gamme in _gammesDetectees) {
        final nomGamme = gamme['nom_gamme'] as String;
        final echantillons = List<String>.from(gamme['echantillons'] as List);
        final dimsGamme = <String, Map<String, double>>{};
        for (final ech in echantillons) {
          final l0 = _lireDouble(_l0ParEchCtrl[nomGamme]![ech]!);
          final section = _lireDouble(_sectionParEchCtrl[nomGamme]![ech]!);
          final dims = <String, double>{};
          if (l0 != null) dims['l0_mm'] = l0;
          if (section != null) dims['section_mm2'] = section;
          if (dims.isNotEmpty) dimsGamme[ech] = dims;
        }
        if (dimsGamme.isNotEmpty)
          dimensionsParEchantillon[nomGamme] = dimsGamme;
      }
      if (dimensionsParEchantillon.isNotEmpty) {
        geometrie['dimensions_par_echantillon'] = dimensionsParEchantillon;
      }
    }
    return geometrie;
  }

  Map<String, dynamic>? _construireGeometrieFlexion() {
    if (widget.typeEssai != 'flexion') return null;
    if (_modeFlexion == _ModeSaisieFlexion.global) {
      return {
        'portee_mm': _lireDouble(_porteeCtrl) ?? 0,
        'base_mm': _lireDouble(_baseCtrl) ?? 0,
        'hauteur_mm': _lireDouble(_hauteurCtrl) ?? 0,
        'dimensions_par_echantillon': <String, dynamic>{},
      };
    }

    final dimensionsParEchantillon =
        <String, Map<String, Map<String, double>>>{};
    for (final gamme in _gammesDetectees) {
      final nomGamme = gamme['nom_gamme'] as String;
      final echantillons = List<String>.from(gamme['echantillons'] as List);
      dimensionsParEchantillon[nomGamme] = {
        for (final ech in echantillons)
          ech: {
            'portee_mm': _lireDouble(_porteeParEchCtrl[nomGamme]![ech]!) ?? 0,
            'base_mm': _lireDouble(_baseParEchCtrl[nomGamme]![ech]!) ?? 0,
            'hauteur_mm':
                _lireDouble(_hauteurParEchCtrl[nomGamme]![ech]!) ?? 0,
          },
      };
    }
    return {'dimensions_par_echantillon': dimensionsParEchantillon};
  }

  double? get _l0Traction => widget.typeEssai == 'traction'
      ? (_lireDouble(_l0TractionCtrl) ?? 20.0)
      : null;

  Map<String, Object?> _geometrieCapture() {
    switch (widget.typeEssai) {
      case 'compression':
        return _construireGeometrieCompression() ?? <String, Object?>{};
      case 'flexion':
        return _construireGeometrieFlexion() ?? <String, Object?>{};
      default:
        return {'l0_mm': _l0Traction ?? 20.0, 'forme': _formeSelectionnee};
    }
  }

  Future<void> _sauvegarderGeometrie() async {
    final captureId = widget.captureId;
    if (captureId != null) {
      await _captureDao.enregistrerGeometrie(captureId, _geometrieCapture());
    }
  }

  String? _validerSaisie() {
    if (widget.typeEssai == 'flexion') {
      if (_modeFlexion == _ModeSaisieFlexion.global) {
        final portee = _lireDouble(_porteeCtrl);
        final base = _lireDouble(_baseCtrl);
        final hauteur = _lireDouble(_hauteurCtrl);
        if (portee == null || portee <= 0 ||
            base == null || base <= 0 ||
            hauteur == null || hauteur <= 0) {
          return 'Portée, base et hauteur doivent être renseignées et positives.';
        }
      } else {
        if (!_echantillonsCharges || _gammesDetectees.isEmpty) {
          return 'Chargez les échantillons avant de saisir leurs dimensions.';
        }
        for (final gamme in _gammesDetectees) {
          final nomGamme = gamme['nom_gamme'] as String;
          final echantillons = List<String>.from(gamme['echantillons'] as List);
          for (final ech in echantillons) {
            final portee = _lireDouble(_porteeParEchCtrl[nomGamme]![ech]!);
            final base = _lireDouble(_baseParEchCtrl[nomGamme]![ech]!);
            final hauteur = _lireDouble(_hauteurParEchCtrl[nomGamme]![ech]!);
            if (portee == null || portee <= 0 ||
                base == null || base <= 0 ||
                hauteur == null || hauteur <= 0) {
              return 'Renseignez une portée, une base et une hauteur positives '
                  'pour $ech (gamme $nomGamme).';
            }
          }
        }
      }
    }
    if (widget.typeEssai == 'traction' &&
        (_l0Traction == null || _l0Traction! <= 0)) {
      return 'L0 doit être une valeur positive.';
    }
    return null;
  }

  Future<void> _calculerApercu() async {
    final erreurValidation = _validerSaisie();
    if (erreurValidation != null) {
      setState(() => _erreur = erreurValidation);
      return;
    }
    setState(() {
      _isBusy = true;
      _erreur = null;
      _resumeResultat = null;
    });
    try {
      await _sauvegarderGeometrie();
      final captureId = widget.captureId;
      final capture =
          captureId == null ? null : await _captureDao.lireCapture(captureId);
      final resultat = capture == null
          ? await _pythonService.calculerEssaiDepuisExcel(
              typeEssai: widget.typeEssai,
              cheminFichier: widget.cheminFichier,
              l0Mm: _l0Traction,
              forme: _formeSelectionnee,
              geometrieCompression: _construireGeometrieCompression(),
              geometrieFlexion: _construireGeometrieFlexion(),
            )
          : await _pythonService.calculerDonneesCapture(
              typeEssai: widget.typeEssai,
              donnees: capture.donneesMoteur,
              l0Mm: _l0Traction ?? 20.0,
            );
      if (captureId != null) {
        await _captureDao.enregistrerResultat(
          captureId: captureId,
          geometrie: _geometrieCapture(),
          resultat: Map<String, Object?>.from(resultat),
        );
        HistoryService.instance.signalHistoryChanged();
      } else {
        for (final lot in resultatsVersHistorique(resultat, widget.typeEssai)) {
          HistoryService.instance.add(lot);
        }
      }
      if (!mounted) return;
      setState(() => _isBusy = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultatsScreen(
            donnees: resultat,
            typeEssai: widget.typeEssai,
            onExporter: _exporterExcel,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _erreur = 'Calcul impossible : $e';
      });
    }
  }

  Future<void> _exporterExcel() async {
    final erreurValidation = _validerSaisie();
    if (erreurValidation != null) {
      setState(() => _erreur = erreurValidation);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erreurValidation),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
        ),
      );
      return;
    }

    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer le rapport Excel Pycnolab',
      fileName: 'RAPPORT_${widget.typeEssai.toUpperCase()}.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (outputFile == null || !mounted) return;

    setState(() {
      _isBusy = true;
      _erreur = null;
    });
    try {
      await _sauvegarderGeometrie();
      final chemin = await _pythonService.exporterEssaiExcel(
        typeEssai: widget.typeEssai,
        cheminFichier: widget.cheminFichier,
        cheminDestination: outputFile,
        l0Mm: _l0Traction,
        forme: _formeSelectionnee,
        geometrieCompression: _construireGeometrieCompression(),
        geometrieFlexion: _construireGeometrieFlexion(),
      );
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rapport généré avec succès : $chemin'),
          backgroundColor: const Color(0xFF1B5E20),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _erreur = 'Export impossible : $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export impossible : $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          _titre,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontSize: 18,
            color: Color(0xFF1B5E20),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF374151)),
        shape: const Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.straighten_rounded,
                          color: Color(0xFF1B5E20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.nomFichier,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ..._buildChampsParEssai(),
                  const SizedBox(height: 24),
                  if (_erreur != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        _erreur!,
                        style: const TextStyle(
                            color: Color(0xFF991B1B), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_resumeResultat != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Text(
                        _resumeResultat!,
                        style: const TextStyle(
                            color: Color(0xFF1B5E20), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isBusy ? null : _calculerApercu,
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('Aperçu des résultats'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isBusy ? null : _exporterExcel,
                          icon: _isBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.table_view_rounded, size: 18),
                          label: const Text('Exporter (.xlsx)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChampsParEssai() {
    switch (widget.typeEssai) {
      case 'compression':
        return _buildChampsCompression();
      case 'flexion':
        return _buildChampsFlexion();
      default:
        return _buildChampsTraction();
    }
  }

  List<Widget> _buildChampsTraction() {
    return [
      const Text(
        'Forme géométrique de l\'éprouvette',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
      ),
      const SizedBox(height: 6),
      const Text(
        'Sélectionnez la forme pour lire correctement la feuille de dimensions.',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _formesDisponibles.map((f) {
          final estSelectionne = _formeSelectionnee == f['valeur'];
          return ChoiceChip(
            label: Text(f['libelle']!),
            selected: estSelectionne,
            selectedColor: const Color(0xFF1B5E20),
            labelStyle: TextStyle(
              color: estSelectionne ? Colors.white : const Color(0xFF374151),
              fontWeight: estSelectionne ? FontWeight.bold : FontWeight.normal,
            ),
            backgroundColor: const Color(0xFFF3F4F6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: estSelectionne ? const Color(0xFF1B5E20) : const Color(0xFFE5E7EB),
              ),
            ),
            onSelected: (selected) {
              if (selected) {
                setState(() => _formeSelectionnee = f['valeur']!);
              }
            },
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
      const Text(
        'Longueur initiale (L0)',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
      ),
      const SizedBox(height: 4),
      const Text(
        'Valeur globale appliquée à tous les échantillons du fichier.',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _l0TractionCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration:
            const InputDecoration(labelText: 'L0 (mm)', suffixText: 'mm'),
      ),
    ];
  }

  List<Widget> _buildChampsFlexion() {
    return [
      const Text(
        'Géométrie de l\'éprouvette (flexion 3 points)',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
      ),
      const SizedBox(height: 4),
      const Text(
        'Choisissez une géométrie commune ou renseignez les mesures de chaque échantillon.',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
      ),
      const SizedBox(height: 16),
      SegmentedButton<_ModeSaisieFlexion>(
        segments: const [
          ButtonSegment(
            value: _ModeSaisieFlexion.global,
            label: Text('Global'),
            icon: Icon(Icons.public_rounded, size: 16),
          ),
          ButtonSegment(
            value: _ModeSaisieFlexion.parEchantillon,
            label: Text('Par échantillon'),
            icon: Icon(Icons.view_list_rounded, size: 16),
          ),
        ],
        selected: {_modeFlexion},
        onSelectionChanged: (selection) =>
            _basculerModeFlexion(selection.first),
      ),
      const SizedBox(height: 16),
      if (_modeFlexion == _ModeSaisieFlexion.global) ...[
        TextField(
          controller: _porteeCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Portée L (mm)', suffixText: 'mm'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _baseCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(labelText: 'Base b (mm)', suffixText: 'mm'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _hauteurCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Hauteur h (mm)', suffixText: 'mm'),
        ),
      ] else if (_chargementEchantillons)
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
          ),
        )
      else if (_erreurChargementEchantillons != null)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Text(
            _erreurChargementEchantillons!,
            style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
          ),
        )
      else if (_gammesDetectees.isEmpty)
        const Text(
          'Aucun échantillon à afficher.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        )
      else
        for (final gamme in _gammesDetectees) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  gamme['nom_gamme'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 10),
                for (final ech
                    in List<String>.from(gamme['echantillons'] as List))
                  _buildChampsFlexionEchantillon(
                    gamme['nom_gamme'] as String,
                    ech,
                  ),
              ],
            ),
          ),
        ],
    ];
  }

  Widget _buildChampsFlexionEchantillon(String nomGamme, String identifiant) {
    final suffixe = '$nomGamme/$identifiant';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Échantillon $identifiant',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: ValueKey('flexion-portee-$suffixe'),
            controller: _porteeParEchCtrl[nomGamme]![identifiant],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Portée L (mm)', suffixText: 'mm'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: ValueKey('flexion-base-$suffixe'),
            controller: _baseParEchCtrl[nomGamme]![identifiant],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Base b (mm)', suffixText: 'mm'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: ValueKey('flexion-hauteur-$suffixe'),
            controller: _hauteurParEchCtrl[nomGamme]![identifiant],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Hauteur h (mm)', suffixText: 'mm'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChampsCompression() {
    return [
      const Text(
        'Dimensions des éprouvettes',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
      ),
      const SizedBox(height: 4),
      const Text(
        'La feuille de dimensions par échantillon n\'étant pas encore fournie par le labo, '
        'deux modes de saisie restent possibles pour l\'instant.',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
      ),
      const SizedBox(height: 16),
      SegmentedButton<_ModeSaisieCompression>(
        segments: const [
          ButtonSegment(
            value: _ModeSaisieCompression.global,
            label: Text('Global'),
            icon: Icon(Icons.public_rounded, size: 16),
          ),
          ButtonSegment(
            value: _ModeSaisieCompression.parEchantillon,
            label: Text('Par échantillon'),
            icon: Icon(Icons.view_list_rounded, size: 16),
          ),
        ],
        selected: {_modeCompression},
        onSelectionChanged: (selection) =>
            _basculerModeCompression(selection.first),
      ),
      const SizedBox(height: 16),
      if (_modeCompression == _ModeSaisieCompression.global) ...[
        TextField(
          controller: _l0CompressionGlobalCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(labelText: 'L0 (mm)', suffixText: 'mm'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _sectionCompressionGlobalCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Section (mm²)', suffixText: 'mm²'),
        ),
      ] else ...[
        if (_chargementEchantillons)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            ),
          )
        else if (_erreurChargementEchantillons != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Text(
              _erreurChargementEchantillons!,
              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
            ),
          )
        else ...[
          const Text(
            'L0/Section laissés vides ci-dessous utilisent les valeurs globales '
            'ci-dessus comme repli, si renseignées.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _l0CompressionGlobalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'L0 global (mm, optionnel)', suffixText: 'mm'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sectionCompressionGlobalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Section globale (mm², optionnel)',
                suffixText: 'mm²'),
          ),
          const SizedBox(height: 16),
          for (final gamme in _gammesDetectees) _buildGammeCompression(gamme),
        ],
      ],
    ];
  }

Widget _buildGammeCompression(Map<String, dynamic> gamme) {
    final nomGamme = gamme['nom_gamme'] as String;
    final echantillons = List<String>.from(gamme['echantillons'] as List);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nomGamme,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
          ),
          const SizedBox(height: 10),
          for (final ech in echantillons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                      width: 56,
                      child: Text(ech, style: const TextStyle(fontSize: 13))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _l0ParEchCtrl[nomGamme]![ech],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'L0 (mm)', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _sectionParEchCtrl[nomGamme]![ech],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Section (mm²)', isDense: true),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}