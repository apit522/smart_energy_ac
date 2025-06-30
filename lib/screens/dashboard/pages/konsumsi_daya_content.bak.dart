// lib/screens/dashboard/pages/konsumsi_daya_content.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../models/device_model.dart';
import '../../../models/device_data_model.dart';
import '../../../services/device_service.dart';
import '../../../utils/app_colors.dart';

class KonsumsiDayaContent extends StatefulWidget {
  const KonsumsiDayaContent({super.key});

  @override
  State<KonsumsiDayaContent> createState() => _KonsumsiDayaContentState();
}

class _KonsumsiDayaContentState extends State<KonsumsiDayaContent> {
  final DeviceService _deviceService = DeviceService();
  List<Device> _devices = [];
  Device? _selectedDevice;
  List<DeviceData> _deviceData = [];
  bool _isLoading = true;
  String _selectedPeriod = '24h';

  double _avgWatt = 0.0;
  double _avgVoltage = 0.0;
  double _avgCurrent = 0.0;
  double _totalKwh = 0.0;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchUserDevices();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_selectedDevice != null) {
        _fetchDeviceData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserDevices() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final devices = await _deviceService.getDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          if (_devices.isNotEmpty) {
            _selectedDevice = _devices.first;
            _fetchDeviceData();
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error memuat perangkat: $e')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDeviceData() async {
    if (_selectedDevice == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    try {
      final data = await _deviceService.getDeviceData(
        _selectedDevice!.id,
        period: _selectedPeriod,
      );
      if (mounted) {
        setState(() {
          _deviceData = data;
          _calculateMetrics(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error memuat data perangkat: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateMetrics(List<DeviceData> data) {
    if (data.isEmpty) {
      _avgWatt = 0.0;
      _avgVoltage = 0.0;
      _avgCurrent = 0.0;
      _totalKwh = 0.0;
      return;
    }

    _avgWatt = data.map((d) => d.watt).reduce((a, b) => a + b) / data.length;
    _avgVoltage =
        data.map((d) => d.voltage).reduce((a, b) => a + b) / data.length;
    _avgCurrent =
        data.map((d) => d.current).reduce((a, b) => a + b) / data.length;

    double totalWattSeconds = 0;
    for (int i = 0; i < data.length - 1; i++) {
      double avgPowerInterval = (data[i].watt + data[i + 1].watt) / 2;
      double durationSeconds = data[i + 1].timestamp
          .difference(data[i].timestamp)
          .inSeconds
          .toDouble();
      totalWattSeconds += avgPowerInterval * durationSeconds;
    }
    double totalWattHours = totalWattSeconds / 3600;
    _totalKwh = totalWattHours / 1000;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_devices.isNotEmpty)
              DropdownButton<Device>(
                value: _selectedDevice,
                hint: const Text('Pilih Perangkat'),
                items: _devices
                    .map(
                      (device) => DropdownMenuItem(
                        value: device,
                        child: Text(device.name),
                      ),
                    )
                    .toList(),
                onChanged: (device) {
                  if (device != null) {
                    setState(() {
                      _selectedDevice = device;
                    });
                    _fetchDeviceData();
                  }
                },
              )
            else if (!_isLoading)
              const Text('Tidak ada perangkat terdaftar.'),
            DropdownButton<String>(
              value: _selectedPeriod,
              items: const [
                DropdownMenuItem(value: '24h', child: Text('24 Jam')),
                DropdownMenuItem(value: '7d', child: Text('7 Hari')),
                DropdownMenuItem(value: '30d', child: Text('30 Hari')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPeriod = value;
                  });
                  _fetchDeviceData();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
            : Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildChartCard(
                        title: 'Penggunaan Daya (Watt)',
                        spots: _deviceData
                            .map(
                              (d) => FlSpot(
                                d.timestamp.millisecondsSinceEpoch.toDouble(),
                                d.watt,
                              ),
                            )
                            .toList(),
                        color: Colors.blue,
                        unit: 'W',
                      ),
                      const SizedBox(height: 16),
                      _buildChartCard(
                        title: 'Tegangan (Voltage)',
                        spots: _deviceData
                            .map(
                              (d) => FlSpot(
                                d.timestamp.millisecondsSinceEpoch.toDouble(),
                                d.voltage,
                              ),
                            )
                            .toList(),
                        color: Colors.red,
                        unit: 'V',
                      ),
                      const SizedBox(height: 16),
                      _buildChartCard(
                        title: 'Arus (Current)',
                        spots: _deviceData
                            .map(
                              (d) => FlSpot(
                                d.timestamp.millisecondsSinceEpoch.toDouble(),
                                d.current,
                              ),
                            )
                            .toList(),
                        color: Colors.green,
                        unit: 'A',
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.5 / 2,
      children: [
        _buildSummaryCard(
          'Rata-rata Watt',
          _avgWatt.toStringAsFixed(2),
          'W',
          Icons.power_outlined,
        ),
        _buildSummaryCard(
          'Rata-rata Voltage',
          _avgVoltage.toStringAsFixed(2),
          'V',
          Icons.flash_on_outlined,
        ),
        _buildSummaryCard(
          'Rata-rata Current',
          _avgCurrent.toStringAsFixed(2),
          'A',
          Icons.electrical_services_outlined,
        ),
        _buildSummaryCard(
          'Total Konsumsi',
          _totalKwh.toStringAsFixed(3),
          'kWh',
          Icons.battery_charging_full_outlined,
          isKwh: true,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String unit,
    IconData icon, {
    bool isKwh = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                Icon(icon, color: AppColors.primaryColor),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isKwh ? 24 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                  child: Text(unit, style: TextStyle(color: Colors.grey[600])),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required List<FlSpot> spots,
    required Color color,
    required String unit,
  }) {
    if (spots.length < 2) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const AspectRatio(
                aspectRatio: 2.5,
                child: Center(
                  child: Text('Data tidak cukup untuk menampilkan grafik.'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final double minX = spots.first.x;
    final double maxX = spots.last.x;
    final double xRange = maxX - minX;
    final double interval = xRange > 0 ? xRange / 4 : 1;

    final yValues = spots.map((s) => s.y).toList();
    final minY = yValues.reduce((a, b) => a < b ? a : b);
    final maxY = yValues.reduce((a, b) => a > b ? a : b);
    final yMargin = (maxY - minY) * 0.1; // 10% padding

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 2.5,
              child: LineChart(
                LineChartData(
                  minY: minY - yMargin,
                  maxY: maxY + yMargin,
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
                          meta.formattedValue,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.min || value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          final dateTime = DateTime.fromMillisecondsSinceEpoch(
                            value.toInt(),
                          );
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8.0,
                            child: Text(
                              DateFormat('HH:mm').format(dateTime),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: const Color(0xffe7e7e7),
                      width: 1,
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.3),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.black,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final yValue = spot.y.toStringAsFixed(2);
                          return LineTooltipItem(
                            '$yValue $unit',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
