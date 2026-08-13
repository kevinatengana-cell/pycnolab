// lib/screens/resultats_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ResultatsScreen extends StatefulWidget {
  final Map<String, dynamic>? donnees;

  const ResultatsScreen({Key? key, this.donnees}) : super(key: key);

  @override
  State<ResultatsScreen> createState() => _ResultatsScreenState();
}

class _ResultatsScreenState extends State<ResultatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<dynamic> _echantillons;
  late Map<String, dynamic> _stats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // CORRECTION ICI : Accepte 'echantillons' OU 'resultats_echantillons'
    _echantillons = (widget.donnees?['echantillons'] ?? widget.donnees?['resultats_echantillons']) as List<dynamic>? ?? [];
    _stats = widget.donnees?['statistiques'] as Map<String, dynamic>? ?? {};
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
            color: const Color(0xFF0F172A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Résultats de l'Essai",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Retour"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                )
              ],
            )
          ),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVueGenerale(),
                _buildTableauData(),
                _buildDetailEchantillons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1E293B),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF3B82F6),
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: const Color(0xFF3B82F6),
        tabs: const [
          Tab(icon: Icon(Icons.analytics_outlined), text: "Vue Générale & Stats"),
          Tab(icon: Icon(Icons.table_chart_outlined), text: "Tableau de Données"),
          Tab(icon: Icon(Icons.list_alt_outlined), text: "Détail par Échantillon"),
        ],
      ),
    );
  }

  Widget _buildVueGenerale() {
    if (_echantillons.isEmpty) {
      return const Center(child: Text("Aucune donnée disponible pour cet essai.", style: TextStyle(color: Colors.white)));
    }

    List<Widget> cards = [];
    final sigmaMoy = widget.donnees?['resistance_moyenne_mpa'];
    final epsilonMoy = _stats['epsilon_moyen'];
    final youngMoy = widget.donnees?['module_young_moyen_mpa'];
    final energieMoy = widget.donnees?['energie_rupture_moyenne_joules'];
    final limiteMoy = widget.donnees?['limite_elastique_moyenne_mpa'];

    if (sigmaMoy != null) cards.add(_buildStatCard("Moyenne Contrainte", "${_parseDouble(sigmaMoy).toStringAsFixed(2)} MPa", const Color(0xFF3B82F6)));
    if (epsilonMoy != null && _parseDouble(epsilonMoy) > 0) cards.add(_buildStatCard("Déformation Moyenne", "${_parseDouble(epsilonMoy).toStringAsFixed(2)} %", Colors.orange));
    if (youngMoy != null) cards.add(_buildStatCard("Module d'Young", "${_parseDouble(youngMoy).toStringAsFixed(2)} MPa", Colors.greenAccent));
    if (energieMoy != null) cards.add(_buildStatCard("Énergie à rupture", "${_parseDouble(energieMoy).toStringAsFixed(2)} J", Colors.purpleAccent));
    if (limiteMoy != null) cards.add(_buildStatCard("Limite Élastique", "${_parseDouble(limiteMoy).toStringAsFixed(2)} MPa", Colors.redAccent));
    
    cards.add(_buildStatCard("Total Échantillons", "${_echantillons.length}", const Color(0xFF06B6D4)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: cards,
          ),
          const SizedBox(height: 32),
          _buildGraphiqueContraintes(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGraphiqueContraintes() {
    final double maxVal = _echantillons
        .map((e) => _parseDouble(e['contrainte_rupture_mpa']))
        .fold(0.0, (prev, curr) => curr > prev ? curr : prev);

    return Card(
      color: const Color(0xFF1E293B),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Comparatif des Contraintes de Rupture (MPa)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 32),
            SizedBox(
              height: 280,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal > 0 ? maxVal * 1.2 : 10,
                  barGroups: _echantillons.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ech = entry.value;
                    final val = _parseDouble(ech['contrainte_rupture_mpa']);
                    return BarChartGroupData(
                      x: index,
                      barRods: [BarChartRodData(toY: val, color: const Color(0xFF3B82F6), width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < _echantillons.length) {
                            return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(_echantillons[idx]['identifiant'] ?? 'Ech ${idx + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(color: Color(0xFF94A3B8))))),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableauData() {
    if (_echantillons.isEmpty) return const Center(child: Text("Aucune donnée à afficher.", style: TextStyle(color: Colors.white)));

    // Determiner dynamiquement les colonnes basées sur le premier echantillon
    final firstEch = _echantillons.first as Map<String, dynamic>;
    
    List<DataColumn> cols = [const DataColumn(label: Text("Identifiant", style: TextStyle(color: Colors.white)))] ;
    if (firstEch.containsKey("largeur_mm") || firstEch.containsKey("diametres_mm")) {
        cols.add(const DataColumn(label: Text("Section (mm²)", style: TextStyle(color: Colors.white))));
    }
    cols.add(const DataColumn(label: Text("Force Max (N)", style: TextStyle(color: Colors.white))));
    cols.add(const DataColumn(label: Text("Contrainte (MPa)", style: TextStyle(color: Colors.white))));
    if (firstEch['module_young_mpa'] != null) cols.add(const DataColumn(label: Text("Module (MPa)", style: TextStyle(color: Colors.white))));
    if (firstEch['energie_rupture_joules'] != null) cols.add(const DataColumn(label: Text("Énergie (J)", style: TextStyle(color: Colors.white))));
    if (firstEch['limite_elastique_mpa'] != null) cols.add(const DataColumn(label: Text("Limite Élas. (MPa)", style: TextStyle(color: Colors.white))));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            columns: cols,
            rows: _echantillons.map((ech) {
              List<DataCell> cells = [DataCell(Text(ech['identifiant']?.toString() ?? '-', style: const TextStyle(color: Colors.white)))];
              if (ech.containsKey("largeur_mm") || ech.containsKey("diametres_mm")) {
                double section = _parseDouble(ech['section_mm2']);
                cells.add(DataCell(Text(section > 0 ? section.toStringAsFixed(2) : "-", style: const TextStyle(color: Colors.white))));
              }
              cells.add(DataCell(Text(_parseDouble(ech['force_rupture_newton']).toStringAsFixed(2), style: const TextStyle(color: Colors.white))));
              cells.add(DataCell(Text(_parseDouble(ech['contrainte_rupture_mpa']).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)))));
              if (firstEch['module_young_mpa'] != null) {
                cells.add(DataCell(Text(ech['module_young_mpa'] != null ? _parseDouble(ech['module_young_mpa']).toStringAsFixed(2) : "-", style: const TextStyle(color: Colors.white))));
              }
              if (firstEch['energie_rupture_joules'] != null) {
                cells.add(DataCell(Text(ech['energie_rupture_joules'] != null ? _parseDouble(ech['energie_rupture_joules']).toStringAsFixed(2) : "-", style: const TextStyle(color: Colors.white))));
              }
              if (firstEch['limite_elastique_mpa'] != null) {
                cells.add(DataCell(Text(ech['limite_elastique_mpa'] != null ? _parseDouble(ech['limite_elastique_mpa']).toStringAsFixed(2) : "-", style: const TextStyle(color: Colors.white))));
              }
              return DataRow(cells: cells);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailEchantillons() {
    if (_echantillons.isEmpty) return const Center(child: Text("Aucun échantillon renseigné.", style: TextStyle(color: Colors.white)));

    return ListView.builder(
      padding: const EdgeInsets.all(24.0),
      itemCount: _echantillons.length,
      itemBuilder: (context, index) {
        final ech = _echantillons[index];
        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: const Color(0xFF3B82F6).withOpacity(0.2), child: Text("${index + 1}", style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold))),
                  title: Text(ech['identifiant'] ?? 'Échantillon #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text("Contrainte: ${_parseDouble(ech['contrainte_rupture_mpa']).toStringAsFixed(2)} MPa", style: const TextStyle(color: Color(0xFF94A3B8))),
                ),
                const Divider(height: 32, color: Color(0xFF334155)),
                _buildCourbeTraction(ech, height: 250),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCourbeTraction(Map<String, dynamic> ech, {double height = 250}) {
    final List<dynamic> pointsDyn = ech['points_courbe'] as List<dynamic>? ?? [];
    if (pointsDyn.isEmpty) return const Center(child: Text("Aucune courbe détaillée n'est disponible pour cet échantillon.", style: TextStyle(color: Color(0xFF94A3B8))));

    List<FlSpot> spots = [];
    double maxX = 0;
    double maxY = 0;
    
    for (var p in pointsDyn) {
      double f = _parseDouble(p['force_newton']);
      double d = _parseDouble(p['deplacement_mm']);
      spots.add(FlSpot(d, f));
      if (d > maxX) maxX = d;
      if (f > maxY) maxY = f;
    }

    if (spots.length < 2) return const Center(child: Text("Points de courbe insuffisants.", style: TextStyle(color: Color(0xFF94A3B8))));

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          minY: 0,
          maxX: maxX > 0 ? maxX * 1.05 : 10,
          maxY: maxY > 0 ? maxY * 1.1 : 100,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text("Déplacement (mm)", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ),
              sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (val, meta) => Text(val.toStringAsFixed(1), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10))),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text("Force (N)", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              sideTitles: SideTitles(showTitles: true, reservedSize: 55, getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10))),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1), getDrawingVerticalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: const Color(0xFF06B6D4), // Cyan
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF06B6D4).withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
