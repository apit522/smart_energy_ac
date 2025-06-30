import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/device_model.dart';
import '../../../models/device_data_model.dart';
import '../../../models/device_data_hourly_model.dart';
import '../../../models/device_trending_data_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/device_service.dart';
import '../../../utils/app_colors.dart';
import '../widgets/welcome_banner.dart';
import '../widgets/prediction_chart_card.dart';

class ActualDashboardContent extends StatefulWidget {
  const ActualDashboardContent({super.key});

  @override
  State<ActualDashboardContent> createState() => _ActualDashboardContentState();
}

class _ActualDashboardContentState extends State<ActualDashboardContent> {
  // Services
  final AuthService _authService = AuthService();
  final DeviceService _deviceService = DeviceService();

  // State untuk UI
  String _userName = 'User';
  bool _isLoading = true;
  Timer? _realtimeTimer; // Untuk data real-time (tiap 30 detik)
  Timer? _refreshTimer; // Untuk data tren & harian (tiap 5 menit)

  // State untuk filter
  List<Device> _devices = [];
  Device? _selectedDevice;
  DateTime _selectedDate = DateTime.now();

  // State untuk data
  DeviceData? _latestData;
  List<FlSpot> _lineChartSpots = []; // Diubah untuk LineChart
  DeviceTrendingData? _trendingData;
  double _totalKwhToday = 0.0;
  double _totalCostToday = 0.0;

  // StreamController untuk data realtime
  final StreamController<DeviceData?> _realtimeDataController =
      StreamController<DeviceData?>.broadcast();

  @override
  void initState() {
    super.initState();
    _initializeDashboard();

    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_selectedDevice != null) {
        _fetchTrendingData(showLoading: false);
        if (_isToday(_selectedDate)) {
          _fetchHourlyData(showLoading: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _refreshTimer?.cancel();
    _realtimeDataController.close();
    super.dispose();
  }

  // --- LOGIKA PENGAMBILAN & PEMROSESAN DATA ---

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _initializeDashboard() async {
    setState(() => _isLoading = true);
    try {
      final userDetails = await _authService.getUserDetails();
      _devices = await _deviceService.getDevices();

      if (mounted) {
        setState(() {
          _userName = userDetails['name'] ?? 'User';
          if (_devices.isNotEmpty) _selectedDevice = _devices.first;
        });

        if (_selectedDevice != null) {
          await Future.wait([
            _fetchTrendingData(showLoading: false),
            _fetchHourlyData(showLoading: false),
          ]);
          _startRealtimeUpdates(); // Memulai refresh otomatis
        }
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error memuat data awal: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAllDataForDevice() async {
    if (_selectedDevice == null) return;
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchTrendingData(showLoading: false),
        _fetchHourlyData(showLoading: false),
      ]);
      _startRealtimeUpdates();
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error memuat data perangkat: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTrendingData({bool showLoading = true}) async {
    if (_selectedDevice == null) return;
    if (showLoading) setState(() => _isLoading = true);
    try {
      final data = await _deviceService.getTrendingData(_selectedDevice!.id);
      if (mounted) setState(() => _trendingData = data);
    } catch (e) {
      print('Error fetching trending data: $e'); // Log untuk debug
    } finally {
      if (showLoading && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHourlyData({bool showLoading = true}) async {
    if (_selectedDevice == null) return;
    if (showLoading) setState(() => _isLoading = true);
    try {
      final data = await _deviceService.getHourlyData(
        _selectedDevice!.id,
        _selectedDate,
      );
      if (mounted) _processHourlyData(data);
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error memuat data grafik: $e');
    } finally {
      if (showLoading && mounted) setState(() => _isLoading = false);
    }
  }

  void _startRealtimeUpdates() {
    _realtimeTimer?.cancel();
    _fetchLatestData(); // Panggil sekali di awal
    _realtimeTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      print("Fetching latest data..."); // Log untuk menandakan refresh otomatis
      _fetchLatestData();
    });
  }

  Future<void> _fetchLatestData() async {
    if (_selectedDevice == null) return;
    try {
      final latest = await _deviceService.getLatestData(_selectedDevice!.id);
      if (mounted) {
        setState(() => _latestData = latest);
        _realtimeDataController.add(latest); // Update stream dengan data baru
      }
    } catch (e) {
      print("Gagal memuat data real-time: $e");
    }
  }

  void _processHourlyData(List<DeviceDataHourly> data) {
    if (!mounted) return;

    final spots = List.generate(24, (hour) {
      final dataPoint = data.where((d) => d.hourTimestamp.hour == hour);
      if (dataPoint.isNotEmpty) {
        return FlSpot(hour.toDouble(), dataPoint.first.kwhTotal);
      }
      return FlSpot(hour.toDouble(), 0);
    });

    setState(() {
      _lineChartSpots = spots;
      _totalKwhToday = data.isEmpty
          ? 0.0
          : data.map((d) => d.kwhTotal).reduce((a, b) => a + b);
      _totalCostToday = data.isEmpty
          ? 0.0
          : data.map((d) => d.costTotal).reduce((a, b) => a + b);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // --- EVENT HANDLERS ---

  void _onDeviceChanged(Device? device) {
    if (device != null && device != _selectedDevice) {
      setState(() {
        _selectedDevice = device;
        _latestData = null;
        _lineChartSpots = [];
        _trendingData = null;
        _totalKwhToday = 0.0;
        _totalCostToday = 0.0;
      });
      _fetchAllDataForDevice();
    }
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchHourlyData();
    }
  }

  void _showEerInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Energy Efficiency Ratio (EER)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Energy Efficiency Ratio (EER) adalah perbandingan kapasitas pendingin dengan input daya, semakin tinggi nilai EER maka makin efisien AC tersebut.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border(
                        left: BorderSide(
                          color: AppColors.primaryColor,
                          width: 4,
                        ),
                      ),
                    ),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontFamily: 'Poppins',
                        ),
                        children: [
                          TextSpan(
                            text: 'EER: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text:
                                'Efek pendinginan (Btu/Jam) / Energi Input (W)',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Berdasarkan Peraturan Menteri ESDM Nomor 57 Tahun 2017:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Table(
                    border: TableBorder(
                      horizontalInside: BorderSide(
                        width: 1,
                        color: Colors.grey.shade200,
                      ),
                    ),
                    columnWidths: const {
                      0: IntrinsicColumnWidth(),
                      1: FlexColumnWidth(),
                      2: IntrinsicColumnWidth(),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.8),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              'Rating',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              'Rentang EER',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              'Kategori',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      _buildEerTableRow(
                        '★',
                        '8.53 < EER < 9.01',
                        'Kurang Efisien',
                      ),
                      _buildEerTableRow(
                        '★★',
                        '9.01 < EER < 9.96',
                        'Cukup Efisien',
                      ),
                      _buildEerTableRow('★★★', '9.96 < EER < 10.41', 'Efisien'),
                      _buildEerTableRow(
                        '★★★★',
                        'EER > 10.41',
                        'Sangat Efisien',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border(
                        left: BorderSide(color: Colors.blue.shade400, width: 4),
                      ),
                    ),
                    child: const Text(
                      'Catatan: Semakin tinggi nilai EER, semakin hemat penggunaan energi AC Anda. Pilih AC dengan rating bintang lebih tinggi untuk penghematan jangka panjang.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TableRow _buildEerTableRow(String rating, String range, String category) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            rating,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.all(10), child: Text(range)),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            category,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WelcomeBanner(userName: _userName),
          const SizedBox(height: 24),
          _buildFilterBar(),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(heightFactor: 10, child: CircularProgressIndicator())
          else if (_selectedDevice == null)
            const Center(
              heightFactor: 10,
              child: Text(
                "Silakan tambah perangkat.",
                textAlign: TextAlign.center,
              ),
            )
          else
            _buildDashboardContent(),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Tren Penggunaan'),
        _buildTrendingCards(),
        const SizedBox(height: 24),
        _buildSectionTitle('Status & Ringkasan Harian'),
        _buildDailyAndRealtimeCards(),
        const SizedBox(height: 24),
        _buildSectionTitle('Analisis Konsumsi'),
        _buildChartWidgets(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // UPDATED: Card color set to white
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            const Icon(Icons.devices, color: AppColors.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: DropdownButtonHideUnderline(
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
                  onChanged: _onDeviceChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(DateFormat('d MMM yy').format(_selectedDate)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyAndRealtimeCards() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth > 500
                  ? (constraints.maxWidth / 2 - 8)
                  : double.infinity,
              child: _buildRealtimeCard(),
            );
          },
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth > 500
                  ? (constraints.maxWidth / 2 - 8)
                  : double.infinity,
              child: _buildDailySummaryCard(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRealtimeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // UPDATED: Card color set to white
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Status Real-time',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                StreamBuilder<DeviceData?>(
                  stream: _realtimeDataController.stream,
                  builder: (context, snapshot) {
                    final lastUpdate = _latestData?.timestamp ?? DateTime.now();
                    return Text(
                      'Terakhir: ${DateFormat('HH:mm:ss').format(lastUpdate)}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            _buildRealtimeMetricRow(
              'Daya',
              _latestData?.watt,
              'Watt',
              Icons.bolt,
            ),
            const SizedBox(height: 8),
            _buildRealtimeMetricRow(
              'Tegangan',
              _latestData?.voltage,
              'V',
              Icons.offline_bolt,
            ),
            const SizedBox(height: 8),
            _buildRealtimeMetricRow(
              'Arus',
              _latestData?.current,
              'A',
              Icons.electric_bolt,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeMetricRow(
    String label,
    double? value,
    String unit,
    IconData icon,
  ) {
    return StreamBuilder<DeviceData?>(
      stream: _realtimeDataController.stream,
      builder: (context, snapshot) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    child: child,
                  ),
                );
              },
              child: Text(
                key: ValueKey<double?>(value),
                value != null
                    ? '${value.toStringAsFixed(1)} $unit'
                    : '-- $unit',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDailySummaryCard() {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // UPDATED: Card color set to white
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Harian',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const Divider(height: 20),
            _buildMetricRow(
              'Total Energi',
              _totalKwhToday.toStringAsFixed(2),
              'kWh',
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              'Perkiraan Biaya',
              currencyFormatter.format(_totalCostToday),
              '',
            ),
            const SizedBox(height: 8),
            _buildMetricRow(
              'Suhu Rata-rata',
              '${_latestData?.temperature.toStringAsFixed(1) ?? '--'}',
              '°C',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(
          '$value $unit',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildChartWidgets() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth > 800
                  ? (constraints.maxWidth / 2 - 8)
                  : double.infinity,
              child: _buildHourlyLineChartCard(),
            );
          },
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth > 800
                  ? (constraints.maxWidth / 2 - 8)
                  : double.infinity,
              child: PredictionChartCard(deviceId: _selectedDevice!.id),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHourlyLineChartCard() {
    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // UPDATED: Card color set to white
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: _lineChartSpots.isEmpty
              ? const Center(
                  child: Text("Tidak ada data konsumsi pada tanggal ini."),
                )
              : LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 23,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      getDrawingHorizontalLine: (value) => const FlLine(
                        color: Color(0xff37434d),
                        strokeWidth: 0.2,
                      ),
                      getDrawingVerticalLine: (value) => const FlLine(
                        color: Color(0xff37434d),
                        strokeWidth: 0.2,
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
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(2),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 4,
                          getTitlesWidget: (value, meta) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                value.toInt().toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
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
                        color: const Color(0xff37434d),
                        width: 1,
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _lineChartSpots,
                        isCurved: true,
                        color: AppColors.primaryColor,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primaryColor.withOpacity(0.3),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) =>
                            Colors.blueGrey.withOpacity(0.8),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((LineBarSpot spot) {
                            final jam = spot.x.toInt();
                            final kwh = spot.y;
                            return LineTooltipItem(
                              'Jam ${jam.toString().padLeft(2, '0')}:00\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              children: [
                                TextSpan(
                                  text: '${kwh.toStringAsFixed(3)} kWh',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // UPDATED: Card color is now white, but text color remains dynamic for status indication
  Widget _buildEfficiencyCard() {
    final double eer = _trendingData?.currentEfficiency ?? 0.0;

    String starRating = 'N/A';
    String efficiencyLabel = 'Data Tidak Cukup';
    String recommendation =
        'Nyalakan AC Anda untuk mendapatkan data efisiensi.';
    Color textColor = Colors.grey.shade800;

    if (eer > 0) {
      if (eer > 10.41) {
        starRating = '★★★★';
        efficiencyLabel = 'Sangat Efisien';
        textColor = Colors.green.shade800;
        recommendation =
            'Kerja bagus! Pertahankan dengan membersihkan filter secara rutin.';
      } else if (eer > 9.96) {
        starRating = '★★★';
        efficiencyLabel = 'Efisien';
        textColor = Colors.blue.shade800;
        recommendation =
            'Performa AC Anda baik. Pastikan tidak ada kebocoran udara di ruangan.';
      } else if (eer > 9.01) {
        starRating = '★★';
        efficiencyLabel = 'Cukup Efisien';
        textColor = Colors.orange.shade800;
        recommendation =
            'Efisiensi standar. Coba naikkan suhu 1-2° untuk penghematan energi.';
      } else if (eer > 8.53) {
        starRating = '★';
        efficiencyLabel = 'Kurang Efisien';
        textColor = Colors.deepOrange.shade800;
        recommendation =
            'Performa di bawah standar. Segera bersihkan filter & periksa unit outdoor.';
      } else {
        starRating = 'Tidak Ada Bintang';
        efficiencyLabel = 'Tidak Efisien';
        textColor = Colors.red.shade800;
        recommendation =
            'Peringatan: Efisiensi sangat rendah! Pertimbangkan untuk servis unit AC Anda.';
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Status Efisiensi (EER)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    color: textColor.withOpacity(0.7),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Apa itu EER?',
                  onPressed: () {
                    _showEerInfoDialog(context);
                  },
                ),
              ],
            ),
            const Spacer(),
            Text(
              starRating,
              style: TextStyle(
                fontSize: 28,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              efficiencyLabel,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            // -- BARIS BARU DITAMBAHKAN DI SINI --
            // Hanya tampilkan jika ada nilai EER yang valid
            if (eer > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'Nilai EER: ${eer.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const Spacer(),
            const Divider(),
            Text(
              recommendation,
              style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.9)),
            ),
          ],
        ),
      ),
    );
  }

  // UPDATED: Layout logic is updated for responsiveness and balanced width
  Widget _buildTrendingCards() {
    if (_trendingData == null) {
      return const Center(
        child: Text("Belum ada data tren untuk perangkat ini."),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tampilan untuk layar lebar (misal > 900px)
        if (constraints.maxWidth > 900) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Kolom 1: Kartu Efisiensi
                Expanded(
                  // UPDATED: flex factor changed to 1 for balanced width
                  flex: 1,
                  child: _buildEfficiencyCard(),
                ),
                const SizedBox(width: 16),
                // Kolom 2: Tiga kartu ringkasan
                Expanded(
                  // UPDATED: flex factor changed to 1 for balanced width
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          '24 Jam Terakhir',
                          _trendingData!.last24hKwh,
                          'kWh',
                          Icons.hourglass_bottom,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          '7 Hari Terakhir',
                          _trendingData!.last7dKwh,
                          'kWh',
                          Icons.date_range,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          '30 Hari Terakhir',
                          _trendingData!.last30dKwh,
                          'kWh',
                          Icons.calendar_month,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Tampilan untuk layar kecil (mobile)
        return Column(
          children: [
            _buildEfficiencyCard(),
            const SizedBox(height: 16),
            _buildSummaryCard(
              '24 Jam Terakhir',
              _trendingData!.last24hKwh,
              'kWh',
              Icons.hourglass_bottom,
              Colors.orange,
            ),
            const SizedBox(height: 16),
            _buildSummaryCard(
              '7 Hari Terakhir',
              _trendingData!.last7dKwh,
              'kWh',
              Icons.date_range,
              Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildSummaryCard(
              '30 Hari Terakhir',
              _trendingData!.last30dKwh,
              'kWh',
              Icons.calendar_month,
              Colors.green,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    double value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // UPDATED: Card color set to white
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ),
                Icon(icon, color: color),
              ],
            ),
            Text(
              '${value.toStringAsFixed(2)} $unit',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
