import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/device_model.dart';
import '../../../models/device_monthly_summary_model.dart';
import '../../../services/device_service.dart';
import '../../../utils/app_colors.dart';

class TopKonsumsiBulananContent extends StatefulWidget {
  final List<Device> devices;
  final Device? selectedDevice;
  final ValueChanged<Device?> onDeviceChanged;

  const TopKonsumsiBulananContent({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.onDeviceChanged,
  });

  @override
  State<TopKonsumsiBulananContent> createState() =>
      _TopKonsumsiBulananContentState();
}

class _TopKonsumsiBulananContentState extends State<TopKonsumsiBulananContent> {
  final DeviceService _deviceService = DeviceService();

  // State
  bool _isLoading = true;
  int _selectedYear = DateTime.now().year;
  List<DeviceMonthlySummary> _monthlySummaries = [];
  double _yearlyAvgWatt = 0.0;
  double _yearlyPeakWatt = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.selectedDevice != null) {
      _fetchMonthlyData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant TopKonsumsiBulananContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jika perangkat yang dipilih berubah dari parent, fetch data baru
    if (widget.selectedDevice != oldWidget.selectedDevice &&
        widget.selectedDevice != null) {
      _fetchMonthlyData();
    }
  }

  Future<void> _fetchMonthlyData() async {
    if (widget.selectedDevice == null) return;
    setState(() => _isLoading = true);

    try {
      final summaries = await _deviceService.getMonthlySummary(
        widget.selectedDevice!.id,
        year: _selectedYear,
      );

      // Urutkan data dari totalKwh tertinggi ke terendah
      summaries.sort((a, b) => b.totalKwh.compareTo(a.totalKwh));

      setState(() {
        _monthlySummaries = summaries;
        _calculateYearlyStats();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data bulanan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateYearlyStats() {
    if (_monthlySummaries.isEmpty) {
      _yearlyAvgWatt = 0.0;
      _yearlyPeakWatt = 0.0;
      return;
    }
    // Rata-rata dari semua rata-rata bulanan
    _yearlyAvgWatt =
        _monthlySummaries.map((s) => s.avgWatt).reduce((a, b) => a + b) /
        _monthlySummaries.length;
    // Nilai puncak tertinggi dari semua puncak bulanan
    _yearlyPeakWatt = _monthlySummaries.map((s) => s.peakWatt).reduce(max);
  }

  // --- WIDGET BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 850;

        return Column(
          children: [
            _buildFilterBar(),
            const SizedBox(height: 24),
            _isLoading
                ? const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : widget.selectedDevice == null
                ? const Expanded(
                    child: Center(
                      child: Text(
                        'Pilih perangkat terlebih dahulu.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                : Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            _buildSummaryCards(isMobile: isMobile),
                            const SizedBox(height: 24),
                            _buildMonthlyChartCard(),
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

  Widget _buildFilterBar() {
    // Membuat daftar tahun, contoh: dari 2022 hingga tahun ini
    final currentYear = DateTime.now().year;
    final yearList = List.generate(
      currentYear - 2021,
      (index) => currentYear - index,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            // Dropdown Perangkat
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Device>(
                  value: widget.selectedDevice,
                  isExpanded: true,
                  hint: const Text('Pilih Perangkat'),
                  items: widget.devices
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(d.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: widget.onDeviceChanged,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Dropdown Tahun
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                items: yearList
                    .map(
                      (y) =>
                          DropdownMenuItem(value: y, child: Text(y.toString())),
                    )
                    .toList(),
                onChanged: (year) {
                  if (year != null && year != _selectedYear) {
                    setState(() {
                      _selectedYear = year;
                    });
                    _fetchMonthlyData();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards({required bool isMobile}) {
    int crossAxisCount = isMobile ? 2 : 2; // Hanya 2 kartu
    double childAspectRatio = isMobile ? 2.2 : 4;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: childAspectRatio,
      children: [
        _buildSummaryCard(
          'Rata-rata Watt',
          '${_yearlyAvgWatt.toStringAsFixed(1)} W',
          Icons.speed_outlined,
        ),
        _buildSummaryCard(
          'Puncak Watt',
          '${_yearlyPeakWatt.toStringAsFixed(1)} W',
          Icons.bolt,
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
        padding: const EdgeInsets.all(16.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(icon, size: 32, color: AppColors.primaryColor),
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
                    value,
                    style: const TextStyle(
                      fontSize: 20,
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

  Widget _buildMonthlyChartCard() {
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
              'Top Konsumsi Bulanan (kWh)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.7,
              child: _monthlySummaries.isEmpty
                  ? const Center(
                      child: Text('Tidak ada data untuk ditampilkan.'),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (touchedSpot) => Colors.black87,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final summary = _monthlySummaries[groupIndex];
                              return BarTooltipItem(
                                '${_getMonthName(summary.summaryMonth)}\n',
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
                                // value adalah indeks 0, 1, 2, ...
                                final index = value.toInt();
                                if (index < _monthlySummaries.length) {
                                  final month =
                                      _monthlySummaries[index].summaryMonth;
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 4,
                                    child: Text(
                                      _getMonthName(month, short: true),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        barGroups: _monthlySummaries.asMap().entries.map((
                          entry,
                        ) {
                          final index = entry.key; // 0, 1, 2, ...
                          final summary = entry.value;
                          return BarChartGroupData(
                            x: index, // Gunakan indeks sebagai nilai x
                            barRods: [
                              BarChartRodData(
                                toY: summary.totalKwh,
                                color: AppColors.primaryColor,
                                width: 20,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
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

  String _getMonthName(int month, {bool short = false}) {
    final format = short ? 'MMM' : 'MMMM';
    // Buat tanggal dummy untuk mendapatkan nama bulan dari int
    return DateFormat(format, 'id_ID').format(DateTime(2022, month, 1));
  }
}
