import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/resultat_gamme.dart';
import '../services/history_service.dart';
import 'compare_screen.dart';
import 'config_essai_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<ResultatGamme> _selectedLots = {};
  
  List<FileSystemEntity> _protocolesLocaux = [];
  bool _chargementProtocoles = true;

  @override
  void initState() {
    super.initState();
    _chargerProtocolesLocaux();
  }

  /// Scanne le dossier /protocoles à côté de l'exécutable
  Future<void> _chargerProtocolesLocaux() async {
    if (!mounted) return;
    setState(() => _chargementProtocoles = true);
    
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
  void initState() {
    super.initState();
    // Pre-populate with mock lots for easy visual verification if history is empty
    if (HistoryService.instance.history.isEmpty) {
      final lotA = ResultatGamme(
        materiauNom: "Lin Standard",
        normeCode: "ISO 527-4",
        horodatage: DateTime.now().subtract(const Duration(hours: 2)),
        resultatsEchantillons: [
          ResultatEchantillon(identifiant: "ECH-01", contrainteRuptureMpa: 310, deformationRupturePourcent: 2.2, moduleYoungMpa: 17500),
          ResultatEchantillon(identifiant: "ECH-02", contrainteRuptureMpa: 331, deformationRupturePourcent: 2.6, moduleYoungMpa: 19500),
        ],
        resistanceMoyenneMpa: 320.5,
        ecartTypeMpa: 14.8,
        moduleYoungMoyenMpa: 18500.0,
        statut: "conforme",
        deformationMoyennePourcent: 2.4,
        ecartTypeDeformationPourcent: 0.28,
        ecartTypeModuleYoungMpa: 1414.2,
      );

      final lotB = ResultatGamme(
        materiauNom: "Chanvre Premium",
        normeCode: "ISO 527-4",
        horodatage: DateTime.now().subtract(const Duration(hours: 1)),
        resultatsEchantillons: [
          ResultatEchantillon(identifiant: "ECH-01", contrainteRuptureMpa: 275, deformationRupturePourcent: 2.9, moduleYoungMpa: 14800),
          ResultatEchantillon(identifiant: "ECH-02", contrainteRuptureMpa: 285.4, deformationRupturePourcent: 3.3, moduleYoungMpa: 16000),
        ],
        resistanceMoyenneMpa: 280.2,
        ecartTypeMpa: 7.35,
        moduleYoungMoyenMpa: 15400.0,
        statut: "conforme",
        deformationMoyennePourcent: 3.1,
        ecartTypeDeformationPourcent: 0.28,
        ecartTypeModuleYoungMpa: 848.5,
      );

      final lotC = ResultatGamme(
        materiauNom: "Ortie Sauvage",
        normeCode: "ISO 527-4",
        horodatage: DateTime.now(),
        resultatsEchantillons: [
          ResultatEchantillon(identifiant: "ECH-01", contrainteRuptureMpa: 385.6, deformationRupturePourcent: 1.6, moduleYoungMpa: 20800),
          ResultatEchantillon(identifiant: "ECH-02", contrainteRuptureMpa: 436.0, deformationRupturePourcent: 2.0, moduleYoungMpa: 23400),
        ],
        resistanceMoyenneMpa: 410.8,
        ecartTypeMpa: 35.6,
        moduleYoungMoyenMpa: 22100.0,
        statut: "non_conforme",
        deformationMoyennePourcent: 1.8,
        ecartTypeDeformationPourcent: 0.28,
        ecartTypeModuleYoungMpa: 1838.4,
      );

      HistoryService.instance.add(lotA);
      HistoryService.instance.add(lotB);
      HistoryService.instance.add(lotC);

      // Pre-select the lots so the button is immediately active and ready to compare
      _selectedLots.add(lotA);
      _selectedLots.add(lotB);
      _selectedLots.add(lotC);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = HistoryService.instance.history;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate-900
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.science_outlined, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text(
              'PYCNOLAB',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Rafraîchir les protocoles",
            onPressed: _chargerProtocolesLocaux,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tableau de bord du Laboratoire",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Sélectionnez un module ou importez vos fichiers de mesure pour démarrer une analyse.",
              style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 32),

            // 1. Modules d'essais
            const Text(
              "MODULES & PROTOCOLES",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _buildActionCard(
                  context,
                  title: "Essai de Traction",
                  subtitle: "ISO 527 / ASTM D638\nImport Excel standard",
                  icon: Icons.unfold_more_rounded,
                  color: Colors.blue,
                  badgeText: "Prêt",
                  badgeColor: Colors.green,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ConfigEssaiScreen(typeEssai: "traction"),
                      ),
                    );
                    setState(() {});
                  },
                ),
                _buildActionCard(
                  context,
                  title: "Éditeur No-Code",
                  subtitle: "Créer / Éditer un protocole personnalisée",
                  icon: Icons.post_add_rounded,
                  color: Colors.indigo,
                  badgeText: "Conception",
                  badgeColor: Colors.indigo.shade300,
                  onTap: () async {
                    await Navigator.pushNamed(context, '/editeur-protocole');
                    _chargerProtocolesLocaux(); // Recharge à la fermeture
                  },
                ),
                _buildActionCard(
                  context,
                  title: "Moteur d'Exécution",
                  subtitle: "Exécuter un protocole JSON sur des mesures",
                  icon: Icons.play_circle_fill_rounded,
                  color: Colors.green,
                  badgeText: "Exécution",
                  badgeColor: Colors.green.shade300,
                  onTap: () async {
                    await Navigator.pushNamed(context, '/runner-protocole');
                    _chargerProtocolesLocaux();
                  },
                ),
              ],
            ),

            const SizedBox(height: 40),

            // 2. Section Fichiers Protocoles Enregistrés
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "PROTOCOLES LOCAUX ENREGISTRÉS (.JSON)",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  "${_protocolesLocaux.length} fichier(s)",
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_chargementProtocoles)
              const Center(child: CircularProgressIndicator())
            else if (_protocolesLocaux.isEmpty)
              Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      "Aucun protocole personnalisé trouvé dans /protocoles.\nUtilisez l'Éditeur No-Code pour en enregistrer un.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              )
            else
              Card(
                elevation: 0,
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _protocolesLocaux.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFF334155)),
                  itemBuilder: (context, index) {
                    final file = _protocolesLocaux[index];
                    final fileName = p.basename(file.path);

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0F172A),
                        child: Icon(Icons.code_rounded, color: Colors.blueAccent, size: 20),
                      ),
                      title: Text(
                        fileName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                      subtitle: Text(
                        file.path,
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text("Exécuter"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          foregroundColor: Colors.blueAccent,
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/runner-protocole');
                          _chargerProtocolesLocaux();
                        },
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 40),

            // 3. Section Historique
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "LOTS EN MÉMOIRE POUR COMPARAISON",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.1,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _selectedLots.length >= 2
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CompareScreen(selectedLots: _selectedLots.toList()),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.compare_arrows),
                  label: Text("Comparer (${_selectedLots.length})"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white10,
                    disabledForegroundColor: Colors.white30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (history.isEmpty)
              Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      "Aucun lot exécuté dans la session actuelle.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              )
            else
              Card(
                elevation: 0,
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFF334155)),
                  itemBuilder: (context, index) {
                    final lot = history[index];
                    final isSelected = _selectedLots.contains(lot);

                    IconData statusIcon = Icons.check_circle_outline;
                    Color statusColor = Colors.green;
                    if (lot.statut == "non_conforme") {
                      statusIcon = Icons.error_outline;
                      statusColor = Colors.red;
                    } else if (lot.statut == "non_evalue") {
                      statusIcon = Icons.help_outline;
                      statusColor = Colors.grey;
                    }

                    return CheckboxListTile(
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
                      activeColor: Colors.blueAccent,
                      checkColor: Colors.white,
                      title: Text(
                        "Lot ${lot.materiauNom}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Norme ${lot.normeCode} • ${lot.resultatsEchantillons.length} échantillon(s) • Conformité : ${lot.statut.toUpperCase()}",
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      secondary: CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.15),
                        child: Icon(statusIcon, color: statusColor),
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
      elevation: isEnabled ? 2 : 0,
      color: isEnabled ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEnabled ? const Color(0xFF334155) : Colors.transparent,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                      color: isEnabled ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: isEnabled ? color : Colors.grey, size: 24),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
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
                      color: isEnabled ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isEnabled ? const Color(0xFF94A3B8) : Colors.grey.shade700,
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