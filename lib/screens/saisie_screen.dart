import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/resultat_gamme.dart';
import '../services/python_engine_service.dart';
import 'resultats_screen.dart';

class SaisieScreen extends StatefulWidget {
  const SaisieScreen({super.key});

  @override
  State<SaisieScreen> createState() => _SaisieScreenState();
}

class _SaisieScreenState extends State<SaisieScreen> {
  final PythonEngineService _pythonService = PythonEngineService();
  bool _isLoading = false;

  Future<void> _importerEtCalculerExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);

      String filePath = result.files.single.path!;

      try {
        final dynamic resultatsJson =
            await _pythonService.calculerDepuisExcel(filePath);
        if (!mounted) return;

        Map<String, dynamic> donnees;
        if (resultatsJson is ResultatGamme) {
          final echantillons = resultatsJson.resultatsEchantillons
              .map((e) => {
                    'identifiant': e.identifiant,
                    'largeur_mm': null,
                    'epaisseur_mm': null,
                    'longueur_initiale_mm': null,
                    'force_rupture_newton': null,
                    'deplacement_rupture_mm': null,
                    'contrainte_rupture_mpa': e.contrainteRuptureMpa,
                    'deformation_rupture_pourcent': e.deformationRupturePourcent,
                  })
              .toList();

          donnees = {
            'echantillons': echantillons,
            'statistiques': {
              'sigma_moyenne': resultatsJson.resistanceMoyenneMpa,
              'sigma_ecart_type': resultatsJson.ecartTypeMpa,
              'epsilon_moyen': resultatsJson.moduleYoungMoyenMpa ?? 0.0,
            }
          };
        } else if (resultatsJson is Map<String, dynamic>) {
          donnees = resultatsJson;
        } else {
          donnees = Map<String, dynamic>.from(resultatsJson as dynamic);
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultatsScreen(
              donnees: donnees,
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors du calcul : $e'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        title: const Text(
          'PYCNOLAB - Essai de Traction',
          style: TextStyle(
            color: Color(0xFF1B5E20),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(32.0),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    size: 40,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Importation du Fichier d\'Essai',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sélectionnez un classeur Excel (.xlsx) pour exécuter l\'analyse des propriétés mécaniques.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _importerEtCalculerExcel,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file, size: 20),
                    label: Text(
                      _isLoading
                          ? 'Calcul en cours...'
                          : 'Charger les données depuis Excel',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}