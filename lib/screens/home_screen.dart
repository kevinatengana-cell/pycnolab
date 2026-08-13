import 'package:flutter/material.dart';
import 'config_essai_screen.dart';
import 'compare_screen.dart';
import '../services/history_service.dart';
import '../models/resultat_gamme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<ResultatGamme> _selectedLots = {};

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
      backgroundColor: const Color(0xFF0F172A), // Slate-900 (Dark Mode)
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
        backgroundColor: const Color(0xFF0F172A), // Slate-900
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Navigation vers les paramètres si besoin
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Message de bienvenue & statut
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

            // 2. Section "Lancer un Essai" (Cartes d'action principales)
            const Text(
              "ESSAIS MÉCANIQUES",
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
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.6,
              children: [
                // Carte 1 : Essai de Traction (Actif)
                _buildActionCard(
                  context,
                  title: "Essai de Traction",
                  subtitle: "ISO 527 / ASTM D638\nImport Excel & Calculs auto",
                  icon: Icons.unfold_more_rounded,
                  color: Colors.blue,
                  badgeText: "Prêt",
                  badgeColor: Colors.green,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ConfigEssaiScreen()),
                    );
                    setState(() {});
                  },
                ),

                // Carte 2 : Créateur de Protocole (No-Code V2)
                _buildActionCard(
                  context,
                  title: "Nouveau Protocole (No-Code)",
                  subtitle: "Configurer des formules & seuils personnalisés",
                  icon: Icons.post_add_rounded,
                  color: Colors.indigo,
                  badgeText: "Laborantin",
                  badgeColor: Colors.indigo.shade300,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Module de création No-Code en cours d'intégration..."),
                      ),
                    );
                  },
                ),

                // Carte 3 : Flexion 3 Points (Futur plugin)
                _buildActionCard(
                  context,
                  title: "Flexion 3 Points",
                  subtitle: "ISO 178 / ASTM D790\nCalcul de contrainte & flèche",
                  icon: Icons.architecture,
                  color: Colors.amber.shade800,
                  badgeText: "Prochainement",
                  badgeColor: Colors.grey,
                  onTap: null, // Inactif pour l'instant
                ),

                // Carte 4 : Compression (Futur plugin)
                _buildActionCard(
                  context,
                  title: "Essai de Compression",
                  subtitle: "ISO 604 / ASTM D695\nComportement en charge",
                  icon: Icons.compress_rounded,
                  color: Colors.teal,
                  badgeText: "Prochainement",
                  badgeColor: Colors.grey,
                  onTap: null,
                ),
              ],
            ),

            const SizedBox(height: 40),

            // 3. Section Historique / Activité récente (dynamique)
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
                  label: Text("Comparer les lots (${_selectedLots.length})"),
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
              const Card(
                color: Color(0xFF1E293B),
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      "Aucun lot importé pour le moment.\nConfigurez un essai et importez un fichier Excel pour commencer.",
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
                        "Traction - Lot ${lot.materiauNom}",
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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isEnabled ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: isEnabled ? color : Colors.grey, size: 28),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
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
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isEnabled ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                    ),
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