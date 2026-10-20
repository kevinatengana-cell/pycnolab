
import 'package:pycnolab/models/gamme_request.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/capture_dao.dart';
import '../services/python_engine_service.dart';
import 'dimensions_essai_screen.dart';

class ImportScreen extends StatefulWidget {
  final Object? configInitiale;
  final String typeEssai;

  const ImportScreen({super.key, this.configInitiale, this.typeEssai = 'traction'});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String? _cheminFichierSelectionne;
  String? _nomFichierSelectionne;
  int? _captureId;
  bool _importEnCours = false;
  String? _erreurImport;

  final CaptureDao _captureDao = CaptureDao();
  final PythonEngineService _pythonService = PythonEngineService();

  Future<void> _choisirFichier() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null || result.files.single.path == null || !mounted) return;
    setState(() {
      _cheminFichierSelectionne = result.files.single.path!;
      _nomFichierSelectionne = result.files.single.name;
      _captureId = null;
      _erreurImport = null;
    });
  }

  Future<void> _continuerVersDimensions() async {
    final chemin = _cheminFichierSelectionne;
    final nom = _nomFichierSelectionne;
    if (chemin == null || nom == null || _importEnCours) return;
    setState(() {
      _importEnCours = true;
      _erreurImport = null;
    });
    try {
      var captureId = _captureId;
      if (captureId == null) {
        final donnees = await _pythonService.lireDonneesBrutes(
          typeEssai: widget.typeEssai,
          cheminFichier: chemin,
        );
        final configuration = widget.configInitiale;
        final configurationMap = configuration is GammeRequest
            ? configuration.toJson()
            : configuration is Map
                ? Map<String, Object?>.from(configuration)
                : <String, Object?>{};
        captureId = await _captureDao.creerCapture(
          typeEssai: widget.typeEssai,
          origine: 'excel',
          nomFichier: nom,
          cheminSource: chemin,
          donneesMoteur: donnees,
          configuration: configurationMap,
        );
        _captureId = captureId;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DimensionsEssaiScreen(
            typeEssai: widget.typeEssai,
            cheminFichier: chemin,
            nomFichier: nom,
            captureId: captureId,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _erreurImport = 'Import impossible : $error');
      }
    } finally {
      if (mounted) setState(() => _importEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const titresParEssai = {
      'compression': 'Essai de Compression',
      'flexion': 'Essai de Flexion',
      'traction': 'Essai de Traction',
    };
    final titre = titresParEssai[widget.typeEssai] ?? titresParEssai['traction']!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          'Importation de l\'Essai',
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
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
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
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.02),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icône de type d'essai
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.table_chart_rounded,
                        color: Color(0xFF1B5E20),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Titre & Sous-titre
                  Text(
                    titre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sélectionnez le classeur Excel (.xlsx) contenant les séries de mesures brutes '
                    '(Élongation / Force). Les dimensions des éprouvettes seront demandées à l\'étape suivante.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Zone d'aperçu du fichier sélectionné
                  InkWell(
                    onTap: _importEnCours ? null : _choisirFichier,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _nomFichierSelectionne != null
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _nomFichierSelectionne != null
                              ? const Color(0xFFA5D6A7)
                              : const Color(0xFFE5E7EB),
                          width: _nomFichierSelectionne != null ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _nomFichierSelectionne != null
                                ? Icons.insert_drive_file_rounded
                                : Icons.upload_file_rounded,
                            color: _nomFichierSelectionne != null
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFF9CA3AF),
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nomFichierSelectionne != null
                                      ? 'Fichier prêt pour analyse'
                                      : 'Aucun fichier sélectionné',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _nomFichierSelectionne != null
                                        ? const Color(0xFF1B5E20)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _nomFichierSelectionne ?? 'Cliquez pour parcourir vos fichiers',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _nomFichierSelectionne != null
                                        ? const Color(0xFF1A1A1A)
                                        : const Color(0xFF6B7280),
                                    fontWeight: _nomFichierSelectionne != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_nomFichierSelectionne != null)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF1B5E20),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _importEnCours ? null : _choisirFichier,
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: Text(
                          _nomFichierSelectionne != null
                              ? 'Changer de fichier'
                              : 'Sélectionner le fichier Excel',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_erreurImport != null) ...[
                        Text(
                          _erreurImport!,
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.icon(
                        onPressed: _cheminFichierSelectionne == null || _importEnCours
                            ? null
                            : _continuerVersDimensions,
                        icon: _importEnCours
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(
                          _importEnCours
                              ? 'Lecture et sauvegarde en cours...'
                              : 'Continuer — saisir les dimensions',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          disabledBackgroundColor: const Color(0xFFF3F4F6),
                          disabledForegroundColor: const Color(0xFF9CA3AF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
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
}