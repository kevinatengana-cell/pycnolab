import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/protocole_model.dart';
import '../models/resultat_gamme.dart';
import '../services/history_service.dart';
import '../services/python_engine_service.dart';
import '../services/studio_protocol_runtime_service.dart';
import 'resultats_screen.dart';

class ProtocoleRunnerScreen extends StatefulWidget {
  const ProtocoleRunnerScreen({super.key});

  @override
  State<ProtocoleRunnerScreen> createState() => _ProtocoleRunnerScreenState();
}

class _ProtocoleRunnerScreenState extends State<ProtocoleRunnerScreen> {
  final _pythonService = PythonEngineService();
  final _studioService = StudioProtocolRuntimeService();

  List<ProtocoleModel> _protocoles = const [];
  ProtocoleModel? _selection;
  String? _cheminExcel;
  String? _erreur;
  bool _chargement = true;
  bool _execution = false;

  @override
  void initState() {
    super.initState();
    _chargerProtocoles();
  }

  Future<void> _chargerProtocoles() async {
    setState(() => _chargement = true);
    try {
      final protocoles = await _studioService.listerProtocolesActifs();
      if (!mounted) return;
      setState(() {
        _protocoles = protocoles;
        _selection = protocoles.isEmpty ? null : protocoles.first;
        _erreur = null;
      });
    } catch (error) {
      if (mounted) setState(() => _erreur = 'Impossible de lire le Studio : $error');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _selectionnerExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    final path = result?.files.single.path;
    if (path != null && mounted) setState(() => _cheminExcel = path);
  }

  Future<void> _executer() async {
    final protocole = _selection;
    final excel = _cheminExcel;
    if (protocole == null || excel == null) {
      setState(() => _erreur = 'Sélectionnez un protocole Studio et un fichier Excel.');
      return;
    }

    setState(() {
      _execution = true;
      _erreur = null;
    });

    StudioProtocolFile? materialized;
    try {
      materialized = await _studioService.materialiser(protocole);
      final raw = await _pythonService.executerProtocole(
        cheminProtocole: materialized.path,
        cheminFichier: excel,
      );
      final donnees = Map<String, dynamic>.from(raw as Map);
      final resultat = ResultatGamme.fromJson(donnees);
      HistoryService.instance.add(resultat);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultatsScreen(donnees: donnees)),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _erreur = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      try {
        await materialized?.file.parent.delete(recursive: true);
      } catch (_) {
        // Le fichier temporaire sera également nettoyé par le système.
      }
      if (mounted) setState(() => _execution = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exécuter un protocole Studio'),
        actions: [IconButton(onPressed: _chargement ? null : _chargerProtocoles, icon: const Icon(Icons.refresh))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PROTOCOLE PERSISTÉ PAR LE STUDIO', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_chargement)
              const LinearProgressIndicator()
            else if (_protocoles.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Aucun protocole actif. Créez-en un dans le Studio.')))
            else
              DropdownButtonFormField<ProtocoleModel>(
                value: _selection,
                isExpanded: true,
                items: _protocoles.map((protocole) => DropdownMenuItem(
                      value: protocole,
                      child: Text('${protocole.codeNorme} — ${protocole.titre} v${protocole.version}'),
                    )).toList(),
                onChanged: (value) => setState(() => _selection = value),
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Norme / protocole'),
              ),
            const SizedBox(height: 24),
            const Text('FICHIER DE MESURES EXCEL', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(_cheminExcel == null ? 'Aucun fichier sélectionné' : p.basename(_cheminExcel!))),
              FilledButton.icon(onPressed: _selectionnerExcel, icon: const Icon(Icons.folder_open), label: const Text('Parcourir')),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _execution ? null : _executer,
                icon: _execution ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
                label: Text(_execution ? 'Calcul en cours...' : 'EXÉCUTER LE PROTOCOLE'),
              ),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 16),
              Text(_erreur!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
