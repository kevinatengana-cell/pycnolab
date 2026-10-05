import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/python_engine_service.dart';
import '../services/history_service.dart';
import '../models/resultat_gamme.dart';
import 'resultats_screen.dart';
import '../models/gamme_request.dart';

class ImportScreen extends StatefulWidget {
  final GammeRequest? configInitiale;
  final String typeEssai;

  const ImportScreen({super.key, this.configInitiale, this.typeEssai = "traction"});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final PythonEngineService _pythonService = PythonEngineService();
  bool _isLoading = false;
  String? _nomFichierSelectionne;

  Future<void> _importerEtCalculerExcel() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // Le lecteur Python exige un classeur structure ; un CSV ne peut pas etre importe.
      allowedExtensions: ['xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      final String filePath = result.files.single.path!;
      
      setState(() {
        _nomFichierSelectionne = result.files.single.name;
        _isLoading = true;
      });

      try {
        // Envoi du chemin du fichier au backend Python
        final dynamic resultatsJson = await _pythonService.calculerDepuisExcel(
          filePath,
          widget.configInitiale,
          widget.typeEssai,
        );

        setState(() => _isLoading = false);

        // --- DEBUT DU BLOC CORRIGÉ ---
        Map<String, dynamic> donnees;
        if (resultatsJson is ResultatGamme) {
          donnees = resultatsJson.toJson();
        } else if (resultatsJson is Map<String, dynamic>) {
          donnees = resultatsJson;
        } else {
          donnees = Map<String, dynamic>.from(resultatsJson as dynamic);
        }

        // Ajouter au service d'historique
        final ResultatGamme resultatGamme = resultatsJson is ResultatGamme 
            ? resultatsJson 
            : ResultatGamme.fromJson(donnees);
            
        HistoryService.instance.add(resultatGamme);
        // --- FIN DU BLOC CORRIGÉ ---

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultatsScreen(donnees: donnees),
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _afficherErreur("Erreur lors de la lecture du fichier Excel : $e");
      }
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(days: 1),
        action: SnackBarAction(
          label: "OK",
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('PYCNOLAB — Acquisition des Données'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.typeEssai == "compression" ? "Essai de Compression" : "Essai de Traction",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Importez les données brutes issues de votre banc d'essai pour exécuter l'analyse automatique.",
                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              Card(
                elevation: 0,
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blue.withOpacity(0.3), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.table_chart_outlined,
                          size: 48,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _nomFichierSelectionne ?? "Aucun fichier chargé",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _nomFichierSelectionne != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Format accepte : .xlsx",
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 24),

                      _isLoading
                          ? const Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text(
                                  "Traitement par le moteur Python...",
                                  style: TextStyle(fontSize: 13, color: Colors.grey),
                                )
                              ],
                            )
                          : ElevatedButton.icon(
                              onPressed: _importerEtCalculerExcel,
                              icon: const Icon(Icons.file_open_outlined),
                              label: const Text(
                                "Parcourir le fichier Excel",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      "Télécharger le modèle Excel conforme",
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}