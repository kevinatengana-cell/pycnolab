import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/capture_dao.dart';
import '../services/history_service.dart';
import '../services/python_engine_service.dart';
import 'resultats_screen.dart';

/// Écran intercalé entre la sélection du fichier brut et le calcul final :
/// demande les variables géométriques propres à l'essai (L0 pour la
/// traction, L0+Section pour la compression, portée/base/hauteur pour la
/// flexion), puis lance le calcul et l'export du fichier Excel complet.
///
/// Traction : détecte la présence d'une feuille de dimensions dans le
/// fichier, propose un menu de forme, et bascule automatiquement entre
/// lecture auto et saisie manuelle.
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

/// Formes supportées par l'exporteur.
const List<({String code, String libelle})> _formesDisponibles = [
  (code: 'cylindre', libelle: 'Circulaire pleine'),
  (code: 'rectangle', libelle: 'Rectangulaire'),
  (code: 'carre', libelle: 'Carrée'),
  (code: 'tube_circulaire', libelle: 'Tube circulaire'),
  (code: 'tube_rectangulaire', libelle: 'Tube rectangulaire'),
  (code: 'surface', libelle: 'Section quelconque'),
];

class _DimensionsEssaiScreenState extends State<DimensionsEssaiScreen> {
  final PythonEngineService _pythonService = PythonEngineService();
  final CaptureDao _captureDao = CaptureDao();

  // --- Traction ---------------------------------------------------------
  final TextEditingController _l0TractionCtrl =
      TextEditingController(text: '20.0');
  String? _formeTraction;
  bool _fichierContientDimensions = false;
  bool _chargementFormes = false;
  String? _erreurChargementFormes;

  // Champs de saisie manuelle des dimensions (traction sans feuille)
  final TextEditingController _dim1Ctrl = TextEditingController();
  final TextEditingController _dim2Ctrl = TextEditingController();
  final TextEditingController _dim3Ctrl = TextEditingController();
  final TextEditingController _dim4Ctrl = TextEditingController();

  // --- Compression ------------------------------------------------------
  _ModeSaisieCompression _modeCompression = _ModeSaisieCompression.global;
  final TextEditingController _l0CompressionGlobalCtrl = TextEditingController();
  final TextEditingController _sectionCompressionGlobalCtrl =
      TextEditingController();
  bool _echantillonsCharges = false;
  bool _chargementEchantillons = false;
  String? _erreurChargementEchantillons;
  final Map<String, Map<String, TextEditingController>> _l0ParEchCtrl = {};
  final Map<String, Map<String, TextEditingController>> _sectionParEchCtrl = {};
  List<Map<String, dynamic>> _gammesDetectees = [];

  // --- Flexion ----------------------------------------------------------
  final TextEditingController _porteeCtrl = TextEditingController(text: '100.0');
  final TextEditingController _baseCtrl = TextEditingController(text: '40.0');
  final TextEditingController _hauteurCtrl = TextEditingController(text: '40.0');

  // --- État global ------------------------------------------------------
  bool _isBusy = false;
  String? _resumeResultat;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    if (widget.typeEssai == 'traction') {
      _detecterFeuilleDimensions();
    }
  }

  @override
  void dispose() {
    _l0TractionCtrl.dispose();
    _dim1Ctrl.dispose();
    _dim2Ctrl.dispose();
    _dim3Ctrl.dispose();
    _dim4Ctrl.dispose();
    _l0CompressionGlobalCtrl.dispose();
    _sectionCompressionGlobalCtrl.dispose();
    for (final parGamme in [
      ..._l0ParEchCtrl.values,
      ..._sectionParEchCtrl.values
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

  // ---------------------------------------------------------------------
  // Détection de la feuille de dimensions
  // ---------------------------------------------------------------------

  Future<void> _detecterFeuilleDimensions() async {
    setState(() {
      _chargementFormes = true;
      _erreurChargementFormes = null;
    });
    try {
      final info = await _pythonService.listerEchantillons(
        typeEssai: widget.typeEssai,
        cheminFichier: widget.cheminFichier,
      );
      final aFeuille = info['a_feuille_dimensions'] as bool? ?? false;
      if (!mounted) return;
      setState(() {
        _fichierContientDimensions = aFeuille;
        _chargementFormes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementFormes = false;
        _erreurChargementFormes =
            'Impossible de lire la structure du fichier : $e';
      });
    }
  }

  // ---------------------------------------------------------------------
  // Calcul local de la section (uniquement pour l'affichage informatif)
  // ---------------------------------------------------------------------

  double? _calculerSectionManuelle() {
    double? v(TextEditingController c) => _lireDouble(c);
    switch (_formeTraction) {
      case 'cylindre':
        final d = v(_dim1Ctrl);
        return d == null ? null : math.pi * (d / 2) * (d / 2);
      case 'rectangle':
        final l = v(_dim1Ctrl);
        final e = v(_dim2Ctrl);
        return (l == null || e == null) ? null : l * e;
      case 'carre':
        final c = v(_dim1Ctrl);
        return c == null ? null : c * c;
      case 'tube_circulaire':
        final de = v(_dim1Ctrl);
        final di = v(_dim2Ctrl);
        return (de == null || di == null)
            ? null
            : math.pi * (de * de - di * di) / 4;
      case 'tube_rectangulaire':
        final b = v(_dim1Ctrl);
        final h = v(_dim2Ctrl);
        final bi = v(_dim3Ctrl);
        final hi = v(_dim4Ctrl);
        if (b == null || h == null || bi == null || hi == null) return null;
        return b * h - bi * hi;
      case 'surface':
        return v(_dim1Ctrl);
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------
  // Construction de la géométrie
  // ---------------------------------------------------------------------

  Map<String, dynamic>? _construireGeometrieTraction() {
    if (widget.typeEssai != 'traction') return null;
    final l0 = _lireDouble(_l0TractionCtrl);
    final section =
        _fichierContientDimensions ? null : _calculerSectionManuelle();
    final geometrie = <String, dynamic>{};
    if (l0 != null) geometrie['l0_mm'] = l0;
    if (section != null) geometrie['section_mm2'] = section;
    if (_formeTraction != null) geometrie['forme'] = _formeTraction;
    return geometrie;
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
        if (dimsGamme.isNotEmpty) {
          dimensionsParEchantillon[nomGamme] = dimsGamme;
        }
      }
      if (dimensionsParEchantillon.isNotEmpty) {
        geometrie['dimensions_par_echantillon'] = dimensionsParEchantillon;
      }
    }
    return geometrie;
  }

  Map<String, dynamic>? _construireGeometrieFlexion() {
    if (widget.typeEssai != 'flexion') return null;
    return {
      'portee_mm': _lireDouble(_porteeCtrl) ?? 0,
      'base_mm': _lireDouble(_baseCtrl) ?? 0,
      'hauteur_mm': _lireDouble(_hauteurCtrl) ?? 0,
    };
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
        return {
          'l0_mm': _l0Traction ?? 20.0,
          if (_formeTraction != null) 'forme': _formeTraction,
          if (!_fichierContientDimensions)
            'section_mm2': _calculerSectionManuelle(),
        };
    }
  }

  Future<void> _sauvegarderGeometrie() async {
    final captureId = widget.captureId;
    if (captureId != null) {
      await _captureDao.enregistrerGeometrie(captureId, _geometrieCapture());
    }
  }

  // ---------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------

  String? _validerSaisie() {
    if (widget.typeEssai == 'traction') {
      if (_formeTraction == null) {
        return 'Sélectionnez la forme de l\'éprouvette.';
      }
      final l0 = _lireDouble(_l0TractionCtrl);
      if (l0 == null || l0 <= 0) {
        return 'L0 doit être une valeur positive.';
      }
      if (!_fichierContientDimensions) {
        final s = _calculerSectionManuelle();
        if (s == null || s <= 0) {
          return 'Renseignez toutes les dimensions pour calculer la section.';
        }
      }
    }
    if (widget.typeEssai == 'flexion') {
      final g = _construireGeometrieFlexion()!;
      if ((g['portee_mm'] as num) <= 0 ||
          (g['base_mm'] as num) <= 0 ||
          (g['hauteur_mm'] as num) <= 0) {
        return 'Portée, base et hauteur doivent être renseignées et positives.';
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Chargement des échantillons (compression, mode par échantillon)
  // ---------------------------------------------------------------------

  Future<void> _basculerModeCompression(_ModeSaisieCompression mode) async {
    setState(() => _modeCompression = mode);
    if (mode == _ModeSaisieCompression.parEchantillon && !_echantillonsCharges) {
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
                    .map((sample) =>
                        (sample as Map<String, dynamic>)['identifiant'] as String)
                    .toList(),
              };
            }).toList();
      for (final gamme in gammes) {
        final nomGamme = gamme['nom_gamme'] as String;
        final echantillons = List<String>.from(gamme['echantillons'] as List);
        _l0ParEchCtrl[nomGamme] = {
          for (final ech in echantillons) ech: TextEditingController()
        };
        _sectionParEchCtrl[nomGamme] = {
          for (final ech in echantillons) ech: TextEditingController()
        };
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

  // ---------------------------------------------------------------------
  // Calcul et export
  // ---------------------------------------------------------------------

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

      // Toujours relire le fichier source pour recalculer les sections :
      // la capture SQLite contient les courbes brutes mais pas les sections,
      // qui dépendent de la forme et des dimensions saisies dans cet écran.
      final resultat = await _pythonService.calculerEssaiDepuisExcel(
        typeEssai: widget.typeEssai,
        cheminFichier: widget.cheminFichier,
        l0Mm: _l0Traction,
        geometrieCompression: _construireGeometrieCompression(),
        geometrieFlexion: _construireGeometrieFlexion(),
        geometrieTraction: _construireGeometrieTraction(),
        forme: _formeTraction,
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
        geometrieCompression: _construireGeometrieCompression(),
        geometrieFlexion: _construireGeometrieFlexion(),
        geometrieTraction: _construireGeometrieTraction(),
        forme: _formeTraction,
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

  // ---------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------

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
            constraints: const BoxConstraints(maxWidth: 720),
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

  // ---------------------------------------------------------------------
  // Bloc traction
  // ---------------------------------------------------------------------

  List<Widget> _buildChampsTraction() {
    return [
      const Text(
        'Forme de l\'éprouvette',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
      ),
      const SizedBox(height: 4),
      const Text(
        'Valeur globale appliquée à toutes les gammes du fichier.',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _formeTraction,
        decoration: const InputDecoration(
          labelText: 'Forme',
          border: OutlineInputBorder(),
        ),
        items: _formesDisponibles
            .map((f) => DropdownMenuItem<String>(
                  value: f.code,
                  child: Text(f.libelle),
                ))
            .toList(),
        onChanged: (v) => setState(() => _formeTraction = v),
      ),
      const SizedBox(height: 20),
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
      const SizedBox(height: 20),
      if (_chargementFormes)
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
          ),
        )
      else if (_erreurChargementFormes != null)
        _buildMessage(const Color(0xFFFEF2F2), const Color(0xFFFCA5A5),
            const Color(0xFF991B1B), _erreurChargementFormes!)
      else if (_fichierContientDimensions)
        _buildMessage(
          const Color(0xFFE8F5E9),
          const Color(0xFFA5D6A7),
          const Color(0xFF1B5E20),
          'Les sections seront lues automatiquement depuis le fichier.',
        )
      else ...[
        _buildMessage(
          const Color(0xFFFFF3E0),
          const Color(0xFFFFCC80),
          const Color(0xFFE65100),
          'Aucune feuille de dimensions détectée. Saisissez les valeurs ci-dessous.',
        ),
        const SizedBox(height: 16),
        ..._buildChampsDimensionsManuelles(),
      ],
    ];
  }

  Widget _buildMessage(Color fond, Color bordure, Color texte, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bordure),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: texte, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: texte, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChampsDimensionsManuelles() {
    final widgets = <Widget>[];

    Widget champ(String label, TextEditingController ctrl, String suffixe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffixe,
          ),
          onChanged: (_) => setState(() {}),
        ),
      );
    }

    switch (_formeTraction) {
      case 'cylindre':
        widgets.add(champ('Diamètre (mm)', _dim1Ctrl, 'mm'));
        break;
      case 'rectangle':
        widgets.add(champ('Largeur L (mm)', _dim1Ctrl, 'mm'));
        widgets.add(champ('Épaisseur E (mm)', _dim2Ctrl, 'mm'));
        break;
      case 'carre':
        widgets.add(champ('Côté C (mm)', _dim1Ctrl, 'mm'));
        break;
      case 'tube_circulaire':
        widgets.add(champ('Diamètre extérieur (mm)', _dim1Ctrl, 'mm'));
        widgets.add(champ('Diamètre intérieur (mm)', _dim2Ctrl, 'mm'));
        break;
      case 'tube_rectangulaire':
        widgets.add(champ('B extérieur (mm)', _dim1Ctrl, 'mm'));
        widgets.add(champ('H extérieur (mm)', _dim2Ctrl, 'mm'));
        widgets.add(champ('b intérieur (mm)', _dim3Ctrl, 'mm'));
        widgets.add(champ('h intérieur (mm)', _dim4Ctrl, 'mm'));
        break;
      case 'surface':
        widgets.add(champ('Section S (mm²)', _dim1Ctrl, 'mm²'));
        break;
      default:
        break;
    }

    final section = _calculerSectionManuelle();
    if (section != null && section > 0) {
      widgets.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calculate_rounded,
                  color: Color(0xFF1B5E20), size: 18),
              const SizedBox(width: 8),
              Text(
                'Section calculée : ${section.toStringAsFixed(4)} mm²',
                style: const TextStyle(
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  // ---------------------------------------------------------------------
  // Bloc flexion
  // ---------------------------------------------------------------------

  List<Widget> _buildChampsFlexion() {
    return [
      const Text(
        'Géométrie de l\'éprouvette (flexion 3 points)',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
      ),
      const SizedBox(height: 4),
      const Text(
        'Valeurs globales, identiques pour tous les échantillons du fichier.',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _porteeCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration:
            const InputDecoration(labelText: 'Portée L (mm)', suffixText: 'mm'),
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
    ];
  }

  // ---------------------------------------------------------------------
  // Bloc compression (inchangé)
  // ---------------------------------------------------------------------

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
          _buildMessage(const Color(0xFFFEF2F2), const Color(0xFFFCA5A5),
              const Color(0xFF991B1B), _erreurChargementEchantillons!)
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