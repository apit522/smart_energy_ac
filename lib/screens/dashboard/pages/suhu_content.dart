// lib/screens/dashboard/pages/suhu_content.dart

import 'dart:async';
import 'dart:math'; // Diperlukan untuk kalkulasi min/max
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../models/device_model.dart';
import '../../../models/device_data_model.dart'; // Impor model DeviceData
import '../../../models/device_daily_summary_model.dart';
import '../../../services/device_service.dart';
import '../../../utils/app_colors.dart';

// Kelas data untuk grafik suhu real-time
class _SuhuRealtimeDataPoint {
  final DateTime timestamp;
  final double temperature;

  _SuhuRealtimeDataPoint({required this.timestamp, required this.temperature});
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
    start: DateTime.now().subtract(const Duration(days: 31)),
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

  // State untuk batas zoom
  double? _minXData;
  double? _maxXData;

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
      await _startRealtimeUpdates(); // Panggilan utama untuk grafik
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
      final difference = picked.end.difference(picked.start).inDays + 1;
      if (difference > 31) {
        _showError('Maksimal rentang tanggal adalah 31 hari.');
        return;
      }
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

  // --- LOGIKA BARU UNTUK GRAFIK REAL-TIME ---

  void _updateVisibleXRangeForLive() {
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
      _updateVisibleXRangeForLive();
    });
  }

  void _handleZoom(double scale) {
    // Pastikan semua nilai yang dibutuhkan tidak null
    if (_minXVisible == null ||
        _maxXVisible == null ||
        _minXData == null ||
        _maxXData == null) {
      return;
    }

    final totalDataRange = _maxXData! - _minXData!;
    final center = (_maxXVisible! + _minXVisible!) / 2;

    // Hitung rentang baru setelah di-zoom
    double newRange = (_maxXVisible! - _minXVisible!) / scale;

    // Batasi zoom-out agar tidak lebih lebar dari total data
    if (newRange > totalDataRange) {
      newRange = totalDataRange;
    }

    // ▼▼▼ FIX DI SINI ▼▼▼
    // Batasi zoom-in agar tidak terlalu dekat
    final minVisibleRange = const Duration(minutes: 1).inMilliseconds;
    if (newRange < minVisibleRange) {
      newRange = minVisibleRange.toDouble();
    }

    setState(() {
      _minXVisible = center - newRange / 2;
      _maxXVisible = center + newRange / 2;

      // Pastikan viewport tidak keluar dari batas data setelah zoom
      if (_minXVisible! < _minXData!) {
        _minXVisible = _minXData;
        _maxXVisible = _minXData! + newRange;
      }
      if (_maxXVisible! > _maxXData!) {
        _maxXVisible = _maxXData;
        _minXVisible = _maxXData! - newRange;
      }

      _isAtLiveEdge = false;
    });
  }

  void _zoomIn() => _handleZoom(0.8);
  void _zoomOut() => _handleZoom(1.2);

  void _handleTouchEvent(FlTouchEvent event) {
    if (event is FlPanStartEvent) {
      setState(() {
        _isAtLiveEdge = false;
        _lastPanPosition = event.localPosition;
      });
    } else if (event is FlPanUpdateEvent) {
      if (_minXVisible == null ||
          _maxXVisible == null ||
          _lastPanPosition == null ||
          _minXData == null ||
          _maxXData == null)
        return;

      final double dx = event.localPosition.dx - _lastPanPosition!.dx;
      final chartWidth = context.size?.width ?? 1;
      final dataPerPixel = (_maxXVisible! - _minXVisible!) / chartWidth;
      final dataDx = dx * dataPerPixel;

      setState(() {
        double visibleWidth = _maxXVisible! - _minXVisible!;
        double newMinX = _minXVisible! - dataDx;
        double newMaxX = _maxXVisible! - dataDx;

        if (newMinX < _minXData!) {
          newMinX = _minXData!;
          newMaxX = newMinX + visibleWidth;
        }
        if (newMaxX > _maxXData!) {
          newMaxX = _maxXData!;
          newMinX = newMaxX - visibleWidth;
          if (!_isAtLiveEdge) {
            _scrollToLive();
          }
        }

        _minXVisible = newMinX;
        _maxXVisible = newMaxX;
        _lastPanPosition = event.localPosition;
      });
    } else if (event is FlPanEndEvent) {
      _lastPanPosition = null;
    }
  }

  _SuhuRealtimeDataPoint _findClosestDataPoint(double targetX) {
    if (_suhuRealtimeDataPoints.isEmpty) {
      return _SuhuRealtimeDataPoint(timestamp: DateTime.now(), temperature: 0);
    }
    return _suhuRealtimeDataPoints.reduce((a, b) {
      final diffA = (a.timestamp.millisecondsSinceEpoch - targetX).abs();
      final diffB = (b.timestamp.millisecondsSinceEpoch - targetX).abs();
      return diffA < diffB ? a : b;
    });
  }

  Future<void> _startRealtimeUpdates() async {
    _realtimeTimer?.cancel();
    _clearRealtimeData();

    if (_selectedDevice == null || !mounted) return;

    try {
      final List<DeviceData> historicalData = await _deviceService
          .getDeviceData(_selectedDevice!.id, period: '24h');

      if (mounted && historicalData.isNotEmpty) {
        setState(() {
          _suhuRealtimeDataPoints = historicalData
              .map(
                (data) => _SuhuRealtimeDataPoint(
                  timestamp: data.timestamp,
                  temperature: data.temperature,
                ),
              )
              .toList();

          _suhuRealtimeDataPoints.sort(
            (a, b) => a.timestamp.compareTo(b.timestamp),
          );

          _minXData = _suhuRealtimeDataPoints
              .first
              .timestamp
              .millisecondsSinceEpoch
              .toDouble();
          _maxXData = _suhuRealtimeDataPoints
              .last
              .timestamp
              .millisecondsSinceEpoch
              .toDouble();

          _minXVisible = _minXData;
          _maxXVisible = _maxXData;
          _isAtLiveEdge = true;
        });
      }
    } catch (e) {
      _showError('Gagal memuat data grafik suhu 24 jam: $e');
    }

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
            timestamp: latestData.timestamp,
            temperature: latestData.temperature,
          );
          _suhuRealtimeDataPoints.add(newPoint);

          // Perbarui batas data terakhir
          _maxXData = newPoint.timestamp.millisecondsSinceEpoch.toDouble();

          // Manajemen memori: hapus data > 24 jam
          final cutoff = DateTime.now().subtract(
            const Duration(hours: 24, minutes: 5),
          );
          _suhuRealtimeDataPoints.removeWhere(
            (point) => point.timestamp.isBefore(cutoff),
          );

          // Perbarui batas data pertama jika ada data yang dihapus
          if (_suhuRealtimeDataPoints.isNotEmpty) {
            _minXData = _suhuRealtimeDataPoints
                .first
                .timestamp
                .millisecondsSinceEpoch
                .toDouble();
          }

          if (_isAtLiveEdge) {
            _updateVisibleXRangeForLive();
          }
        });
      }
    } catch (e) {
      print("Gagal mengambil data suhu real-time: $e");
    }
  }

  void _clearRealtimeData() => setState(() {
    _suhuRealtimeDataPoints = [];
    _minXData = null;
    _maxXData = null;
  });
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
    int crossAxisCount = isMobile ? 1 : 3;
    double childAspectRatio = isMobile ? 4.5 : 2.8;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: childAspectRatio,
      children: [
        _buildSummaryCard(
          'Suhu Rata-rata',
          _periodAvgTemp.toStringAsFixed(1),
          Icons.thermostat_outlined,
        ),
        _buildSummaryCard(
          'Suhu Tertinggi',
          _periodMaxTemp.toStringAsFixed(1),
          Icons.arrow_upward_rounded,
        ),
        _buildSummaryCard(
          'Suhu Terendah',
          _periodMinTemp.toStringAsFixed(1),
          Icons.arrow_downward_rounded,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(icon, size: 36, color: Colors.orange.shade700),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$value°C',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
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

    // Hitung minY dan maxY agar grafik tidak nabrak batas atas
    double? minY, maxY;
    if (spots.isNotEmpty) {
      minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      if (minY == maxY) {
        // Jika semua nilai sama, beri padding default
        minY = minY - 2;
        maxY = maxY + 2;
      } else {
        // Tambahkan padding 15% ke atas dan 20% ke bawah (lebih lebar dari sebelumnya)
        final range = maxY - minY;
        minY = minY - range * 0.20;
        maxY = maxY + range * 0.20;
      }
      if (minY < 0) minY = 0;
    }

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
                  : Stack(
                      children: [
                        LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            clipData: const FlClipData.all(),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) =>
                                    Colors.black87,
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
                                          text:
                                              '${spot.y.toStringAsFixed(1)}°C',
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
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    // Tampilkan label Y seperti biasa
                                    return Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                                axisNameWidget: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8.0,
                                    top: 8.0,
                                  ),
                                ),
                                axisNameSize: 4,
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
                      ],
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

    double minY = 0, maxY = 50;
    if (_suhuRealtimeDataPoints.isNotEmpty &&
        _minXVisible != null &&
        _maxXVisible != null) {
      final visiblePoints = _suhuRealtimeDataPoints.where((p) {
        final time = p.timestamp.millisecondsSinceEpoch.toDouble();
        return time >= _minXVisible! && time <= _maxXVisible!;
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
                const Flexible(
                  child: Text(
                    'Grafik Suhu 24 Jam Terakhir',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Row(
                  children: [
                    if (!_isAtLiveEdge)
                      TextButton(
                        onPressed: _scrollToLive,
                        child: const Text('Go to Live'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in),
                      onPressed: _zoomOut,
                      tooltip: 'Zoom In',
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_out),
                      onPressed: _zoomIn,
                      tooltip: 'Zoom Out',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.7,
              child: _suhuRealtimeDataPoints.isEmpty
                  ? const Center(child: Text('Menunggu data...'))
                  : LineChart(
                      // HAPUS GestureDetector yang sebelumnya membungkus widget ini
                      LineChartData(
                        minX: _minXVisible,
                        maxX: _maxXVisible,
                        minY: minY,
                        maxY: maxY,
                        clipData: const FlClipData.all(),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          handleBuiltInTouches: true,
                          touchCallback: (event, response) {
                            _handleTouchEvent(event);
                          },
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => Colors.black87,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final dataPoint = _findClosestDataPoint(spot.x);
                                return LineTooltipItem(
                                  '${DateFormat('d MMM, HH:mm:ss').format(dataPoint.timestamp)}\n',
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
                              interval:
                                  (_maxXVisible != null && _minXVisible != null)
                                  ? ((_maxXVisible! - _minXVisible!) / 5)
                                  : null,
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
                            curveSmoothness: 0.1,
                            color: Colors.orange.shade700,
                            barWidth: 2,
                            isStrokeCapRound: true,
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
