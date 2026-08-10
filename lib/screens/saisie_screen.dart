import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/python_engine_service.dart'; // Ton service FFI
import '../models/resultat_gamme.dart';
import 'resultats_screen.dart'; // Ton écran de résultats

class SaisieScreen extends StatefulWidget {
  const SaisieScreen({Key? key}) : super(key: key);

  @override
  _SaisieScreenState createState() => _SaisieScreenState();
}

class _SaisieScreenState extends State<SaisieScreen> {
  final PythonEngineService _pythonService = PythonEngineService();
  bool _isLoading = false;

  Future<void> _importerEtCalculerExcel() async {
    // 1. Déclencher le sélecteur de fichier Windows
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);

      String filePath = result.files.single.path!;

      try {
        final dynamic resultatsJson = await _pythonService.calculerDepuisExcel(filePath);
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
                    'allongement_rupture_pourcent': e.deformationRupturePourcent,
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
            builder: (context) => ResultatsScreen(donnees: donnees),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors du calcul : $e'),
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
      appBar: AppBar(title: const Text('PYCNOLAB - Essai de Traction')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: _importerEtCalculerExcel,
                icon: const Icon(Icons.upload_file, size: 28),
                label: const Text(
                  'Charger les données depuis Excel',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
      ),
    );
  }
}