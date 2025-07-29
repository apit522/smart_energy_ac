// lib/screens/main/konsumsi/konsumsi_daya_content.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../models/device_model.dart';
import '../../../models/device_daily_summary_model.dart';
import '../../../services/device_service.dart';
import '../../../utils/app_colors.dart';
import 'top_konsumsi_bulanan_content.dart';

// Enum untuk mengelola halaman yang aktif
enum _KonsumsiDayaPage { analisis, topBulanan }

// Kelas data untuk grafik real-time, menyimpan timestamp
class _RealtimeDataPoint {
  final DateTime timestamp;
  final double watt;

  _RealtimeDataPoint({required this.timestamp, required this.watt});

  // Fungsi toJson dan fromJson tidak lagi diperlukan karena tidak ada persistensi
  // namun tetap disimpan jika dibutuhkan di masa depan.
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

  // State Halaman
  _KonsumsiDayaPage _selectedPage = _KonsumsiDayaPage.analisis;

  // State UI
  bool _isLoading = true;
  List<Device> _devices = [];
  Device? _selectedDevice;
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 31)),
    end: DateTime.now(),
  );

  // State Data
  List<DeviceDailySummary> _dailySummaries = [];
  double _totalKwh = 0.0,
      _avgWatt = 0.0,
      _minWatt = 0.0,
      _maxWatt = 0.0,
      _estimatedCost = 0.0;

  // State Grafik Real-time
  Timer? _realtimeTimer;
  List<_RealtimeDataPoint> _realtimeDataPoints = [];

  // State untuk panning dan viewport
  static const Duration _visibleDuration = Duration(minutes: 5);
  double? _minXVisible, _maxXVisible;
  bool _isAtLiveEdge = true;
  Offset? _lastPanPosition;

  // ▼▼▼ TAMBAHKAN: State untuk batas zoom ▼▼▼
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
      _minWatt = 0;
      _maxWatt = 0;
      _estimatedCost = 0;
      return;
    }

    _totalKwh = _dailySummaries.map((s) => s.totalKwh).reduce((a, b) => a + b);
    final count = _dailySummaries.length;
    _avgWatt =
        _dailySummaries.map((s) => s.avgWatt).reduce((a, b) => a + b) / count;
    _minWatt = _dailySummaries.map((s) => s.minWatt).reduce(min);
    _maxWatt = _dailySummaries.map((s) => s.maxWatt).reduce(max);
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
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
  }

  // --- LOGIKA GRAFIK REAL-TIME YANG DIPERBARUI ---

  void _updateVisibleXRangeForLive() {
    if (_realtimeDataPoints.isEmpty) return;
    final lastTimestamp = _realtimeDataPoints.last.timestamp;
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

  // ▼▼▼ GANTI: Fungsi handle zoom dengan versi yang sudah ada pembatasnya ▼▼▼
  void _handleZoom(double scale) {
    if (_minXVisible == null ||
        _maxXVisible == null ||
        _minXData == null ||
        _maxXData == null) {
      return;
    }

    final totalDataRange = _maxXData! - _minXData!;
    final center = (_maxXVisible! + _minXVisible!) / 2;
    double newRange = (_maxXVisible! - _minXVisible!) / scale;

    if (newRange > totalDataRange) {
      newRange = totalDataRange;
    }

    final minVisibleRange = Duration(minutes: 1).inMilliseconds;
    if (newRange < minVisibleRange) {
      newRange = minVisibleRange.toDouble();
    }

    setState(() {
      _minXVisible = center - newRange / 2;
      _maxXVisible = center + newRange / 2;

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

  // ▼▼▼ GANTI: Fungsi _startRealtimeUpdates untuk menyimpan batas data ▼▼▼
  Future<void> _startRealtimeUpdates() async {
    _realtimeTimer?.cancel();
    _clearRealtimeData();

    if (_selectedDevice == null || !mounted) return;

    try {
      final historicalData = await _deviceService.getDeviceData(
        _selectedDevice!.id,
        period: '24h',
      );

      if (mounted && historicalData.isNotEmpty) {
        setState(() {
          _realtimeDataPoints = historicalData
              .map(
                (data) => _RealtimeDataPoint(
                  timestamp: data.timestamp,
                  watt: data.watt,
                ),
              )
              .toList();

          _realtimeDataPoints.sort(
            (a, b) => a.timestamp.compareTo(b.timestamp),
          );

          _minXData = _realtimeDataPoints.first.timestamp.millisecondsSinceEpoch
              .toDouble();
          _maxXData = _realtimeDataPoints.last.timestamp.millisecondsSinceEpoch
              .toDouble();

          _minXVisible = _minXData;
          _maxXVisible = _maxXData;
          _isAtLiveEdge = true;
        });
      }
    } catch (e) {
      _showError('Gagal memuat data grafik 24 jam: $e');
    }

    _realtimeTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchLatestWattData();
    });
  }

  // ▼▼▼ GANTI: Fungsi _fetchLatestWattData dengan manajemen memori & update batas ▼▼▼
  Future<void> _fetchLatestWattData() async {
    if (_selectedDevice == null || !mounted) return;

    try {
      final latestData = await _deviceService.getLatestData(
        _selectedDevice!.id,
      );
      if (latestData != null) {
        setState(() {
          final newPoint = _RealtimeDataPoint(
            timestamp: latestData.timestamp,
            watt: latestData.watt,
          );
          _realtimeDataPoints.add(newPoint);

          _maxXData = newPoint.timestamp.millisecondsSinceEpoch.toDouble();

          final cutoff = DateTime.now().subtract(
            const Duration(hours: 24, minutes: 5),
          );
          _realtimeDataPoints.removeWhere(
            (point) => point.timestamp.isBefore(cutoff),
          );

          if (_realtimeDataPoints.isNotEmpty) {
            _minXData = _realtimeDataPoints
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
      print("Gagal mengambil data real-time: $e");
    }
  }

  // ▼▼▼ GANTI: Fungsi _clearRealtimeData untuk mereset batas data ▼▼▼
  void _clearRealtimeData() => setState(() {
    _realtimeDataPoints = [];
    _minXData = null;
    _maxXData = null;
  });

  _RealtimeDataPoint _findClosestDataPoint(double targetX) {
    if (_realtimeDataPoints.isEmpty) {
      return _RealtimeDataPoint(timestamp: DateTime.now(), watt: 0);
    }
    return _realtimeDataPoints.reduce((a, b) {
      final diffA = (a.timestamp.millisecondsSinceEpoch - targetX).abs();
      final diffB = (b.timestamp.millisecondsSinceEpoch - targetX).abs();
      return diffA < diffB ? a : b;
    });
  }

  // --- UI UTAMA & WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 850;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildPageSelector(isMobile),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _selectedPage == _KonsumsiDayaPage.analisis
                  ? _buildAnalisisContent(isMobile)
                  : TopKonsumsiBulananContent(
                      devices: _devices,
                      selectedDevice: _selectedDevice,
                      onDeviceChanged: (device) {
                        if (device != null &&
                            device.id != _selectedDevice?.id) {
                          setState(() => _selectedDevice = device);
                        }
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPageSelector(bool isMobile) {
    return ToggleButtons(
      direction: isMobile ? Axis.vertical : Axis.horizontal,
      isSelected: [
        _selectedPage == _KonsumsiDayaPage.analisis,
        _selectedPage == _KonsumsiDayaPage.topBulanan,
      ],
      onPressed: (index) {
        setState(() {
          _selectedPage = _KonsumsiDayaPage.values[index];
        });
      },
      borderRadius: BorderRadius.circular(8.0),
      selectedBorderColor: AppColors.primaryColor,
      selectedColor: Colors.white,
      fillColor: AppColors.primaryColor,
      color: AppColors.primaryColor,
      constraints: const BoxConstraints(minHeight: 40.0, minWidth: 150.0),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Analisis Konsumsi Daya'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Top Konsumsi Bulanan'),
        ),
      ],
    );
  }

  Widget _buildAnalisisContent(bool isMobile) {
    return Column(
      children: [
        _buildFilterBar(isMobile: isMobile),
        const SizedBox(height: 24),
        _isLoading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
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
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
          if (_selectedPage == _KonsumsiDayaPage.analisis) {
            _fetchSummaryData();
          }
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

    // Data untuk semua card
    final cards = [
      _buildCompactSummaryCard(
        'Total',
        _totalKwh.toStringAsFixed(2),
        'kWh',
        Icons.power,
      ),
      _buildCompactSummaryCard(
        'Rata2',
        _avgWatt.toStringAsFixed(1),
        'Watt',
        Icons.speed_outlined,
      ),
      _buildCompactSummaryCard(
        'Biaya',
        currencyFormatter.format(_estimatedCost),
        '',
        Icons.payments_outlined,
      ),
      _buildCompactSummaryCard(
        'Min',
        _minWatt.toStringAsFixed(1),
        'Watt',
        Icons.arrow_downward,
      ),
      _buildCompactSummaryCard(
        'Max',
        _maxWatt.toStringAsFixed(1),
        'Watt',
        Icons.arrow_upward,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - (isMobile ? 32 : 48);
        final cardWidth = (availableWidth / (isMobile ? 3 : 5)) - 12;

        return isMobile
            ? Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: cards
                        .sublist(0, 3)
                        .map((card) => SizedBox(width: cardWidth, child: card))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: cards
                        .sublist(3)
                        .map((card) => SizedBox(width: cardWidth, child: card))
                        .toList(),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: cards
                      .map((card) => SizedBox(width: cardWidth, child: card))
                      .toList(),
                ),
              );
      },
    );
  }

  Widget _buildCompactSummaryCard(
    String title,
    String value,
    String unit,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: AppColors.primaryColor),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$value${unit.isNotEmpty ? ' $unit' : ''}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
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
          // ▼▼▼ UBAH DI SINI: tambahkan parameter isMobile ▼▼▼
          _buildDailyChartCard(isMobile: isMobile),
          const SizedBox(height: 24),
          _buildRealtimeChartCard(),
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ▼▼▼ UBAH DI SINI: tambahkan parameter isMobile ▼▼▼
          Expanded(child: _buildDailyChartCard(isMobile: isMobile)),
          const SizedBox(width: 24),
          Expanded(child: _buildRealtimeChartCard()),
        ],
      );
    }
  }

  Widget _buildDailyChartCard({required bool isMobile}) {
    // Hitung minY dan maxY agar bar tidak mentok ke batas atas
    double minY = 0;
    double maxY = 1;
    if (_dailySummaries.isNotEmpty) {
      minY = 0;
      maxY = _dailySummaries.map((s) => s.totalKwh).reduce(max);
      // Tambahkan padding 20% ke atas
      maxY = maxY + (maxY * 0.2);
      // Jika semua nilai sama, beri padding default
      if (_dailySummaries.every((s) => s.totalKwh == maxY)) {
        maxY += 2;
      }
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
                        minY: minY,
                        maxY: maxY,
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
                                // ▼▼▼ UBAH DI SINI: Atur lebar batang secara dinamis ▼▼▼
                                width: isMobile
                                    ? 7
                                    : 12, // Lebih kecil di mobile
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

    double minY = 0, maxY = 100;
    if (_realtimeDataPoints.isNotEmpty &&
        _minXVisible != null &&
        _maxXVisible != null) {
      final visiblePoints = _realtimeDataPoints.where((p) {
        final time = p.timestamp.millisecondsSinceEpoch.toDouble();
        return time >= _minXVisible! && time <= _maxXVisible!;
      });

      if (visiblePoints.isNotEmpty) {
        final wattValues = visiblePoints.map((p) => p.watt);
        minY = wattValues.reduce(min);
        maxY = wattValues.reduce(max);
        if (minY == maxY) {
          minY = max(0, minY - 20);
          maxY += 20;
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
                    'Grafik Daya 24 Jam Terakhir (Watt)',
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
              child: _realtimeDataPoints.isEmpty
                  ? const Center(child: Text('Menunggu data...'))
                  : LineChart(
                      // DIHAPUS: GestureDetector yang membungkus ini
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
                        // ... sisa kode LineChartData Anda ...
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
                            color: AppColors.accentColor,
                            barWidth: 2,
                            isStrokeCapRound: true,
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
