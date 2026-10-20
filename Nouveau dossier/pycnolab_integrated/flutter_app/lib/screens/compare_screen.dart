import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Comparaison Multi-Lots"),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Titre & Descriptif
            const Text(
              "Tableau Comparatif des Lots",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Moyennes et écarts-types calculés côte à côte pour chaque grandeur mécanique.",
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),

            // 2. Tableau de comparaison
            _buildTableauComparatif(),
            const SizedBox(height: 40),

            // 3. Section Graphiques
            const Text(
              "Analyse Graphique Comparative",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Visualisation des moyennes sous forme de graphiques en barres par grandeur.",
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 24),

            // Grid ou liste de graphiques
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _buildBarChart(
                  title: "Contrainte maximale de rupture (MPa)",
                  lots: selectedLots,
                  valueSelector: (lot) => lot.resistanceMoyenneMpa,
                  barColor: const Color(0xFF3B82F6), // Blue
                ),
                _buildBarChart(
                  title: "Déformation à la rupture (%)",
                  lots: selectedLots,
                  valueSelector: (lot) => lot.deformationMoyennePourcent,
                  barColor: const Color(0xFFF97316), // Orange
                ),
                _buildBarChart(
                  title: "Module d'Young (MPa) — Données brutes",
                  lots: selectedLots,
                  valueSelector: (lot) => lot.moduleYoungMoyenMpa,
                  barColor: const Color(0xFF10B981), // Teal/Green
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
      color: const Color(0xFF1E293B),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFF0F172A)),
            columns: [
              const DataColumn(
                label: Text(
                  "Grandeur / Propriété",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              ...selectedLots.map(
                (lot) => DataColumn(
                  label: Text(
                    lot.materiauNom,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                  ),
                  ...selectedLots.map(
                    (lot) => DataCell(
                      Text(
                        _formatValueAndStd(lot.resistanceMoyenneMpa, lot.ecartTypeMpa),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                  ),
                  ...selectedLots.map(
                    (lot) => DataCell(
                      Text(
                        _formatValueAndStd(lot.deformationMoyennePourcent, lot.ecartTypeDeformationPourcent),
                        style: const TextStyle(color: Colors.white),
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
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                  ),
                  ...selectedLots.map(
                    (lot) => DataCell(
                      Text(
                        _formatValueAndStd(lot.moduleYoungMoyenMpa, lot.ecartTypeModuleYoungMpa),
                        style: const TextStyle(color: Colors.white),
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
            width: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          )
        ],
      );
    }).toList();

    return SizedBox(
      width: 450,
      height: 320,
      child: Card(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 28),
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
                                  constraints: const BoxConstraints(maxWidth: 80),
                                  child: Text(
                                    lots[idx].materiauNom,
                                    style: const TextStyle(fontSize: 10, color: Colors.white70),
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
                          reservedSize: 45,
                          getTitlesWidget: (val, meta) {
                            return Text(
                              val.toStringAsFixed(1),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9),
                            );
                          },
                        ),
                      ),
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
      ),
    );
  }
}
