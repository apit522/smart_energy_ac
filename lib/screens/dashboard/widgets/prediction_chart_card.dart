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
  final PredictionService _predictionService = PredictionService();
  late Future<List<DailyPredictionPoint>> _predictionFuture;

  @override
  void initState() {
    super.initState();
    _fetchPrediction();
  }

  @override
  void didUpdateWidget(covariant PredictionChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.deviceId != oldWidget.deviceId) {
      _fetchPrediction();
    }
  }

  void _fetchPrediction() {
    setState(() {
      _predictionFuture = _predictionService.get7DayPrediction(widget.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Prediksi Konsumsi 7 Hari ke Depan (kWh per Hari)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<DailyPredictionPoint>>(
                  future: _predictionFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('Tidak ada data prediksi.'),
                      );
                    }

                    final predictionData = snapshot.data!;

                    final spots = predictionData.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.predictedKwh,
                      );
                    }).toList();

                    // Cari nilai Y maksimal untuk skala grafik (dengan padding 20%)
                    double maxY = 1;
                    if (spots.isNotEmpty) {
                      maxY = spots
                          .map((e) => e.y)
                          .reduce((a, b) => a > b ? a : b);
                      if (maxY == 0) {
                        maxY = 1;
                      } else {
                        maxY = maxY + (maxY * 0.2);
                      }
                    }

                    return LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        minX: 0,
                        maxX: 6,
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
                                final index = value.toInt();
                                if (index >= 0 &&
                                    index < predictionData.length) {
                                  final date = predictionData[index].date;
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
                                }
                                return const Text('');
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
                                final pointData = predictionData[index];
                                final dateText = DateFormat(
                                  'EEEE, d MMM',
                                ).format(pointData.date);
                                final kwhText = pointData.predictedKwh
                                    .toStringAsFixed(3);

                                return LineTooltipItem(
                                  '$dateText\n',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '$kwhText kWh',
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
