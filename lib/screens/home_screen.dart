import 'package:flutter/material.dart';
import 'config_essai_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ConfigEssaiScreen()),
                    );
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

            // 3. Section Historique / Activité récente
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "RÉCENTS RAPPORT S SÉLECTIONNÉS",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.1,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text("Voir tout l'historique"),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 0,
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Icon(Icons.check_circle_outline, color: Colors.green),
                    ),
                    title: Text("Traction - Gamme TEXTILE_BATCH_04", style: TextStyle(color: Colors.white)),
                    subtitle: Text("Norme ISO 527 • 5 échantillon(s) • Conformité : CONFORME", style: TextStyle(color: Colors.grey)),
                    trailing: Text("Aujourd'hui, 14:32", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                  Divider(height: 1, color: Color(0xFF334155)),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFFFEE2E2),
                      child: Icon(Icons.error_outline, color: Colors.red),
                    ),
                    title: Text("Traction - Gamme COMPOSITE_C_12", style: TextStyle(color: Colors.white)),
                    subtitle: Text("Norme ISO 527 • 3 échantillon(s) • Conformité : NON CONFORME", style: TextStyle(color: Colors.grey)),
                    trailing: Text("Hier, 09:15", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],
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