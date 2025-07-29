// lib\screens\dashboard\pages\top_konsumsi_bulanan_content.dart
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
  double _yearlyTotalKwh = 0.0;
  double _yearlyAvgTemp = 0.0;

  // --- DITAMBAHKAN: Daftar warna untuk grafik donat ---
  final List<Color> _pieColors = [
    Colors.blue.shade400,
    Colors.green.shade400,
    Colors.orange.shade400,
    Colors.red.shade400,
    Colors.purple.shade400,
    Colors.amber.shade400,
    Colors.cyan.shade400,
    Colors.pink.shade300,
    Colors.teal.shade400,
    Colors.indigo.shade400,
    Colors.lime.shade600,
    Colors.brown.shade400,
  ];

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
      _yearlyTotalKwh = 0.0;
      _yearlyAvgTemp = 0.0;
      return;
    }

    _yearlyTotalKwh = _monthlySummaries
        .map((s) => s.totalKwh)
        .reduce((a, b) => a + b);
    _yearlyAvgWatt =
        _monthlySummaries.map((s) => s.avgWatt).reduce((a, b) => a + b) /
        _monthlySummaries.length;
    _yearlyAvgTemp =
        _monthlySummaries.map((s) => s.avgTemperature).reduce((a, b) => a + b) /
        _monthlySummaries.length;
    _yearlyPeakWatt = _monthlySummaries.map((s) => s.peakWatt).reduce(max);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 850;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: _buildContentBody(isMobile),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- DIPERBARUI: Mengatur posisi widget baru di layout ---
  Widget _buildContentBody(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _buildSummaryCards(isMobile: true),
          const SizedBox(height: 24),
          _buildMonthlyConsumptionList(),
          const SizedBox(height: 24),
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: _buildMonthlyConsumptionList()),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildSummaryCards(isMobile: false),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildFilterBar() {
    final currentYear = DateTime.now().year;
    final yearList = List.generate(3, (index) => currentYear - index);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
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
                    setState(() => _selectedYear = year);
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
    double childAspectRatio = isMobile ? 1.8 : 2.0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: childAspectRatio,
      children: [
        _buildSummaryCard(
          'Total Konsumsi',
          '${_yearlyTotalKwh.toStringAsFixed(2)} kWh',
          Icons.electric_bolt_outlined,
        ),
        _buildSummaryCard(
          'Rata-rata Watt Hour',
          '${_yearlyAvgWatt.toStringAsFixed(1)} Wh',
          Icons.speed_outlined,
        ),
        _buildSummaryCard(
          'Puncak Daya',
          '${_yearlyPeakWatt.toStringAsFixed(1)} W',
          Icons.flash_on_outlined,
        ),
        _buildSummaryCard(
          'Rata-rata Suhu',
          '${_yearlyAvgTemp.toStringAsFixed(1)} °C',
          Icons.thermostat_outlined,
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

  // --- DIPERBARUI: Mengganti BarChart menjadi daftar kustom ---
  Widget _buildMonthlyConsumptionList() {
    if (_monthlySummaries.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        child: Container(
          height: 400,
          alignment: Alignment.center,
          child: const Text('Tidak ada data untuk ditampilkan.'),
        ),
      );
    }
    final double maxKwh = _monthlySummaries.map((s) => s.totalKwh).reduce(max);

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
              'Top Konsumsi Bulanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ..._monthlySummaries.asMap().entries.map((entry) {
              final index = entry.key;
              final summary = entry.value;
              final barWidthFactor = (maxKwh > 0)
                  ? summary.totalKwh / maxKwh
                  : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        _getMonthName(summary.summaryMonth),
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: barWidthFactor.toDouble(),
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: _pieColors[index % _pieColors.length],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${summary.totalKwh.toStringAsFixed(1)} kWh',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month, {bool short = false}) {
    final format = short ? 'MMM' : 'MMMM';
    return DateFormat(format, 'id_ID').format(DateTime(2022, month, 1));
  }
}
