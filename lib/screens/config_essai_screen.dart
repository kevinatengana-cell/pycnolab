import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/gamme_request.dart';
import 'import_screen.dart';

class ConfigEssaiScreen extends StatefulWidget {
  const ConfigEssaiScreen({super.key});

  @override
  State<ConfigEssaiScreen> createState() => _ConfigEssaiScreenState();
}

class _ConfigEssaiScreenState extends State<ConfigEssaiScreen> {
  String _selectedNorm = "ISO 527"; // Par défaut

  // Liste de tous les calculs possibles
  final List<Map<String, dynamic>> _calculsDisponibles = [
    {"id": "contrainte_rupture", "nom": "Contrainte à la rupture (MPa)", "desc": "Contrainte maximale supportée avant rupture."},
    {"id": "deformation_rupture", "nom": "Déformation à la rupture (%)", "desc": "Allongement relatif maximal mesuré."},
    {"id": "module_young", "nom": "Module d'Young (MPa)", "desc": "Pente de la zone élastique de la courbe."},
    {"id": "energie_rupture", "nom": "Énergie à la rupture (J)", "desc": "Aire sous la courbe force-déplacement."},
    {"id": "limite_elastique", "nom": "Limite Élastique (MPa)", "desc": "Contrainte de fin de proportionnalité."},
  ];

  // État des calculs : true s'ils sont cochés
  final Map<String, bool> _calculsCoches = {};

  // Définition des normes et de leurs calculs obligatoires
  final Map<String, List<String>> _normesConfig = {
    "ISO 527": ["contrainte_rupture", "deformation_rupture", "module_young"],
    "ASTM D638": ["contrainte_rupture", "deformation_rupture", "module_young"],
    "Mode Libre": [], // Aucun obligatoire
  };

  @override
  void initState() {
    super.initState();
    _appliquerNorme(_selectedNorm);
  }

  void _appliquerNorme(String norme) {
    setState(() {
      _selectedNorm = norme;
      final obligatoires = _normesConfig[norme] ?? [];
      
      // On coche automatiquement les obligatoires
      for (var calc in _calculsDisponibles) {
        final id = calc["id"] as String;
        if (obligatoires.contains(id)) {
          _calculsCoches[id] = true;
        } else {
          // On garde l'état précédent pour les optionnels s'ils existent, sinon false
          _calculsCoches[id] = _calculsCoches[id] ?? false;
        }
      }
    });
  }

  bool _estObligatoire(String calculId) {
    return (_normesConfig[_selectedNorm] ?? []).contains(calculId);
  }

  void _allerAImport() {
    // Récupérer la liste des IDs cochés
    final calculsDemandes = _calculsCoches.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    // Créer la configuration de base de la gamme
    final configInitiale = GammeRequest(
      materiau: MateriauRequest(nomUsage: "À définir", codeInterne: "TEMP", famille: "autre"),
      norme: NormeRequest(code: _selectedNorm, designation: _selectedNorm),
      conditions: ConditionsRequest(),
      echantillons: [],
      calculsDemandes: calculsDemandes,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportScreen(configInitiale: configInitiale),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate-900
      appBar: AppBar(
        title: const Text('Configuration de l\'Essai de Traction'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // PANNEAU GAUCHE : Sélection de la norme
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    "PROTOCOLE",
                    style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 16),
                  ..._normesConfig.keys.map((norme) => _buildNormeTile(norme)).toList(),
                ],
              ),
            ),
          ),
          
          // PANNEAU DROIT : Calculs à effectuer
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Calculs à effectuer",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Les calculs obligatoires pour la norme $_selectedNorm sont verrouillés.",
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  
                  // Liste des toggles (Effet Glassmorphism)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _calculsDisponibles.length,
                      itemBuilder: (context, index) {
                        final calc = _calculsDisponibles[index];
                        final id = calc["id"] as String;
                        final isObligatoire = _estObligatoire(id);
                        final isChecked = _calculsCoches[id] ?? false;

                        return _buildCalculTile(calc, isChecked, isObligatoire, id);
                      },
                    ),
                  ),

                  // Bouton Suivant
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton.icon(
                      onPressed: _allerAImport,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("Passer à l'importation"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormeTile(String norme) {
    final isSelected = _selectedNorm == norme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => _appliquerNorme(norme),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                norme == "Mode Libre" ? Icons.settings_suggest : Icons.verified,
                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 16),
              Text(
                norme,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculTile(Map<String, dynamic> calc, bool isChecked, bool isObligatoire, String id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isChecked ? const Color(0xFF3B82F6).withOpacity(0.5) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SwitchListTile(
              title: Text(
                calc["nom"],
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                calc["desc"],
                style: const TextStyle(color: Color(0xFF94A3B8)),
              ),
              value: isChecked,
              activeColor: const Color(0xFF3B82F6),
              onChanged: isObligatoire ? null : (bool value) {
                setState(() {
                  _calculsCoches[id] = value;
                });
              },
              secondary: Icon(
                isObligatoire ? Icons.lock : Icons.analytics_outlined,
                color: isObligatoire ? const Color(0xFF64748B) : (isChecked ? const Color(0xFF3B82F6) : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
