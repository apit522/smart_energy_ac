// lib\screens\dashboard\pages\suhu_content.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Diperlukan untuk kalkulasi min/max
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/device_model.dart';
import '../../../models/device_daily_summary_model.dart';
import '../../../services/device_service.dart';
import '../../../utils/app_colors.dart';

// Kelas data untuk grafik suhu real-time
class _SuhuRealtimeDataPoint {
  final DateTime timestamp;
  final double temperature;

  _SuhuRealtimeDataPoint({required this.timestamp, required this.temperature});

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'temperature': temperature,
  };

  factory _SuhuRealtimeDataPoint.fromJson(Map<String, dynamic> json) =>
      _SuhuRealtimeDataPoint(
        timestamp: DateTime.parse(json['timestamp']),
        temperature: json['temperature'].toDouble(),
      );
}

class SuhuContent extends StatefulWidget {
  const SuhuContent({super.key});

  @override
  State<SuhuContent> createState() => _SuhuContentState();
}

class _SuhuContentState extends State<SuhuContent> {
  final DeviceService _deviceService = DeviceService();

  // State UI
  bool _isLoading = true;
  List<Device> _devices = [];
  Device? _selectedDevice;
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now(),
  );

  // State Data Ringkasan Harian
  List<DeviceDailySummary> _dailySummaries = [];
  double _periodAvgTemp = 0.0;
  double _periodMaxTemp = 0.0;
  double _periodMinTemp = 0.0;

  // State Grafik Real-time
  Timer? _realtimeTimer;
  List<_SuhuRealtimeDataPoint> _suhuRealtimeDataPoints = [];

  // State untuk panning dan viewport
  static const Duration _visibleDuration = Duration(minutes: 5);
  double? _minXVisible, _maxXVisible;
  bool _isAtLiveEdge = true;
  Offset? _lastPanPosition;

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
      _showError('Error memuat perangkat: $e');
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
      _showError('Error memuat ringkasan suhu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    if (_dailySummaries.isEmpty) {
      _periodAvgTemp = 0;
      _periodMaxTemp = 0;
      _periodMinTemp = 0;
      return;
    }
    final temperatures = _dailySummaries.map((s) => s.avgTemperature);
    _periodAvgTemp = temperatures.reduce((a, b) => a + b) / temperatures.length;
    _periodMaxTemp = temperatures.reduce(max);
    _periodMinTemp = temperatures.reduce(min);
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // --- LOGIKA REAL-TIME & PERSISTENSI ---

  String _getRealtimeDataKey() =>
      'suhu_realtime_data_${_selectedDevice?.id ?? 'null'}';

  Future<void> _loadRealtimeDataFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDataJson = prefs.getString(_getRealtimeDataKey());
    if (savedDataJson != null) {
      final List<dynamic> decodedList = json.decode(savedDataJson);
      final loadedPoints = decodedList
          .map((item) => _SuhuRealtimeDataPoint.fromJson(item))
          .toList();
      if (mounted) setState(() => _suhuRealtimeDataPoints = loadedPoints);
    }
  }

  Future<void> _saveRealtimeDataToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dataToSave = json.encode(
      _suhuRealtimeDataPoints.map((p) => p.toJson()).toList(),
    );
    await prefs.setString(_getRealtimeDataKey(), dataToSave);
  }

  void _updateVisibleXRange() {
    if (_suhuRealtimeDataPoints.isEmpty) return;

    final lastTimestamp = _suhuRealtimeDataPoints.last.timestamp;
    setState(() {
      _maxXVisible = lastTimestamp.millisecondsSinceEpoch.toDouble();
      _minXVisible = lastTimestamp
          .subtract(_visibleDuration)
          .millisecondsSinceEpoch
          .toDouble();
    });
  }

  void _scrollToLive() {
    setState(() {
      _isAtLiveEdge = true;
      _updateVisibleXRange();
    });
  }

  Future<void> _startRealtimeUpdates() async {
    _realtimeTimer?.cancel();
    _clearRealtimeData();
    if (_selectedDevice == null) return;

    await _loadRealtimeDataFromPrefs();
    _scrollToLive();

    _realtimeTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchLatestSuhuData();
    });
  }

  Future<void> _fetchLatestSuhuData() async {
    if (_selectedDevice == null || !mounted) return;
    try {
      final latestData = await _deviceService.getLatestData(
        _selectedDevice!.id,
      );
      if (latestData != null) {
        setState(() {
          final newPoint = _SuhuRealtimeDataPoint(
            timestamp: DateTime.now(),
            temperature: latestData.temperature,
          );
          _suhuRealtimeDataPoints.add(newPoint);
          if (_suhuRealtimeDataPoints.length > 500) {
            _suhuRealtimeDataPoints.removeAt(0);
          }

          if (_isAtLiveEdge) {
            _updateVisibleXRange();
          }
        });
        await _saveRealtimeDataToPrefs();
      }
    } catch (e) {
      print("Gagal mengambil data suhu real-time: $e");
    }
  }

  void _clearRealtimeData() => setState(() => _suhuRealtimeDataPoints = []);

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
    int crossAxisCount = isMobile ? 3 : 3;
    double childAspectRatio = isMobile ? 1.5 : 2.0;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: childAspectRatio,
      children: [
        // ✅ PERUBAHAN: Kirim nilai 'isMobile' ke setiap kartu
        _buildSummaryCard(
          'Suhu Rata-rata',
          _periodAvgTemp.toStringAsFixed(1),
          Icons.thermostat_outlined,
          isMobile: isMobile, // Tambahkan ini
        ),
        _buildSummaryCard(
          'Suhu Tertinggi',
          _periodMaxTemp.toStringAsFixed(1),
          Icons.arrow_upward,
          isMobile: isMobile, // Tambahkan ini
        ),
        _buildSummaryCard(
          'Suhu Terendah',
          _periodMinTemp.toStringAsFixed(1),
          Icons.arrow_downward,
          isMobile: isMobile, // Tambahkan ini
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon, {
    required bool isMobile,
  }) {
    // Tambahkan parameter isMobile
    // Definisikan konten utama di dalam sebuah widget
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '$value°C',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.orange.shade700, size: 24),
          ],
        ),
      ],
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        // ✅ PERUBAHAN: Gunakan FittedBox hanya jika isMobile true
        child: isMobile
            ? FittedBox(fit: BoxFit.contain, child: content)
            : content, // Jika bukan mobile, tampilkan konten ukuran asli
      ),
    );
  }

  Widget _buildChartsSection({required bool isMobile}) {
    if (isMobile) {
      return Column(
        children: [
          _buildDailyAvgChartCard(),
          const SizedBox(height: 24),
          _buildRealtimeChartCard(),
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildDailyAvgChartCard()),
          const SizedBox(width: 24),
          Expanded(child: _buildRealtimeChartCard()),
        ],
      );
    }
  }

  Widget _buildDailyAvgChartCard() {
    final spots = _dailySummaries.map((summary) {
      return FlSpot(
        summary.summaryDate.millisecondsSinceEpoch.toDouble(),
        summary.avgTemperature,
      );
    }).toList();

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
              'Grafik Suhu Rata-rata Harian',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.7,
              child: _dailySummaries.length < 2
                  ? const Center(
                      child: Text('Data tidak cukup untuk menampilkan grafik.'),
                    )
                  : LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => Colors.black87,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final date =
                                    DateTime.fromMillisecondsSinceEpoch(
                                      spot.x.toInt(),
                                    );
                                return LineTooltipItem(
                                  '${DateFormat('d MMM y').format(date)}\n',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${spot.y.toStringAsFixed(1)}°C',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList();
                            },
                          ),
                        ),
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
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
                              interval: spots.length > 1
                                  ? (spots.last.x - spots.first.x) / 4
                                  : 1000,
                              getTitlesWidget: (value, meta) {
                                final date =
                                    DateTime.fromMillisecondsSinceEpoch(
                                      value.toInt(),
                                    );
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 8,
                                  child: Text(
                                    DateFormat('d/M').format(date),
                                    style: const TextStyle(fontSize: 10),
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
                            color: Colors.orange.shade700,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.orange.withOpacity(0.3),
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

  Widget _buildRealtimeChartCard() {
    final spots = _suhuRealtimeDataPoints.map((point) {
      return FlSpot(
        point.timestamp.millisecondsSinceEpoch.toDouble(),
        point.temperature,
      );
    }).toList();

    double minY = 0, maxY = 50; // Default
    if (_suhuRealtimeDataPoints.isNotEmpty) {
      final visiblePoints = _suhuRealtimeDataPoints.where((p) {
        final time = p.timestamp.millisecondsSinceEpoch.toDouble();
        return time >= (_minXVisible ?? 0) &&
            time <= (_maxXVisible ?? double.infinity);
      });

      if (visiblePoints.isNotEmpty) {
        final temps = visiblePoints.map((p) => p.temperature);
        minY = temps.reduce(min);
        maxY = temps.reduce(max);
        if (minY == maxY) {
          minY = max(0, minY - 5);
          maxY += 5;
        }
        final padding = (maxY - minY) * 0.2;
        minY = max(0, minY - padding);
        maxY += padding;
      }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grafik Suhu Real-time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (!_isAtLiveEdge)
                  TextButton(
                    onPressed: _scrollToLive,
                    child: const Text('Go to Live'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.7,
              child: _suhuRealtimeDataPoints.isEmpty
                  ? const Center(child: Text('Menunggu data real-time...'))
                  : LineChart(
                      LineChartData(
                        minX: _minXVisible,
                        maxX: _maxXVisible,
                        minY: minY,
                        maxY: maxY,
                        clipData: const FlClipData.all(),
                        lineTouchData: LineTouchData(
                          touchCallback:
                              (
                                FlTouchEvent event,
                                LineTouchResponse? response,
                              ) {
                                if (!mounted) return;

                                if (event is FlPanStartEvent) {
                                  setState(() {
                                    _isAtLiveEdge = false;
                                    _lastPanPosition = event
                                        .localPosition; // Store start position
                                  });
                                } else if (event is FlPanUpdateEvent) {
                                  if (_minXVisible == null ||
                                      _maxXVisible == null ||
                                      _lastPanPosition == null)
                                    return;

                                  final double dx =
                                      event.localPosition.dx -
                                      _lastPanPosition!.dx;

                                  final chartWidth = context.size?.width ?? 1;
                                  final dataPerPixel =
                                      (_maxXVisible! - _minXVisible!) /
                                      chartWidth;
                                  final dataDx = dx * dataPerPixel;

                                  setState(() {
                                    final firstDataX = _suhuRealtimeDataPoints
                                        .first
                                        .timestamp
                                        .millisecondsSinceEpoch
                                        .toDouble();
                                    final lastDataX = _suhuRealtimeDataPoints
                                        .last
                                        .timestamp
                                        .millisecondsSinceEpoch
                                        .toDouble();

                                    double newMinX = _minXVisible! - dataDx;
                                    double newMaxX = _maxXVisible! - dataDx;

                                    if (newMinX < firstDataX) {
                                      newMinX = firstDataX;
                                      newMaxX =
                                          newMinX +
                                          _visibleDuration.inMilliseconds;
                                    }
                                    if (newMaxX > lastDataX) {
                                      newMaxX = lastDataX;
                                      newMinX =
                                          newMaxX -
                                          _visibleDuration.inMilliseconds;
                                      _isAtLiveEdge = true;
                                    }

                                    _minXVisible = newMinX;
                                    _maxXVisible = newMaxX;
                                    _lastPanPosition = event
                                        .localPosition; // Update last position
                                  });
                                } else if (event is FlPanEndEvent ||
                                    event is FlLongPressEnd) {
                                  _lastPanPosition = null; // Reset on end
                                }
                              },
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => Colors.black87,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final dataPoint = _suhuRealtimeDataPoints
                                    .firstWhere(
                                      (p) =>
                                          p.timestamp.millisecondsSinceEpoch
                                              .toDouble() ==
                                          spot.x,
                                      orElse: () =>
                                          _suhuRealtimeDataPoints.first,
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
                                          '${dataPoint.temperature.toStringAsFixed(1)}°C',
                                      style: const TextStyle(
                                        color: Colors.orange,
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
                              getTitlesWidget: (value, meta) {
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
                            color: Colors.orange.shade700,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.orange.withOpacity(0.3),
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
