import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/resultat_gamme.dart';

class CompareScreen extends StatelessWidget {
  final List<ResultatGamme> selectedLots;

  const CompareScreen({Key? key, required this.selectedLots}) : super(key: key);

  String _formatValueAndStd(double? value, double? std) {
    if (value == null) return "N/A";
    final valStr = value.toStringAsFixed(2);
    final stdStr = std != null ? std.toStringAsFixed(2) : "0.00";
    return "$valStr ± $stdStr";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text(
          "Comparaison Multi-Lots",
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Titre & Descriptif
            const Text(
              "Tableau Comparatif des Lots",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Moyennes et écarts-types calculés côte à côte pour chaque grandeur mécanique.",
              style: TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
            ),
            const SizedBox(height: 20),

            // 2. Tableau de comparaison
            _buildTableauComparatif(),
            const SizedBox(height: 36),

            // 3. Section Graphiques
            const Text(
              "Analyse Graphique Comparative",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Visualisation des moyennes sous forme de graphiques en barres par grandeur.",
              style: TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
            ),
            const SizedBox(height: 20),

            // Grid / Wrap de graphiques
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _buildBarChart(
                  title: "Contrainte maximale de rupture (MPa)",
                  lots: selectedLots,
                  valueSelector: (lot) => lot.resistanceMoyenneMpa,
                  barColor: const Color(0xFF1B5E20), // Vert forêt PycnoLab
                ),
                _buildBarChart(
                  title: "Déformation à la rupture (%)",
                  lots: selectedLots,
                  valueSelector: (lot) => lot.deformationMoyennePourcent,
                  barColor: const Color(0xFFD97706), // Ambre / Orange chaud
                ),
                _buildBarChart(
                  title: "Module d'Young (MPa) — Données brutes",
                  lots: selectedLots,
                  valueSelector: (lot) => lot.moduleYoungMoyenMpa,
                  barColor: const Color(0xFF2563EB), // Bleu roi
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableauComparatif() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor:
                MaterialStateProperty.all(const Color(0xFFF3F4F6)),
            dataRowMaxHeight: 52,
            columns: [
              const DataColumn(
                label: Text(
                  "Grandeur / Propriété",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    fontSize: 13,
                  ),
                ),
              ),
              ...selectedLots.map(
                (lot) => DataColumn(
                  label: Text(
                    lot.materiauNom,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
            rows: [
              DataRow(
                cells: [
                  const DataCell(
                    Text(
                      "Contrainte de rupture (MPa)",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ...selectedLots.map(
                    (lot) => DataCell(
                      Text(
                        _formatValueAndStd(
                            lot.resistanceMoyenneMpa, lot.ecartTypeMpa),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(
                    Text(
                      "Déformation à la rupture (%)",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ...selectedLots.map(
                    (lot) => DataCell(
                      Text(
                        _formatValueAndStd(lot.deformationMoyennePourcent,
                            lot.ecartTypeDeformationPourcent),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(
                    Text(
                      "Module d'Young (MPa)",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ...selectedLots.map(
                    (lot) => DataCell(
                      Text(
                        _formatValueAndStd(lot.moduleYoungMoyenMpa,
                            lot.ecartTypeModuleYoungMpa),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 13,
                        ),
                      ),
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

  Widget _buildBarChart({
    required String title,
    required List<ResultatGamme> lots,
    required double? Function(ResultatGamme) valueSelector,
    required Color barColor,
  }) {
    double maxVal = 0.0;
    for (var lot in lots) {
      final val = valueSelector(lot);
      if (val != null && val > maxVal) {
        maxVal = val;
      }
    }

    final barGroups = lots.asMap().entries.map((entry) {
      final index = entry.key;
      final lot = entry.value;
      final val = valueSelector(lot) ?? 0.0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: val,
            color: barColor,
            width: 22,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          )
        ],
      );
    }).toList();

    return SizedBox(
      width: 440,
      height: 310,
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxVal > 0 ? maxVal * 1.2 : 10,
                    barGroups: barGroups,
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < lots.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 80),
                                  child: Text(
                                    lots[idx].materiauNom,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF4B5563),
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (val, meta) {
                            return Text(
                              val.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => const FlLine(
                        color: Color(0xFFF3F4F6),
                        strokeWidth: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}