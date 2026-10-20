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
      if (mounted) {
        setState(() => _erreur = 'Impossible de lire le Studio : $error');
      }
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

    try {
      final raw = await _pythonService.executerProtocole(
        protocole: protocole.toProtocoleJson(),
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
      if (mounted) {
        setState(() => _erreur = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _execution = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text(
          'Exécuter un Protocole Studio',
          style: TextStyle(
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
        actions: [
          IconButton(
            tooltip: 'Actualiser les protocoles',
            onPressed: _chargement ? null : _chargerProtocoles,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF374151)),
          ),
        ],
      ),
      body: _chargement
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
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
                        _sectionHeader('PROTOCOLE PERSISTÉ PAR LE STUDIO'),
                        const SizedBox(height: 10),
                        if (_protocoles.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Aucun protocole actif. Veuillez en créer un dans le Studio.',
                                    style: TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          DropdownButtonFormField<ProtocoleModel>(
                            value: _selection,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                            items: _protocoles
                                .map((protocole) => DropdownMenuItem(
                                      value: protocole,
                                      child: Text(
                                        '${protocole.codeNorme} — ${protocole.titre} v${protocole.version}',
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A1A),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(() => _selection = value),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
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
                            ),
                          ),
                        const SizedBox(height: 28),
                        _sectionHeader('FICHIER DE MESURES EXCEL'),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _execution ? null : _selectionnerExcel,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _cheminExcel != null ? const Color(0xFFE8F5E9) : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _cheminExcel != null ? const Color(0xFFA5D6A7) : const Color(0xFFE5E7EB),
                                width: _cheminExcel != null ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _cheminExcel != null ? Icons.description_rounded : Icons.upload_file_rounded,
                                  color: _cheminExcel != null ? const Color(0xFF1B5E20) : const Color(0xFF9CA3AF),
                                  size: 24,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _cheminExcel != null ? 'Fichier sélectionné' : 'Aucun fichier sélectionné',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _cheminExcel != null ? const Color(0xFF1B5E20) : const Color(0xFF9CA3AF),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _cheminExcel == null ? 'Sélectionner un fichier Excel (.xlsx, .xls)' : p.basename(_cheminExcel!),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _cheminExcel != null ? const Color(0xFF1A1A1A) : const Color(0xFF6B7280),
                                          fontWeight: _cheminExcel != null ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _execution ? null : _selectionnerExcel,
                                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                                  label: const Text('Parcourir'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF374151),
                                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: _execution || _protocoles.isEmpty ? null : _executer,
                          icon: _execution
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.play_arrow_rounded, size: 20),
                          label: Text(_execution ? 'Calcul en cours par le moteur Python...' : 'EXÉCUTER LE PROTOCOLE'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            disabledBackgroundColor: const Color(0xFFF3F4F6),
                            disabledForegroundColor: const Color(0xFF9CA3AF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                        if (_erreur != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _erreur!,
                                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}