import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../models/license_model.dart';
import '../models/resultat_gamme.dart';
import '../models/capture_essai_model.dart';
import '../database/capture_dao.dart';
import '../services/license_service.dart';
import '../services/history_service.dart';
import '../services/python_engine_service.dart';
import 'compare_screen.dart';
import 'config_essai_screen.dart';
import 'informations_screen.dart';
import 'resultats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<ResultatGamme> _selectedLots = {};
  final CaptureDao _captureDao = CaptureDao();
  final PythonEngineService _pythonService = PythonEngineService();

  List<FileSystemEntity> _protocolesLocaux = [];
  List<ResultatGamme> _lotsEnregistres = [];
  Map<String, dynamic>? _protocoleAsset;
  bool _chargementProtocoles = true;
  bool _chargementHistorique = true;
  String? _erreurHistorique;

  @override
  void initState() {
    super.initState();
    _chargerTousLesProtocoles();
    HistoryService.instance.addListener(_onHistoryChanged);
    _chargerHistorique();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _verifierExpirationLicence());
  }

  @override
  void dispose() {
    HistoryService.instance.removeListener(_onHistoryChanged);
    super.dispose();
  }

  List<ResultatGamme> get _historique {
    final lots = [
      ..._lotsEnregistres,
      ...HistoryService.instance.history,
    ];
    lots.sort((a, b) => b.horodatage.compareTo(a.horodatage));
    return lots;
  }

  String _cleLot(ResultatGamme lot) =>
      '${lot.materiauNom}|${lot.normeCode}|${lot.horodatage.toIso8601String()}|'
      '${lot.resistanceMoyenneMpa}';

  void _onHistoryChanged() {
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    if (mounted) {
      setState(() {
        _chargementHistorique = true;
        _erreurHistorique = null;
      });
    }
    try {
      final rows = await _captureDao.listerResultatsEnregistres();
      final lots = <ResultatGamme>[];
      for (final row in rows) {
        final donnees = Map<String, dynamic>.from(row['donnees']! as Map);
        lots.addAll(
          resultatsVersHistorique(
            donnees,
            row['type_essai']! as String,
            horodatage: DateTime.parse(row['calcule_le']! as String),
            captureId: (row['capture_id']! as num).toInt(),
          ),
        );
      }

      if (!mounted) return;
      final selections = _selectedLots.map(_cleLot).toSet();
      setState(() {
        _lotsEnregistres = lots;
        _chargementHistorique = false;
        _selectedLots
          ..clear()
          ..addAll(
              _historique.where((lot) => selections.contains(_cleLot(lot))));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementHistorique = false;
        _erreurHistorique = 'Impossible de charger les essais enregistrés : $e';
      });
    }
  }

  Future<void> _ouvrirResultatEnregistre(int captureId) async {
    try {
      final capture = await _captureDao.lireCapture(captureId);
      final resultat = await _captureDao.lireDernierResultat(captureId);
      if (capture == null || resultat == null) {
        throw StateError('Les données de ce résultat sont introuvables.');
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultatsScreen(
            donnees: Map<String, dynamic>.from(resultat),
            typeEssai: capture.typeEssai,
            onExporter: () => _reexporterCapture(capture),
          ),
        ),
      );
    } catch (error) {
      _afficherMessage('Impossible d’ouvrir les résultats : $error',
          erreur: true);
    }
  }

  Future<void> _supprimerEssaiEnregistre(ResultatGamme lot) async {
    final captureId = lot.captureId;
    if (captureId == null) return;

    final confirmer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
        title: const Text('Supprimer cet essai enregistré ?'),
        content: Text(
          'La capture « ${lot.materiauNom} » et tous ses résultats associés '
          'seront supprimés définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmer != true) return;

    try {
      await _captureDao.supprimerCapture(captureId);
      if (!mounted) return;
      setState(() {
        _selectedLots
            .removeWhere((selected) => selected.captureId == captureId);
      });
      await _chargerHistorique();
      if (mounted) _afficherMessage('Essai supprimé.');
    } catch (error) {
      _afficherMessage('Impossible de supprimer l’essai : $error',
          erreur: true);
    }
  }

  Future<void> _reexporterCapture(CaptureEssai capture) async {
    var cheminSource = capture.cheminSource;
    if (cheminSource == null || !await File(cheminSource).exists()) {
      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: 'Sélectionner le classeur Excel source à réexporter',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (selection == null) return;
      cheminSource = selection.files.single.path;
      if (cheminSource == null) {
        throw StateError(
            'Le chemin du classeur Excel sélectionné est invalide.');
      }
    }

    final nomBase = capture.nomFichier == null
        ? 'RAPPORT_${capture.typeEssai.toUpperCase()}'
        : 'RAPPORT_${p.basenameWithoutExtension(capture.nomFichier!)}';
    final destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Réexporter le rapport Excel',
      fileName: '$nomBase.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (destination == null) return;

    final geometrie = Map<String, dynamic>.from(capture.geometrie);
    final forme = geometrie['forme'] as String?;
    final output = await _pythonService.exporterEssaiExcel(
      typeEssai: capture.typeEssai,
      cheminFichier: cheminSource,
      cheminDestination: destination,
      l0Mm: (geometrie['l0_mm'] as num?)?.toDouble(),
      geometrieCompression:
          capture.typeEssai == 'compression' ? geometrie : null,
      geometrieFlexion: capture.typeEssai == 'flexion' ? geometrie : null,
      geometrieTraction:
          capture.typeEssai == 'traction' ? geometrie : null,
      forme: forme,
    );
    _afficherMessage('Rapport réexporté : $output');
  }

  void _afficherMessage(String message, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: erreur ? Colors.red.shade700 : null,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  /// Seuil sous lequel l'alerte d'expiration s'affiche au démarrage, adapté
  /// à la durée totale de la licence (un seuil unique serait inadapté).
  Duration _seuilAlerte(LicenseModel license) {
    final total = Duration(seconds: license.totalSeconds);
    if (total.inDays >= 180) return const Duration(days: 30);
    if (total.inDays >= 30) return const Duration(days: 7);
    if (total.inDays >= 1) return const Duration(days: 3);
    return const Duration(minutes: 5);
  }

  String _formatRestant(Duration d) {
    if (d.inDays >= 1) return '${d.inDays} jour(s)';
    if (d.inHours >= 1) {
      final m = d.inMinutes.remainder(60);
      return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
    }
    final m = d.inMinutes < 1 ? 1 : d.inMinutes;
    return '$m minute(s)';
  }

  /// Alerte affichée à chaque démarrage de l'application tant que la
  /// licence est sous son seuil d'expiration.
  Future<void> _verifierExpirationLicence() async {
    final license = await LicenseService().getSavedLicense();
    if (!mounted || license == null || license.isExpired) return;
    final restant = license.remainingTime;
    if (restant > _seuilAlerte(license)) return;

    final urgent = restant <= const Duration(days: 3);
    final couleur = urgent ? const Color(0xFFC62828) : const Color(0xFFE65100);
    final voirLicence = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          urgent ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
          color: couleur,
          size: 40,
        ),
        title: const Text('Licence bientôt expirée'),
        content: Text(
          'Votre licence expire dans ${_formatRestant(restant)}.\n'
          'Pensez à la renouveler pour continuer à utiliser PycnoLab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Voir ma licence'),
          ),
        ],
      ),
    );
    if (voirLicence == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const InformationsScreen()),
      );
    }
  }

  /// Charge le protocole embarqué (Asset) et scanne le dossier local /protocoles
  Future<void> _chargerTousLesProtocoles() async {
    if (!mounted) return;
    setState(() => _chargementProtocoles = true);

    // 1. Chargement de l'Asset JSON intégré
    try {
      final jsonString =
          await rootBundle.loadString('assets/json/protocoles.json');
      final data = jsonDecode(jsonString);
      if (mounted) {
        setState(() {
          _protocoleAsset = data is List ? data.first : data;
        });
      }
    } catch (e) {
      debugPrint("Aucun asset protocole embarqué chargé: $e");
    }

    // 2. Scan du dossier /protocoles
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final protocoleDir = Directory(p.join(exeDir.path, 'protocoles'));

      if (await protocoleDir.exists()) {
        final fichiers = protocoleDir
            .listSync()
            .where((entity) => entity.path.endsWith('.json'))
            .toList();

        if (mounted) {
          setState(() {
            _protocolesLocaux = fichiers;
          });
        }
      } else {
        await protocoleDir.create(recursive: true);
      }
    } catch (e) {
      debugPrint("Erreur lors de la lecture des protocoles: $e");
    } finally {
      if (mounted) setState(() => _chargementProtocoles = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = _historique;
    final int totalProtocoles =
        _protocolesLocaux.length + (_protocoleAsset != null ? 1 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 64,
        title: Row(
          children: [
            Image.asset(
              'assets/images/LOGOS.jpg',
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.science_rounded,
                color: Color(0xFF1B5E20),
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'PYCNOLAB',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 19,
                color: Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF374151)),
            tooltip: "Rafraîchir les protocoles",
            onPressed: _chargerTousLesProtocoles,
          ),
          PopupMenuButton<String>(
            tooltip: 'Informations',
            icon: const Icon(Icons.info_outline_rounded,
                color: Color(0xFF374151)),
            onSelected: (value) {
              if (value == 'licence' || value == 'contact') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const InformationsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'licence',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.verified_user_outlined,
                      color: Color(0xFF1B5E20)),
                  title: Text('Licence en cours'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'contact',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.email_outlined, color: Color(0xFF1B5E20)),
                  title: Text('Contacter le développeur'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre & En-tête de page
            const Text(
              "Tableau de Bord LIMS",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Sélectionnez un module d'essai ou gérez vos protocoles et mesures de laboratoire.",
              style: TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
            ),
            const SizedBox(height: 28),

            // 1. Modules & Protocoles
            const Text(
              "MODULES & PROTOCOLES D'ESSAI",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 14),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(
                  context,
                  title: "Essai de Traction",
                  subtitle:
                      "ISO 527 / ASTM D638\nImportation de fichiers Excel",
                  icon: Icons.unfold_more_rounded,
                  color: const Color(0xFF1B5E20),
                  badgeText: "Prêt",
                  badgeColor: const Color(0xFF2E7D32),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ConfigEssaiScreen(typeEssai: "traction"),
                      ),
                    );
                    setState(() {});
                  },
                ),
                _buildActionCard(
                  context,
                  title: "Essai de Compression",
                  subtitle:
                      "ISO 604 / ASTM D695\nImportation de fichiers Excel",
                  icon: Icons.compress_rounded,
                  color: const Color(0xFF6D28D9),
                  badgeText: "Prêt",
                  badgeColor: const Color(0xFF7C3AED),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ConfigEssaiScreen(typeEssai: "compression"),
                      ),
                    );
                    setState(() {});
                  },
                ),
                _buildActionCard(
                  context,
                  title: "Essai de Flexion",
                  subtitle:
                      "ISO 178 / ASTM D790\nImportation de fichiers Excel",
                  icon: Icons.horizontal_split_rounded,
                  color: const Color(0xFF0369A1),
                  badgeText: "Prêt",
                  badgeColor: const Color(0xFF0284C7),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ConfigEssaiScreen(typeEssai: "flexion"),
                      ),
                    );
                    setState(() {});
                  },
                ),
                _buildActionCard(
                  context,
                  title: "Studio des Normes",
                  subtitle:
                      "Créer et versionner des normes personnalisées(prochainement)",
                  icon: Icons.design_services_rounded,
                  color: const Color(0xFF1565C0),
                  badgeText: "Conception",
                  badgeColor: const Color(0xFF1976D2),
                  onTap: null,
                ),
                _buildActionCard(
                  context,
                  title: "Moteur d'Exécution",
                  subtitle:
                      "Exécuter des protocoles JSON automatisés(prochainement)",
                  icon: Icons.play_circle_filled_rounded,
                  color: const Color(0xFF2E7D32),
                  badgeText: "Exécution",
                  badgeColor: const Color(0xFF4CAF50),
                  onTap: null,
                ),
              ],
            ),

            const SizedBox(height: 36),

            // 2. Protocoles Chargés & Enregistrés
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "PROTOCOLES REGISTRES",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 1.1,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$totalProtocoles disponible(s)",
                    style: const TextStyle(
                      color: Color(0xFF1B5E20),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_chargementProtocoles)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
                ),
              )
            else if (totalProtocoles == 0)
              Card(
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      "Aucun protocole trouvé dans /protocoles ni dans assets.\nUtilisez le Studio des Normes pour en enregistrer un.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    if (_protocoleAsset != null) ...[
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFFF8E1),
                          child: const Icon(Icons.memory_rounded,
                              color: Color(0xFFF57F17), size: 20),
                        ),
                        title: Text(
                          _protocoleAsset!['code'] ??
                              _protocoleAsset!['nom'] ??
                              'Protocole Standard (Asset)',
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          "Inclus par défaut (assets/json/protocoles.json)",
                          style:
                              TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                        ),
                        trailing: OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text("Exécuter"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1B5E20),
                            side: const BorderSide(color: Color(0xFF81C784)),
                          ),
                          onPressed: () async {
                            await Navigator.pushNamed(
                                context, '/runner-protocole');
                            _chargerTousLesProtocoles();
                          },
                        ),
                      ),
                      if (_protocolesLocaux.isNotEmpty)
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    ],
                    ..._protocolesLocaux.map((file) {
                      final fileName = p.basename(file.path);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE8F5E9),
                          child: const Icon(Icons.code_rounded,
                              color: Color(0xFF1B5E20), size: 20),
                        ),
                        title: Text(
                          fileName,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          file.path,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text("Exécuter"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1B5E20),
                            side: const BorderSide(color: Color(0xFF81C784)),
                          ),
                          onPressed: () async {
                            await Navigator.pushNamed(
                                context, '/runner-protocole');
                            _chargerTousLesProtocoles();
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),

            const SizedBox(height: 36),

            // 3. Section Historique des Lots
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "LOTS D'ESSAIS ET COMPARAISONS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 1.1,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _selectedLots.length >= 2
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CompareScreen(
                                  selectedLots: _selectedLots.toList()),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                  label: Text("Comparer les lots (${_selectedLots.length})"),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_erreurHistorique != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      _erreurHistorique!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFC62828)),
                    ),
                  ),
                ),
              )
            else if (_chargementHistorique && history.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (history.isEmpty)
              Card(
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      "Aucun essai enregistré pour le moment.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
                ),
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  itemBuilder: (context, index) {
                    final lot = history[index];
                    final isSelected = _selectedLots.contains(lot);

                    IconData statusIcon = Icons.check_circle_rounded;
                    Color statusColor = const Color(0xFF2E7D32);
                    Color statusBg = const Color(0xFFE8F5E9);
                    String statusLabel = "CONFORME";

                    if (lot.statut == "non_conforme") {
                      statusIcon = Icons.cancel_rounded;
                      statusColor = const Color(0xFFC62828);
                      statusBg = const Color(0xFFFFEBEE);
                      statusLabel = "NON CONFORME";
                    } else if (lot.statut == "non_evalue") {
                      statusIcon = Icons.help_rounded;
                      statusColor = const Color(0xFFE65100);
                      statusBg = const Color(0xFFFFF3E0);
                      statusLabel = "NON ÉVALUÉ";
                    }

                    return CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedLots.add(lot);
                          } else {
                            _selectedLots.remove(lot);
                          }
                        });
                      },
                      activeColor: const Color(0xFF1B5E20),
                      checkColor: Colors.white,
                      title: Text(
                        "Lot : ${lot.materiauNom}",
                        style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      isThreeLine: false,
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (lot.captureId != null)
                            IconButton(
                              tooltip: 'Voir les résultats détaillés',
                              onPressed: () =>
                                  _ouvrirResultatEnregistre(lot.captureId!),
                              icon: const Icon(Icons.open_in_new_rounded),
                            ),
                          if (lot.captureId != null)
                            IconButton(
                              tooltip: 'Supprimer cet essai enregistré',
                              onPressed: () => _supprimerEssaiEnregistre(lot),
                              color: Colors.red.shade700,
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "Norme ${lot.normeCode}  •  ${lot.resultatsEchantillons.length} échantillon(s)  •  Résistance moy. : ${lot.resistanceMoyenneMpa.toStringAsFixed(1)} MPa",
                          style: const TextStyle(
                              color: Color(0xFF5F6368), fontSize: 13),
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback? onTap,
  }) {
    final bool isEnabled = onTap != null;

    return Card(
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? color.withOpacity(0.08)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        color: isEnabled ? color : const Color(0xFF9CA3AF),
                        size: 24),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  )
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isEnabled
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled
                          ? const Color(0xFF5F6368)
                          : const Color(0xFF9CA3AF),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}