// lib/screens/dashboard/pages/konsumsi_daya_content.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Diperlukan untuk kalkulasi min/max
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/device_model.dart';
import '../../../models/device_daily_summary_model.dart';
import '../../../services/device_service.dart';
import '../../../utils/app_colors.dart';

// Kelas data untuk grafik real-time, menyimpan timestamp
class _RealtimeDataPoint {
  final DateTime timestamp;
  final double watt;

  _RealtimeDataPoint({required this.timestamp, required this.watt});

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'watt': watt,
  };

  factory _RealtimeDataPoint.fromJson(Map<String, dynamic> json) =>
      _RealtimeDataPoint(
        timestamp: DateTime.parse(json['timestamp']),
        watt: json['watt'].toDouble(),
      );
}

class KonsumsiDayaContent extends StatefulWidget {
  const KonsumsiDayaContent({super.key});

  @override
  State<KonsumsiDayaContent> createState() => _KonsumsiDayaContentState();
}

class _KonsumsiDayaContentState extends State<KonsumsiDayaContent> {
  final DeviceService _deviceService = DeviceService();

  // State UI
  bool _isLoading = true;
  List<Device> _devices = [];
  Device? _selectedDevice;
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );

  // State Data
  List<DeviceDailySummary> _dailySummaries = [];
  double _totalKwh = 0.0,
      _avgWatt = 0.0,
      _avgVoltage = 0.0,
      _avgCurrent = 0.0,
      _estimatedCost = 0.0;

  // State Grafik Real-time
  Timer? _realtimeTimer;
  List<_RealtimeDataPoint> _realtimeDataPoints = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _fetchUserDevices();
    if (_selectedDevice != null) {
      await _fetchSummaryData();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserDevices() async {
    setState(() => _isLoading = true);
    try {
      _devices = await _deviceService.getDevices();
      if (mounted && _devices.isNotEmpty) {
        _selectedDevice = _devices.first;
      }
    } catch (e) {
      _showError('Gagal memuat perangkat: $e');
    }
  }

  Future<void> _fetchSummaryData() async {
    if (_selectedDevice == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      _dailySummaries = await _deviceService.getDailySummary(
        _selectedDevice!.id,
        startDate: _selectedDateRange.start,
        endDate: _selectedDateRange.end,
      );
      _calculateStats();
      await _startRealtimeUpdates();
    } catch (e) {
      _showError('Gagal memuat ringkasan data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    if (_dailySummaries.isEmpty) {
      _totalKwh = 0;
      _avgWatt = 0;
      _avgVoltage = 0;
      _avgCurrent = 0;
      _estimatedCost = 0;
      return;
    }
    _totalKwh = _dailySummaries.map((s) => s.totalKwh).reduce((a, b) => a + b);
    final count = _dailySummaries.length;
    _avgWatt =
        _dailySummaries.map((s) => s.avgWatt).reduce((a, b) => a + b) / count;
    _avgVoltage =
        _dailySummaries.map((s) => s.avgVoltage).reduce((a, b) => a + b) /
        count;
    _avgCurrent =
        _dailySummaries.map((s) => s.avgCurrent).reduce((a, b) => a + b) /
        count;
    final tarif = _selectedDevice?.tarifPerKwh ?? 0;
    _estimatedCost = _totalKwh * tarif;
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      await _fetchSummaryData();
    }
  }

  void _showError(String message) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
  }

  // --- LOGIKA PERSISTENSI REAL-TIME ---

  String _getRealtimeDataKey() =>
      'realtime_watt_data_${_selectedDevice?.id ?? 'null'}';

  Future<void> _loadRealtimeDataFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDataJson = prefs.getString(_getRealtimeDataKey());
    if (savedDataJson != null) {
      final List<dynamic> decodedList = json.decode(savedDataJson);
      final loadedPoints = decodedList
          .map((item) => _RealtimeDataPoint.fromJson(item))
          .toList();
      if (mounted) setState(() => _realtimeDataPoints = loadedPoints);
    }
  }

  Future<void> _saveRealtimeDataToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dataToSave = json.encode(
      _realtimeDataPoints.map((p) => p.toJson()).toList(),
    );
    await prefs.setString(_getRealtimeDataKey(), dataToSave);
  }

  Future<void> _startRealtimeUpdates() async {
    _realtimeTimer?.cancel();
    _clearRealtimeData();
    if (_selectedDevice == null) return;

    await _loadRealtimeDataFromPrefs();

    if (_realtimeDataPoints.isEmpty) {
      await _fetchLatestWattData(saveData: false);
    }

    _realtimeTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchLatestWattData();
    });
  }

  Future<void> _fetchLatestWattData({bool saveData = true}) async {
    if (_selectedDevice == null || !mounted) return;
    try {
      final latestData = await _deviceService.getLatestData(
        _selectedDevice!.id,
      );
      if (latestData != null) {
        setState(() {
          final newPoint = _RealtimeDataPoint(
            timestamp: DateTime.now(),
            watt: latestData.watt,
          );
          _realtimeDataPoints.add(newPoint);
          if (_realtimeDataPoints.length > 30) {
            _realtimeDataPoints.removeAt(0);
          }
        });
        if (saveData) await _saveRealtimeDataToPrefs();
      }
    } catch (e) {
      print("Gagal mengambil data real-time: $e");
    }
  }

  void _clearRealtimeData() => setState(() => _realtimeDataPoints = []);

  // --- UI UTAMA & WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 850;
        return Column(
          children: [
            _buildFilterBar(isMobile: isMobile),
            const SizedBox(height: 24),
            _isLoading
                ? const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Expanded(
                    child: _selectedDevice == null
                        ? const Center(
                            child: Text(
                              'Tidak ada perangkat terpilih.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Column(
                                children: [
                                  _buildSummaryCards(isMobile: isMobile),
                                  const SizedBox(height: 24),
                                  _buildChartsSection(isMobile: isMobile),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar({required bool isMobile}) {
    final dateFormat = DateFormat('d MMM y');
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: isMobile
            ? Column(
                children: [_deviceDropdown(), _datePickerButton(dateFormat)],
              )
            : Row(
                children: [
                  Expanded(child: _deviceDropdown()),
                  const SizedBox(width: 16),
                  _datePickerButton(dateFormat),
                ],
              ),
      ),
    );
  }

  Widget _deviceDropdown() => DropdownButtonHideUnderline(
    child: DropdownButton<Device>(
      value: _selectedDevice,
      isExpanded: true,
      hint: const Text('Pilih Perangkat'),
      items: _devices
          .map(
            (d) => DropdownMenuItem(
              value: d,
              child: Text(d.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (device) {
        if (device != null && device.id != _selectedDevice?.id) {
          setState(() => _selectedDevice = device);
          _fetchSummaryData();
        }
      },
    ),
  );

  Widget _datePickerButton(DateFormat format) => TextButton.icon(
    onPressed: _selectDateRange,
    icon: const Icon(Icons.calendar_today_outlined, size: 18),
    label: Text(
      '${format.format(_selectedDateRange.start)} - ${format.format(_selectedDateRange.end)}',
    ),
    style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
  );

  Widget _buildSummaryCards({required bool isMobile}) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    int crossAxisCount = isMobile ? 2 : 5;
    double childAspectRatio = isMobile ? 1.8 : 2.2;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: childAspectRatio,
      children: [
        _buildSummaryCard(
          'Total Konsumsi',
          _totalKwh.toStringAsFixed(2),
          'kWh',
          Icons.power,
        ),
        _buildSummaryCard(
          'Rata-rata Daya',
          _avgWatt.toStringAsFixed(1),
          'Watt',
          Icons.speed_outlined,
        ),
        _buildSummaryCard(
          'Rata-rata Tegangan',
          _avgVoltage.toStringAsFixed(1),
          'V',
          Icons.flash_on_outlined,
        ),
        _buildSummaryCard(
          'Rata-rata Arus',
          _avgCurrent.toStringAsFixed(2),
          'A',
          Icons.electrical_services_outlined,
        ),
        _buildSummaryCard(
          'Perkiraan Biaya',
          currencyFormatter.format(_estimatedCost),
          '',
          Icons.payments_outlined,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String unit,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '$value $unit'.trim(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection({required bool isMobile}) {
    if (isMobile) {
      return Column(
        children: [
          _buildDailyChartCard(),
          const SizedBox(height: 24),
          _buildRealtimeChartCard(),
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildDailyChartCard()),
          const SizedBox(width: 24),
          Expanded(child: _buildRealtimeChartCard()),
        ],
      );
    }
  }

  Widget _buildDailyChartCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Konsumsi Energi Harian (kWh)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.7,
              child: _dailySummaries.length < 2
                  ? const Center(
                      child: Text('Data tidak cukup untuk menampilkan grafik.'),
                    )
                  : BarChart(
                      BarChartData(
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (touchedSpot) => Colors.black87,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final summary = _dailySummaries[groupIndex];
                              return BarTooltipItem(
                                '${DateFormat('d MMM').format(summary.summaryDate)}\n',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: '${rod.toY.toStringAsFixed(2)} kWh',
                                    style: const TextStyle(
                                      color: Colors.yellow,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            },
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
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) => Text(
                                meta.formattedValue,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                String title = '';
                                final matchingSummary = _dailySummaries
                                    .firstWhere(
                                      (s) => s.summaryDate.day == value.toInt(),
                                      orElse: () => _dailySummaries.first,
                                    );
                                title = DateFormat(
                                  'd/M',
                                ).format(matchingSummary.summaryDate);
                                int skip = _dailySummaries.length ~/ 7 + 1;
                                if (value.toInt() % skip != 0 &&
                                    _dailySummaries.length > 10) {
                                  return Container();
                                }
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 4,
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: _dailySummaries.asMap().entries.map((entry) {
                          final summary = entry.value;
                          return BarChartGroupData(
                            x: summary.summaryDate.day,
                            barRods: [
                              BarChartRodData(
                                toY: summary.totalKwh,
                                color: AppColors.primaryColor,
                                width: 12,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeChartCard() {
    final spots = _realtimeDataPoints.map((point) {
      return FlSpot(
        point.timestamp.millisecondsSinceEpoch.toDouble(),
        point.watt,
      );
    }).toList();

    double minY = 0, maxY = 100; // Default
    if (_realtimeDataPoints.isNotEmpty) {
      final wattValues = _realtimeDataPoints.map((p) => p.watt);
      minY = wattValues.reduce(min);
      maxY = wattValues.reduce(max);
      if (minY == maxY) {
        minY = max(0, minY - 50);
        maxY += 50;
      }
      final padding = (maxY - minY) * 0.2;
      minY = max(0, minY - padding);
      maxY += padding;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grafik Daya Real-time (Watt)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.7,
              child: _realtimeDataPoints.isEmpty
                  ? const Center(child: Text('Menunggu data real-time...'))
                  : LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(),
                        minY: minY,
                        maxY: maxY,
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => Colors.black87,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final dataPoint = _realtimeDataPoints
                                    .firstWhere(
                                      (p) =>
                                          p.timestamp.millisecondsSinceEpoch
                                              .toDouble() ==
                                          spot.x,
                                      orElse: () => _realtimeDataPoints.first,
                                    );
                                return LineTooltipItem(
                                  '${DateFormat('HH:mm:ss').format(dataPoint.timestamp)}\n',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          '${dataPoint.watt.toStringAsFixed(1)} Watt',
                                      style: const TextStyle(
                                        color: Colors.yellow,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList();
                            },
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: Colors.grey.shade300,
                            strokeWidth: 0.5,
                          ),
                          getDrawingVerticalLine: (v) => FlLine(
                            color: Colors.grey.shade300,
                            strokeWidth: 0.5,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (v, m) => Text(
                                m.formattedValue,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              // PERBAIKAN: Memastikan interval tidak nol
                              interval: spots.length > 1
                                  ? (spots.last.x - spots.first.x) / 4
                                  : 1000,
                              getTitlesWidget: (value, meta) {
                                if (meta.max == value || meta.min == value)
                                  return Container();
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 8,
                                  child: Text(
                                    DateFormat('HH:mm').format(
                                      DateTime.fromMillisecondsSinceEpoch(
                                        value.toInt(),
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppColors.accentColor,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.accentColor.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
