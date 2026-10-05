import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/resultat_gamme.dart';

const Map<String, String> _libellesEssai = {
  'traction': 'Traction',
  'compression': 'Compression',
  'flexion': 'Flexion',
};

double? _num(dynamic v) => (v as num?)?.toDouble();

/// Un échantillon aplati (gamme + échantillon), pour les onglets qui
/// raisonnent tous échantillons confondus (Vue Générale, Tableau, Détail).
class _EchantillonAplati {
  final String gamme;
  final Map<String, dynamic> donnees;
  _EchantillonAplati(this.gamme, this.donnees);

  String get identifiant => (donnees['identifiant'] as String?) ?? 'Inconnu';
  double? get contMax => _num(donnees['contrainte_rupture_mpa']);
  double? get defRupt => _num(donnees['deformation_rupture_pourcent']);
  double? get young => _num(donnees['module_young_mpa']);
  double? get energie => _num(donnees['energie_rupture_joule']);
  double? get limiteElastique => _num(donnees['limite_elastique_mpa']);
  List<Map<String, dynamic>> get pointsCourbe =>
      ((donnees['points_courbe'] as List?) ?? const [])
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
}

/// Convertit la réponse multi-gammes du moteur Python en ResultatGamme
/// (un par gamme), pour alimenter HistoryService : tableau de bord et
/// comparaison multi-lots. La déformation est stockée en fraction côté
/// moteur (comme le fichier de référence) : convertie en % ici, puisque
/// les écrans d'historique/comparaison l'affichent en %.
List<ResultatGamme> resultatsVersHistorique(
  Map<String, dynamic> donnees,
  String typeEssai,
) {
  final gammes = (donnees['gammes'] as List?) ?? const [];
  final libelle = _libellesEssai[typeEssai] ?? typeEssai;
  return gammes.map<ResultatGamme>((raw) {
    final g = Map<String, dynamic>.from(raw as Map);
    final echantillons = ((g['echantillons'] as List?) ?? const [])
        .map<ResultatEchantillon>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return ResultatEchantillon(
        identifiant: (m['identifiant'] as String?) ?? 'Inconnu',
        contrainteRuptureMpa: _num(m['contrainte_rupture_mpa']) ?? 0.0,
        deformationRupturePourcent:
            (_num(m['deformation_rupture_pourcent']) ?? 0.0) * 100,
        moduleYoungMpa: _num(m['module_young_mpa']),
        energieRuptureJoule: _num(m['energie_rupture_joule']),
        limiteElastiqueMpa: _num(m['limite_elastique_mpa']),
      );
    }).toList();
    final defMoy = _num(g['deformation_moyenne_pourcent']);
    final defStd = _num(g['ecart_type_deformation_pourcent']);
    return ResultatGamme(
      materiauNom: ((g['nom_gamme'] as String?) ?? 'Gamme').trim(),
      normeCode: 'Essai de $libelle',
      horodatage: DateTime.now(),
      resultatsEchantillons: echantillons,
      resistanceMoyenneMpa: _num(g['resistance_moyenne_mpa']) ?? 0.0,
      ecartTypeMpa: _num(g['ecart_type_mpa']) ?? 0.0,
      moduleYoungMoyenMpa: _num(g['module_young_moyen_mpa']),
      statut: 'non_evalue',
      deformationMoyennePourcent: defMoy == null ? null : defMoy * 100,
      ecartTypeDeformationPourcent: defStd == null ? null : defStd * 100,
      ecartTypeModuleYoungMpa: _num(g['ecart_type_module_young_mpa']),
    );
  }).toList();
}

/// Résultats d'un essai (traction / compression / flexion), à 3 onglets :
/// Vue Générale & Stats (indicateurs + comparatif tous échantillons),
/// Tableau de Données (détail à plat), Détail par Échantillon (courbe
/// Force/Déplacement de chaque éprouvette). L'export Excel est délégué à
/// `onExporter`, fourni par l'écran de saisie des dimensions (qui détient
/// déjà la géométrie).
class ResultatsScreen extends StatefulWidget {
  final Map<String, dynamic> donnees;
  final String typeEssai;
  final Future<void> Function()? onExporter;

  const ResultatsScreen({
    super.key,
    required this.donnees,
    this.typeEssai = 'traction',
    this.onExporter,
  });

  @override
  State<ResultatsScreen> createState() => _ResultatsScreenState();
}

enum _TypeGraphique { barres, courbes, aires }

class _ResultatsScreenState extends State<ResultatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isExporting = false;
  _TypeGraphique _typeGraphique = _TypeGraphique.barres;
  String? _gammeFiltre; // null = toutes les gammes

  late final List<_EchantillonAplati> _echantillons = () {
    final gammes = (widget.donnees['gammes'] as List?) ?? const [];
    final liste = <_EchantillonAplati>[];
    for (final raw in gammes) {
      final g = Map<String, dynamic>.from(raw as Map);
      final nomGamme = ((g['nom_gamme'] as String?) ?? 'Gamme').trim();
      for (final e in (g['echantillons'] as List? ?? const [])) {
        liste.add(_EchantillonAplati(nomGamme, Map<String, dynamic>.from(e as Map)));
      }
    }
    return liste;
  }();

  List<String> get _nomsGammes =>
      _echantillons.map((e) => e.gamme).toSet().toList();

  List<_EchantillonAplati> get _echantillonsAffiches => _gammeFiltre == null
      ? _echantillons
      : _echantillons.where((e) => e.gamme == _gammeFiltre).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double? _moyenne(Iterable<double?> valeurs) {
    final v = valeurs.whereType<double>().toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  String _fmt(double? v, {int digits = 2}) => v == null ? '-' : v.toStringAsFixed(digits);

  Future<void> _exporter() async {
    final export = widget.onExporter;
    if (export == null) return;
    setState(() => _isExporting = true);
    try {
      await export();
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libelle = _libellesEssai[widget.typeEssai] ?? widget.typeEssai;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF374151)),
        shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        title: Text(
          'Résultats — Essai de $libelle',
          style: const TextStyle(color: Color(0xFF1B5E20), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (widget.onExporter != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: FilledButton.icon(
                onPressed: _isExporting ? null : _exporter,
                icon: _isExporting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.table_view_rounded, size: 18),
                label: Text(_isExporting ? 'Export...' : 'Exporter (.xlsx)'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1B5E20),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF1B5E20),
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart_rounded, size: 20), text: 'Vue Générale & Stats'),
            Tab(icon: Icon(Icons.table_chart_rounded, size: 20), text: 'Tableau de Données'),
            Tab(icon: Icon(Icons.view_list_rounded, size: 20), text: 'Détail par Échantillon'),
          ],
        ),
      ),
      body: _echantillons.isEmpty
          ? const Center(child: Text('Aucun résultat exploitable.', style: TextStyle(color: Color(0xFF6B7280))))
          : Column(
              children: [
                _buildBarreFiltreGamme(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVueGenerale(),
                      _buildTableauDonnees(),
                      _buildDetailParEchantillon(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBarreFiltreGamme() {
    final gammes = _nomsGammes;
    if (gammes.length <= 1) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          const Text('Gamme :', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(width: 10),
          DropdownButton<String?>(
            value: _gammeFiltre,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Toutes les gammes')),
              ...gammes.map((g) => DropdownMenuItem<String?>(value: g, child: Text(g))),
            ],
            onChanged: (valeur) => setState(() => _gammeFiltre = valeur),
          ),
        ],
      ),
    );
  }

  // --- Onglet 1 : Vue Générale & Stats ---

  Widget _buildVueGenerale() {
    final echantillons = _echantillonsAffiches;
    final moyCont = _moyenne(echantillons.map((e) => e.contMax));
    final moyDef = _moyenne(echantillons.map((e) => e.defRupt));
    final moyYoung = _moyenne(echantillons.map((e) => e.young));
    final moyEnergie = _moyenne(echantillons.map((e) => e.energie));
    final moyLimite = _moyenne(echantillons.map((e) => e.limiteElastique));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildKpiCard('Moyenne Contrainte', '${_fmt(moyCont)} MPa', Icons.speed_rounded, const Color(0xFFE8F5E9), const Color(0xFF1B5E20)),
              _buildKpiCard('Déformation Moyenne', '${_fmt((moyDef ?? 0) * 100)} %', Icons.show_chart_rounded, const Color(0xFFF3F4F6), const Color(0xFF374151)),
              _buildKpiCard("Module d'Young", '${_fmt(moyYoung)} MPa', Icons.architecture_rounded, const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
              _buildKpiCard('Énergie à rupture', '${_fmt(moyEnergie, digits: 4)} J', Icons.bolt_rounded, const Color(0xFFFCE7F3), const Color(0xFFBE185D)),
              _buildKpiCard('Limite Élastique', '${_fmt(moyLimite)} MPa', Icons.straighten_rounded, const Color(0xFFFFF3E0), const Color(0xFFE65100)),
              _buildKpiCard('Total Échantillons', '${echantillons.length}', Icons.science_rounded, const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Comparatif des Contraintes de Rupture (MPa)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
              SegmentedButton<_TypeGraphique>(
                segments: const [
                  ButtonSegment(value: _TypeGraphique.barres, icon: Icon(Icons.bar_chart_rounded, size: 16), label: Text('Barres')),
                  ButtonSegment(value: _TypeGraphique.courbes, icon: Icon(Icons.show_chart_rounded, size: 16), label: Text('Courbe')),
                  ButtonSegment(value: _TypeGraphique.aires, icon: Icon(Icons.area_chart_rounded, size: 16), label: Text('Aire')),
                ],
                selected: {_typeGraphique},
                onSelectionChanged: (s) => setState(() => _typeGraphique = s.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 320,
            padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: switch (_typeGraphique) {
              _TypeGraphique.barres => _buildBarChartComparatif(echantillons),
              _TypeGraphique.courbes => _buildLineChartComparatif(echantillons, aire: false),
              _TypeGraphique.aires => _buildLineChartComparatif(echantillons, aire: true),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String titre, String valeur, IconData icone, Color fond, Color texte) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(10)),
            child: Icon(icone, color: texte, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(valeur, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartComparatif(List<_EchantillonAplati> echantillons) {
    final barres = echantillons.asMap().entries.map((entry) {
      final v = entry.value.contMax ?? 0.0;
      return BarChartGroupData(x: entry.key, barRods: [
        BarChartRodData(toY: v, color: const Color(0xFF1B5E20), width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
      ]);
    }).toList();
    final maxY = echantillons.map((e) => e.contMax ?? 0.0).fold(0.0, (a, b) => a > b ? a : b);

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY > 0 ? maxY * 1.2 : 10,
      barGroups: barres,
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(color: Color(0xFFF3F4F6), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44,
          getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 56,
          getTitlesWidget: (v, m) {
            final i = v.toInt();
            if (i < 0 || i >= echantillons.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Transform.rotate(
                angle: -0.7,
                child: Text('${echantillons[i].gamme} ${echantillons[i].identifiant}',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
              ),
            );
          })),
      ),
    ));
  }

  Widget _buildLineChartComparatif(List<_EchantillonAplati> echantillons, {required bool aire}) {
    final spots = echantillons.asMap().entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.contMax ?? 0.0))
        .toList();
    final maxY = echantillons.map((e) => e.contMax ?? 0.0).fold(0.0, (a, b) => a > b ? a : b);

    return LineChart(LineChartData(
      minX: 0, maxX: (echantillons.length - 1).clamp(0, double.infinity).toDouble(),
      minY: 0, maxY: maxY > 0 ? maxY * 1.2 : 10,
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(color: Color(0xFFF3F4F6), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44,
          getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 56,
          getTitlesWidget: (v, m) {
            final i = v.toInt();
            if (i < 0 || i >= echantillons.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Transform.rotate(
                angle: -0.7,
                child: Text('${echantillons[i].gamme} ${echantillons[i].identifiant}',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
              ),
            );
          })),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: const Color(0xFF1B5E20),
          barWidth: 2,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: aire, color: const Color(0x331B5E20)),
        ),
      ],
    ));
  }

  // --- Onglet 2 : Tableau de Données ---

  Widget _buildTableauDonnees() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            columns: const [
              DataColumn(label: Text('Gamme', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Échantillon', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Cont(max) MPa', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Def rupt %', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('E (MPa)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Énergie (J)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Limite Élastique (MPa)', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _echantillonsAffiches.map((e) {
              return DataRow(cells: [
                DataCell(Text(e.gamme)),
                DataCell(Text(e.identifiant)),
                DataCell(Text(_fmt(e.contMax))),
                DataCell(Text(_fmt((e.defRupt ?? 0) * 100))),
                DataCell(Text(_fmt(e.young))),
                DataCell(Text(_fmt(e.energie, digits: 4))),
                DataCell(Text(_fmt(e.limiteElastique))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --- Onglet 3 : Détail par Échantillon ---

  Widget _buildDetailParEchantillon() {
    return GridView.builder(
      padding: const EdgeInsets.all(24.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: _echantillons.length,
      itemBuilder: (context, index) => _buildCarteCourbe(index),
    );
  }

  Widget _buildCarteCourbe(int index) {
    final e = _echantillons[index];
    final points = e.pointsCourbe;
    final spots = points
        .map((p) => FlSpot((_num(p['deplacement_mm']) ?? 0), (_num(p['force_newton']) ?? 0)))
        .toList();
    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);
    final maxX = spots.map((s) => s.x).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFE8F5E9),
                child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${e.gamme} — ${e.identifiant}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Contrainte : ${_fmt(e.contMax)} MPa',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Expanded(
            child: spots.isEmpty
                ? const Center(child: Text('Pas de courbe', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)))
                : LineChart(LineChartData(
                    minX: 0, maxX: maxX > 0 ? maxX : 1,
                    minY: 0, maxY: maxY > 0 ? maxY * 1.1 : 1,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                        getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF))))),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
                        getTitlesWidget: (v, m) => Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF))))),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        color: const Color(0xFF0EA5E9),
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: const Color(0x330EA5E9)),
                      ),
                    ],
                  )),
          ),
        ],
      ),
    );
  }
}
