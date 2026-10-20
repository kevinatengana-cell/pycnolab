import 'package:flutter/material.dart';

import '../models/gamme_request.dart';
import 'import_screen.dart';

class ConfigEssaiScreen extends StatefulWidget {
  final String typeEssai;

  const ConfigEssaiScreen({super.key, this.typeEssai = "traction"});

  @override
  State<ConfigEssaiScreen> createState() => _ConfigEssaiScreenState();
}

class _ConfigEssaiScreenState extends State<ConfigEssaiScreen> {
  late String _selectedNorm;

  // Liste de tous les calculs possibles
  final List<Map<String, dynamic>> _calculsDisponibles = [
    {
      "id": "contrainte_rupture",
      "nom": "Contrainte à la rupture (MPa)",
      "desc": "Contrainte maximale supportée avant rupture."
    },
    {
      "id": "deformation_rupture",
      "nom": "Déformation à la rupture (%)",
      "desc": "Allongement relatif maximal mesuré."
    },
    {
      "id": "module_young",
      "nom": "Module d'Young (MPa)",
      "desc": "Pente de la zone élastique de la courbe."
    },
    {
      "id": "energie_rupture",
      "nom": "Énergie à la rupture (J)",
      "desc": "Aire sous la courbe force-déplacement."
    },
    {
      "id": "limite_elastique",
      "nom": "Limite Élastique (MPa)",
      "desc": "Contrainte de fin de proportionnalité."
    },
  ];

  // État des calculs : true s'ils sont cochés
  final Map<String, bool> _calculsCoches = {};

  // Normes disponibles PAR TYPE D'ESSAI
  static const Map<String, Map<String, List<String>>> _normesParEssai = {
    "traction": {
      "ISO 527": ["contrainte_rupture", "deformation_rupture", "module_young"],
      "ASTM D638": ["contrainte_rupture", "deformation_rupture", "module_young"],
      "Mode Libre": [],
    },
    "compression": {
      "ISO 604": ["contrainte_rupture", "deformation_rupture", "module_young"],
      "ASTM D695": ["contrainte_rupture", "deformation_rupture", "module_young"],
      "Mode Libre": [],
    },
    "flexion": {
      "ISO 178": ["contrainte_rupture", "deformation_rupture", "module_young"],
      "ASTM D790": ["contrainte_rupture", "deformation_rupture", "module_young"],
      "Mode Libre": [],
    },
  };

  Map<String, List<String>> get _normesConfig =>
      _normesParEssai[widget.typeEssai] ?? _normesParEssai["traction"]!;

  static const Map<String, String> _titresParEssai = {
    "traction": "l'Essai de Traction",
    "compression": "l'Essai de Compression",
    "flexion": "l'Essai de Flexion",
  };

  String get _titreEssai => _titresParEssai[widget.typeEssai] ?? _titresParEssai["traction"]!;

  @override
  void initState() {
    super.initState();
    _selectedNorm = _normesConfig.keys.first;
    _appliquerNorme(_selectedNorm);
  }

  void _appliquerNorme(String norme) {
    setState(() {
      _selectedNorm = norme;
      final obligatoires = _normesConfig[norme] ?? [];
      
      for (var calc in _calculsDisponibles) {
        final id = calc["id"] as String;
        if (obligatoires.contains(id)) {
          _calculsCoches[id] = true;
        } else {
          _calculsCoches[id] = _calculsCoches[id] ?? false;
        }
      }
    });
  }

  bool _estObligatoire(String calculId) {
    return (_normesConfig[_selectedNorm] ?? []).contains(calculId);
  }

  void _allerAImport() {
    final calculsDemandes = _calculsCoches.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

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
        builder: (context) => ImportScreen(configInitiale: configInitiale, typeEssai: widget.typeEssai),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          'Configuration de $_titreEssai',
          style: const TextStyle(
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
      ),
      body: Row(
        children: [
          // PANNEAU GAUCHE : Sélection de la norme
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                children: [
                  const Text(
                    "PROTOCOLE D'ESSAI",
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      fontSize: 12,
                    ),
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
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Les calculs obligatoires pour la norme $_selectedNorm sont automatiquement activés.",
                    style: const TextStyle(color: Color(0xFF5F6368), fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  
                  // Liste des toggles
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

                  const SizedBox(height: 16),

                  // Bouton Suivant
                  Align(
                    alignment: Alignment.bottomRight,
                    child: FilledButton.icon(
                      onPressed: _allerAImport,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text("Passer à l'importation"),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFFE5E7EB),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                norme == "Mode Libre" ? Icons.tune_rounded : Icons.verified_rounded,
                color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFF9CA3AF),
                size: 20,
              ),
              const SizedBox(width: 14),
              Text(
                norme,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFF374151),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isChecked ? const Color(0xFFA5D6A7) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          calc["nom"],
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          calc["desc"],
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
        value: isChecked,
        activeColor: const Color(0xFF1B5E20),
        onChanged: isObligatoire
            ? null
            : (bool value) {
                setState(() {
                  _calculsCoches[id] = value;
                });
              },
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isObligatoire
                ? const Color(0xFFF3F4F6)
                : (isChecked ? const Color(0xFFE8F5E9) : const Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isObligatoire ? Icons.lock_outline_rounded : Icons.analytics_outlined,
            color: isObligatoire
                ? const Color(0xFF9CA3AF)
                : (isChecked ? const Color(0xFF1B5E20) : const Color(0xFF9CA3AF)),
            size: 20,
          ),
        ),
      ),
    );
  }
}