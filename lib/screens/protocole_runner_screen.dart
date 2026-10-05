import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/python_engine_service.dart';

class ProtocoleInfo {
  final String cheminFichier;
  final String nomAffiche;

  ProtocoleInfo({
    required this.cheminFichier,
    required this.nomAffiche,
  });
}

class ProtocoleRunnerScreen extends StatefulWidget {
  const ProtocoleRunnerScreen({Key? key}) : super(key: key);

  @override
  State<ProtocoleRunnerScreen> createState() => _ProtocoleRunnerScreenState();
}

class _ProtocoleRunnerScreenState extends State<ProtocoleRunnerScreen> {
  final PythonEngineService _pythonService = PythonEngineService();

  ProtocoleInfo? _protocoleSelectionne;
  String? _cheminExcel;
  bool _estEnCours = false;
  String? _erreurMessage;
  Map<String, dynamic>? _resultatJson;

  List<ProtocoleInfo> _protocolesLocaux = [];
  bool _chargementProtocoles = true;

  @override
  void initState() {
    super.initState();
    _chargerProtocolesLocaux();
  }

  /// Extrait le nom personnalisé à l'intérieur de chaque fichier JSON
  Future<void> _chargerProtocolesLocaux() async {
    setState(() => _chargementProtocoles = true);
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final protocoleDir = Directory(p.join(exeDir.path, 'protocoles'));

      if (await protocoleDir.exists()) {
        final fichiers = protocoleDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList();

        List<ProtocoleInfo> charges = [];

        for (var file in fichiers) {
          try {
            final contenu = await file.readAsString();
            final jsonMap = jsonDecode(contenu) as Map<String, dynamic>;

            final nomAffiche = jsonMap['nom'] ?? jsonMap['nom_protocole'] ?? p.basename(file.path);

            charges.add(ProtocoleInfo(
              cheminFichier: file.path,
              nomAffiche: nomAffiche.toString(),
            ));
          } catch (e) {
            charges.add(ProtocoleInfo(
              cheminFichier: file.path,
              nomAffiche: p.basename(file.path),
            ));
          }
        }

        setState(() {
          _protocolesLocaux = charges;
          if (_protocolesLocaux.isNotEmpty) {
            _protocoleSelectionne = _protocolesLocaux.first;
          }
        });
      }
    } catch (e) {
      debugPrint("Erreur de chargement des protocoles: $e");
    } finally {
      setState(() => _chargementProtocoles = false);
    }
  }

  Future<void> _selectionnerFichierExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _cheminExcel = result.files.single.path;
        _erreurMessage = null;
      });
    }
  }

  Future<void> _lancerExecution() async {
    if (_protocoleSelectionne == null || _cheminExcel == null) {
      setState(() {
        _erreurMessage = "Veuillez sélectionner un protocole et un fichier Excel.";
      });
      return;
    }

    setState(() {
      _estEnCours = true;
      _erreurMessage = null;
      _resultatJson = null;
    });

    try {
      // Transmission obligatoire du chemin absolu sur le disque
      final res = await _pythonService.executerProtocole(
        cheminProtocole: _protocoleSelectionne!.cheminFichier,
        cheminFichier: _cheminExcel!,
      );

      setState(() {
        _resultatJson = res as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() {
        _erreurMessage = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      setState(() {
        _estEnCours = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Exécution de Protocole Personnalisé'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "1. CHOIX DU PROTOCOLE",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _chargementProtocoles
                    ? const Center(child: CircularProgressIndicator())
                    : _protocolesLocaux.isEmpty
                        ? const Text(
                            "Aucun protocole trouvé dans le dossier local /protocoles.",
                            style: TextStyle(color: Colors.amber),
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<ProtocoleInfo>(
                              value: _protocoleSelectionne,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                              items: _protocolesLocaux.map((info) {
                                return DropdownMenuItem<ProtocoleInfo>(
                                  value: info,
                                  child: Text(
                                    info.nomAffiche,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _protocoleSelectionne = val);
                              },
                            ),
                          ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "2. FICHIER DE MESURES BRUTES (EXCEL)",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _cheminExcel != null
                            ? p.basename(_cheminExcel!)
                            : "Aucun fichier Excel sélectionné",
                        style: TextStyle(
                          color: _cheminExcel != null ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _selectionnerFichierExcel,
                      icon: const Icon(Icons.folder_open),
                      label: const Text("Parcourir..."),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _estEnCours ? null : _lancerExecution,
                icon: _estEnCours
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _estEnCours ? "Calcul en cours..." : "EXÉCUTER LE PROTOCOLE",
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            if (_erreurMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _erreurMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_resultatJson != null) ...[
              const SizedBox(height: 24),
              Text(
                "Résultats : ${_resultatJson.toString()}",
                style: const TextStyle(color: Colors.white),
              ),
            ]
          ],
        ),
      ),
    );
  }
}