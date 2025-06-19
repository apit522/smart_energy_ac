// lib/screens/dashboard/widgets/prediction_chart_card.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Import intl untuk format angka jika perlu
import '../../../models/prediction_point_model.dart';
import '../../../services/prediction_service.dart';

class PredictionChartCard extends StatefulWidget {
  final int deviceId;

  const PredictionChartCard({super.key, required this.deviceId});

  @override
  State<PredictionChartCard> createState() => _PredictionChartCardState();
}

class _PredictionChartCardState extends State<PredictionChartCard> {
  final PredictionService _predictionService = PredictionService();
  late Future<List<PredictionPoint>> _predictionFuture;

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
      _predictionFuture = _predictionService.getTomorrowPrediction(
        widget.deviceId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip
          .antiAlias, // Tambahkan ini untuk memastikan konten tetap di dalam Card
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prediksi Konsumsi Energi Besok (kWh per Jam)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 54),
            AspectRatio(
              aspectRatio: 2,
              child: FutureBuilder<List<PredictionPoint>>(
                future: _predictionFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('Tidak ada data prediksi.'),
                    );
                  }

                  final spots = snapshot.data!
                      .map((p) => FlSpot(p.hour.toDouble(), p.predictedKwh))
                      .toList();

                  return LineChart(
                    LineChartData(
                      // ========================================================
                      // PERBAIKAN 2: Beri ruang di sumbu X agar tidak terpotong
                      // ========================================================
                      minX: -0.5, // Mulai sedikit sebelum jam 0
                      maxX: 23.5, // Selesai sedikit setelah jam 23

                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                        getDrawingVerticalLine: (value) =>
                            FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (value, meta) => Text(
                              value.toStringAsFixed(2),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 3,
                            getTitlesWidget: (value, meta) {
                              // Pastikan hanya menampilkan label untuk jam yang valid (0-23)
                              if (value < 0 || value > 23)
                                return const SizedBox.shrink();
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  '${value.toInt()}:00',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: false,
                      ), // Sembunyikan border luar chart
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Colors.deepPurple,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                          ), // Tampilkan titik data agar lebih jelas
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.deepPurple.withOpacity(0.3),
                          ),
                        ),
                      ],
                      // ========================================================
                      // PERBAIKAN 1: Update Tooltip untuk Menampilkan Jam
                      // ========================================================
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (touchedSpot) => Colors.black,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final hour = spot.x.toInt();
                              final kwh = spot.y.toStringAsFixed(3);

                              // Gunakan RichText untuk styling berbeda
                              return LineTooltipItem(
                                '', // Teks utama dikosongkan, kita gunakan child
                                const TextStyle(), // Style default
                                children: [
                                  TextSpan(
                                    text: 'Jam $hour:00\n',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(
                                        (0.8 * 255).toInt(),
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '$kwh kWh',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                textAlign: TextAlign.left,
                              );
                            }).toList();
                          },
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
    );
  }
}
