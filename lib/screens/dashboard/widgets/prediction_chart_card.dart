// lib/screens/dashboard/widgets/prediction_chart_card.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../models/daily_prediction_point_model.dart';
import '../../../services/prediction_service.dart';

class PredictionChartCard extends StatefulWidget {
  final int deviceId;
  const PredictionChartCard({super.key, required this.deviceId});

  @override
  State<PredictionChartCard> createState() => _PredictionChartCardState();
}

class _PredictionChartCardState extends State<PredictionChartCard> {
  // Data statis dari prompt
  final List<double> ensemble = [
    1.727,
    1.130,
    1.565,
    // hanya 3 hari
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<DateTime> dates = List.generate(
      3,
      (i) => now.add(Duration(days: i + 1)),
    );

    // Buat data FlSpot untuk grafik
    final spots = List.generate(
      ensemble.length,
      (i) => FlSpot(i.toDouble(), ensemble[i]),
    );

    // Cari nilai Y maksimal untuk skala grafik (dengan padding 20%)
    double maxY = 1;
    if (spots.isNotEmpty) {
      maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      if (maxY == 0) {
        maxY = 1;
      } else {
        maxY = maxY + (maxY * 0.2);
      }
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.none,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Prediksi Konsumsi 3 Hari ke Depan (kWh per Hari)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    minX: 0,
                    maxX: 2,
                    clipData: FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      getDrawingHorizontalLine: (value) => const FlLine(
                        color: Color(0xffe7e8ec),
                        strokeWidth: 1,
                      ),
                      getDrawingVerticalLine: (value) => const FlLine(
                        color: Color(0xffe7e8ec),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.min || value == meta.max) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              value.toStringAsFixed(2),
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.left,
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value >= meta.max) {
                              return const SizedBox.shrink();
                            }
                            final date = dates[value.toInt()];
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 8.0,
                              child: Text(
                                DateFormat('E').format(date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: Colors.deepPurple,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.deepPurple.withOpacity(0.2),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) =>
                            Colors.blueGrey.withOpacity(0.8),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.spotIndex;
                            final date = dates[index];
                            return LineTooltipItem(
                              '${DateFormat('EEEE, d MMM').format(date)}\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '${ensemble[index].toStringAsFixed(3)} kWh',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.all(8),
                        tooltipMargin: 12,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
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
