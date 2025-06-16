import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../models/device_model.dart';
import '../../../models/device_data_model.dart';
import '../../../services/device_service.dart';
import '../../../utils/app_colors.dart';

class SuhuContent extends StatefulWidget {
  const SuhuContent({super.key});

  @override
  State<SuhuContent> createState() => _SuhuContentState();
}

class _SuhuContentState extends State<SuhuContent> {
  final DeviceService _deviceService = DeviceService();
  List<Device> _devices = [];
  Device? _selectedDevice;
  List<DeviceData> _deviceData = [];
  bool _isLoading = true;
  String _selectedPeriod = '24h';
  Timer? _refreshTimer;

  double _avgTemp = 0.0;
  double _minTemp = 0.0;
  double _maxTemp = 0.0;

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
    setState(() => _isLoading = true);
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchDeviceData() async {
    if (_selectedDevice == null) {
      setState(() => _isLoading = false);
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
            content: Text('Error memuat data suhu: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateMetrics(List<DeviceData> data) {
    if (data.isEmpty) {
      _avgTemp = _minTemp = _maxTemp = 0.0;
      return;
    }
    final temps = data.map((d) => d.temperature).toList();
    _avgTemp = temps.reduce((a, b) => a + b) / temps.length;
    _minTemp = temps.reduce((a, b) => a < b ? a : b);
    _maxTemp = temps.reduce((a, b) => a > b ? a : b);
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
                        children: [
                          // Summary cards
                          _buildSummaryCards(),
                          const SizedBox(height: 24),

                          // Temperature chart
                          _buildChartCard(
                            title: 'Suhu',
                            spots: _deviceData
                                .map(
                                  (d) => FlSpot(
                                    d.createdAt.millisecondsSinceEpoch
                                        .toDouble(),
                                    d.temperature,
                                  ),
                                )
                                .toList(),
                            color: _getTemperatureColor(_avgTemp),
                            unit: '°C',
                            icon: Icons.thermostat,
                          ),
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
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(
                              d.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (device) {
                      if (device != null) {
                        setState(() => _selectedDevice = device);
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
                'Tidak ada perangkat.',
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
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPeriod = val);
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
          'Rata-rata',
          _avgTemp.toStringAsFixed(1),
          '°C',
          Icons.thermostat,
          color: _getTemperatureColor(_avgTemp),
        ),
        _buildSummaryCard(
          'Tertinggi',
          _maxTemp.toStringAsFixed(1),
          '°C',
          Icons.arrow_upward,
          color: Colors.red[400],
        ),
        _buildSummaryCard(
          'Terendah',
          _minTemp.toStringAsFixed(1),
          '°C',
          Icons.arrow_downward,
          color: Colors.blue[400],
        ),
        _buildSummaryCard(
          'Terkini',
          _deviceData.isNotEmpty
              ? _deviceData.last.temperature.toStringAsFixed(1)
              : '-',
          '°C',
          Icons.access_time,
          color: Colors.grey[600],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String unit,
    IconData icon, {
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: color ?? AppColors.primaryColor, size: 20),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.grey[800],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                  child: Text(
                    unit,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                          final yValue = spot.y.toStringAsFixed(1);
                          final dateTime = DateTime.fromMillisecondsSinceEpoch(
                            spot.x.toInt(),
                          );
                          return LineTooltipItem(
                            '${DateFormat('HH:mm').format(dateTime)}\n$yValue$unit',
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

  Color _getTemperatureColor(double temp) {
    if (temp < 10) return Colors.blue[400]!;
    if (temp < 20) return Colors.lightBlue[400]!;
    if (temp < 30) return Colors.green[400]!;
    if (temp < 40) return Colors.orange[400]!;
    return Colors.red[400]!;
  }
}
