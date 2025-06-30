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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat perangkat: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
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
          SnackBar(
            content: Text('Error memuat data perangkat: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with dropdowns
          _buildHeaderSection(),
          const SizedBox(height: 16),

          // Content
          _isLoading
              ? const Expanded(
                  child: Center(
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryColor,
                      ),
                    ),
                  ),
                )
              : Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchDeviceData,
                    color: AppColors.primaryColor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary cards
                          _buildSummaryCards(),
                          const SizedBox(height: 24),

                          // Charts
                          _buildChartCard(
                            title: 'Penggunaan Daya',
                            spots: _deviceData
                                .map(
                                  (d) => FlSpot(
                                    d.timestamp.millisecondsSinceEpoch
                                        .toDouble(),
                                    d.watt,
                                  ),
                                )
                                .toList(),
                            color: AppColors.primaryColor,
                            unit: 'W',
                            icon: Icons.power_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildChartCard(
                            title: 'Tegangan',
                            spots: _deviceData
                                .map(
                                  (d) => FlSpot(
                                    d.timestamp.millisecondsSinceEpoch
                                        .toDouble(),
                                    d.voltage,
                                  ),
                                )
                                .toList(),
                            color: Colors.redAccent,
                            unit: 'V',
                            icon: Icons.flash_on_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildChartCard(
                            title: 'Arus',
                            spots: _deviceData
                                .map(
                                  (d) => FlSpot(
                                    d.timestamp.millisecondsSinceEpoch
                                        .toDouble(),
                                    d.current,
                                  ),
                                )
                                .toList(),
                            color: Colors.green,
                            unit: 'A',
                            icon: Icons.electrical_services_outlined,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_devices.isNotEmpty)
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Device>(
                    value: _selectedDevice,
                    isExpanded: true,
                    hint: const Text(
                      'Pilih Perangkat',
                      style: TextStyle(color: Colors.grey),
                    ),
                    items: _devices
                        .map(
                          (device) => DropdownMenuItem(
                            value: device,
                            child: Text(
                              device.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
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
                    borderRadius: BorderRadius.circular(12),
                    icon: const Icon(Icons.arrow_drop_down, size: 24),
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ),
              )
            else if (!_isLoading)
              const Text(
                'Tidak ada perangkat terdaftar.',
                style: TextStyle(color: Colors.grey),
              ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  borderRadius: BorderRadius.circular(12),
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildSummaryCard(
          'Rata-rata Watt',
          _avgWatt.toStringAsFixed(2),
          'W',
          Icons.power_outlined,
          gradient: LinearGradient(
            colors: [
              AppColors.primaryColor.withOpacity(0.8),
              AppColors.primaryColor,
            ],
          ),
        ),
        _buildSummaryCard(
          'Rata-rata Voltage',
          _avgVoltage.toStringAsFixed(2),
          'V',
          Icons.flash_on_outlined,
          gradient: LinearGradient(
            colors: [Colors.redAccent.withOpacity(0.8), Colors.redAccent],
          ),
        ),
        _buildSummaryCard(
          'Rata-rata Current',
          _avgCurrent.toStringAsFixed(2),
          'A',
          Icons.electrical_services_outlined,
          gradient: LinearGradient(
            colors: [Colors.green.withOpacity(0.8), Colors.green],
          ),
        ),
        _buildSummaryCard(
          'Total Konsumsi',
          _totalKwh.toStringAsFixed(3),
          'kWh',
          Icons.battery_charging_full_outlined,
          gradient: LinearGradient(
            colors: [Colors.orange.withOpacity(0.8), Colors.orange],
          ),
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
    Gradient? gradient,
    bool isKwh = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  unit,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
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
    required IconData icon,
  }) {
    if (spots.length < 2) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const AspectRatio(
                aspectRatio: 2.5,
                child: Center(
                  child: Text(
                    'Data tidak cukup untuk menampilkan grafik.',
                    style: TextStyle(color: Colors.grey),
                  ),
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
    final minY = yValues.reduce((a, b) => a < b ? a : b) * 0.98; // 2% padding
    final maxY = yValues.reduce((a, b) => a > b ? a : b) * 1.02; // 2% padding

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 2.5,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: (maxY - minY) / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: (maxY - minY) / 4,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              value.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
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
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          final dateTime = DateTime.fromMillisecondsSinceEpoch(
                            value.toInt(),
                          );
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8.0,
                            child: Text(
                              DateFormat('HH:mm').format(dateTime),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
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
                      color: color,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.2),
                            color.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.white,
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final yValue = spot.y.toStringAsFixed(2);
                          final dateTime = DateTime.fromMillisecondsSinceEpoch(
                            spot.x.toInt(),
                          );
                          return LineTooltipItem(
                            '${DateFormat('HH:mm').format(dateTime)}\n$yValue $unit',
                            TextStyle(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
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
