<<<<<<< Updated upstream
// lib/screens/dashboard/pages/actual_dashboard_content.dart
import 'package:flutter/material.dart';
import '../widgets/welcome_banner.dart'; // Import widget banner
import '../../../services/auth_service.dart'; // Untuk mendapatkan nama user
=======
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:fl_chart/fl_chart.dart';

// // Pastikan semua path import ini sudah benar sesuai struktur proyek Anda
// import '../../../models/device_model.dart';
// import '../../../models/device_data_model.dart';
// import '../../../models/device_data_hourly_model.dart';
// import '../../../services/auth_service.dart';
// import '../../../services/device_service.dart';
// import '../../../utils/app_colors.dart';
// import '../widgets/welcome_banner.dart'; // Import widget banner

// class ActualDashboardContent extends StatefulWidget {
//   const ActualDashboardContent({super.key});

//   @override
//   State<ActualDashboardContent> createState() => _ActualDashboardContentState();
// }

// class _ActualDashboardContentState extends State<ActualDashboardContent> {
//   final AuthService _authService = AuthService();
//   final DeviceService _deviceService = DeviceService();

//   // State untuk data umum
//   String _userName = 'User';
//   bool _isLoading = true;
//   Timer? _realtimeTimer;

//   // State untuk filter dan data perangkat
//   List<Device> _devices = [];
//   Device? _selectedDevice;
//   DateTime _selectedDate = DateTime.now();

//   // State untuk data yang akan ditampilkan
//   List<DeviceDataHourly> _hourlyData = [];
//   DeviceData? _latestData;
//   double _totalKwhToday = 0.0;
//   double _totalCostToday = 0.0;

//   @override
//   void initState() {
//     super.initState();
//     _initializeDashboard();
//   }

//   @override
//   void dispose() {
//     _realtimeTimer?.cancel(); // Hentikan timer saat widget dihancurkan
//     super.dispose();
//   }

//   // --- LOGIKA PENGAMBILAN & PEMROSESAN DATA ---

//   Future<void> _initializeDashboard() async {
//     await _loadUserName();
//     await _fetchUserDevices();
//     if (_selectedDevice != null) {
//       _startRealtimeUpdates();
//     }
//   }

//   Future<void> _loadUserName() async {
//     final userDetails = await _authService.getUserDetails();
//     if (mounted) {
//       setState(() {
//         _userName = userDetails['name'] ?? 'User';
//       });
//     }
//   }

//   Future<void> _fetchUserDevices() async {
//     setState(() {
//       _isLoading = true;
//     });
//     try {
//       _devices = await _deviceService.getDevices();
//       if (mounted && _devices.isNotEmpty) {
//         _selectedDevice = _devices.first;
//         await _fetchHourlyData(); // Langsung ambil data untuk perangkat pertama
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error memuat perangkat: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _fetchHourlyData() async {
//     if (_selectedDevice == null) return;
//     setState(() {
//       _isLoading = true;
//     });
//     try {
//       final data = await _deviceService.getHourlyData(
//         _selectedDevice!.id,
//         _selectedDate,
//       );
//       if (mounted) {
//         _processHourlyData(data); // Panggil fungsi proses data
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error memuat data grafik: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _fetchLatestData() async {
//     if (_selectedDevice == null) return;
//     try {
//       final latest = await _deviceService.getLatestData(_selectedDevice!.id);
//       if (mounted) {
//         setState(() {
//           _latestData = latest;
//         });
//       }
//     } catch (e) {
//       print("Gagal memuat data real-time: $e");
//     }
//   }

//   void _startRealtimeUpdates() {
//     _realtimeTimer?.cancel();
//     _fetchLatestData();
//     _realtimeTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
//       _fetchLatestData();
//     });
//   }

//   void _processHourlyData(List<DeviceDataHourly> data) {
//     if (data.isEmpty) {
//       setState(() {
//         _hourlyData = [];
//         _totalKwhToday = 0.0;
//         _totalCostToday = 0.0;
//       });
//       return;
//     }
//     setState(() {
//       _hourlyData = data;
//       _totalKwhToday = data.map((d) => d.kwhTotal).reduce((a, b) => a + b);
//       _totalCostToday = data.map((d) => d.costTotal).reduce((a, b) => a + b);
//     });
//   }

//   void _selectDate() async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate,
//       firstDate: DateTime.now().subtract(const Duration(days: 30)),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null && picked != _selectedDate) {
//       setState(() {
//         _selectedDate = picked;
//       });
//       _fetchHourlyData();
//     }
//   }

//   // --- UI UTAMA ---
//   @override
//   Widget build(BuildContext context) {
//     // Layout utama sekarang bisa di-scroll
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(24), // Beri padding utama di sini
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // 1. Widget Banner Sapaan
//           WelcomeBanner(userName: _userName),
//           const SizedBox(height: 24),

//           // 2. Filter Bar
//           _buildFilterBar(),
//           const SizedBox(height: 24),

//           // Tampilkan loading atau konten
//           _isLoading
//               ? const Center(
//                   heightFactor: 10,
//                   child: CircularProgressIndicator(),
//                 )
//               : Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // 3. Kartu Ringkasan & Real-time
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(child: _buildRealtimeCard()),
//                         const SizedBox(width: 16),
//                         Expanded(child: _buildDailySummaryCard()),
//                       ],
//                     ),
//                     const SizedBox(height: 24),

//                     // 4. Kartu Grafik Harian
//                     Text(
//                       'Konsumsi per Jam - ${DateFormat('d MMMM yyyy').format(_selectedDate)}',
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     _buildHourlyChartCard(),
//                   ],
//                 ),
//         ],
//       ),
//     );
//   }

//   // --- WIDGET HELPER ---

//   Widget _buildFilterBar() {
//     // ... (kode _buildFilterBar sama seperti sebelumnya) ...
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
//         child: Row(
//           children: [
//             Expanded(
//               flex: 2,
//               child: DropdownButtonHideUnderline(
//                 child: DropdownButton<Device>(
//                   value: _selectedDevice,
//                   isExpanded: true,
//                   hint: const Text('Pilih Perangkat'),
//                   items: _devices
//                       .map(
//                         (d) => DropdownMenuItem(
//                           value: d,
//                           child: Text(d.name, overflow: TextOverflow.ellipsis),
//                         ),
//                       )
//                       .toList(),
//                   onChanged: (device) {
//                     if (device != null) {
//                       setState(() {
//                         _selectedDevice = device;
//                         _hourlyData = [];
//                         _latestData = null;
//                       });
//                       _fetchHourlyData();
//                       _startRealtimeUpdates();
//                     }
//                   },
//                 ),
//               ),
//             ),
//             const SizedBox(width: 8),
//             TextButton.icon(
//               onPressed: _selectDate,
//               icon: const Icon(Icons.calendar_today_outlined, size: 18),
//               label: Text(DateFormat('d MMM yyyy').format(_selectedDate)),
//               style: TextButton.styleFrom(
//                 foregroundColor: AppColors.primaryColor,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRealtimeCard() {
//     // ... (kode _buildRealtimeCard sama seperti sebelumnya) ...
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Status Real-time',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black54,
//               ),
//             ),
//             const Divider(height: 20),
//             _buildMetricRow(
//               'Daya',
//               '${_latestData?.watt.toStringAsFixed(1) ?? '--'}',
//               'Watt',
//             ),
//             const SizedBox(height: 8),
//             _buildMetricRow(
//               'Tegangan',
//               '${_latestData?.voltage.toStringAsFixed(1) ?? '--'}',
//               'V',
//             ),
//             const SizedBox(height: 8),
//             _buildMetricRow(
//               'Arus',
//               '${_latestData?.current.toStringAsFixed(2) ?? '--'}',
//               'A',
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDailySummaryCard() {
//     // ... (kode _buildDailySummaryCard sama seperti sebelumnya) ...
//     final currencyFormatter = NumberFormat.currency(
//       locale: 'id_ID',
//       symbol: 'Rp ',
//       decimalDigits: 0,
//     );

//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Ringkasan Hari Ini',
//               style: const TextStyle(
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black54,
//               ),
//             ),
//             const Divider(height: 20),
//             _buildMetricRow(
//               'Total Energi',
//               _totalKwhToday.toStringAsFixed(3),
//               'kWh',
//             ),
//             const SizedBox(height: 8),
//             _buildMetricRow(
//               'Perkiraan Biaya',
//               currencyFormatter.format(_totalCostToday),
//               '',
//             ),
//             const SizedBox(height: 8),
//             _buildMetricRow(
//               'Suhu Rata-rata',
//               '${_latestData?.temperature.toStringAsFixed(1) ?? '--'}',
//               '°C',
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildMetricRow(String label, String value, String unit) {
//     // ... (kode _buildMetricRow sama seperti sebelumnya) ...
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
//         Text(
//           '$value $unit',
//           style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
//         ),
//       ],
//     );
//   }

//   Widget _buildHourlyChartCard() {
//     // ... (kode _buildHourlyChartCard sama seperti sebelumnya) ...
//     return AspectRatio(
//       aspectRatio: 2,
//       child: Card(
//         elevation: 2,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: _hourlyData.isEmpty
//               ? const Center(child: Text("Tidak ada data pada tanggal ini."))
//               : BarChart(
//                   BarChartData(
//                     alignment: BarChartAlignment.spaceAround,
//                     barGroups: _hourlyData.map((data) {
//                       return BarChartGroupData(
//                         x: data.hourTimestamp.hour,
//                         barRods: [
//                           BarChartRodData(
//                             toY: data.kwhTotal,
//                             color: AppColors.primaryColor,
//                             width: 12,
//                             borderRadius: const BorderRadius.only(
//                               topLeft: Radius.circular(4),
//                               topRight: Radius.circular(4),
//                             ),
//                           ),
//                         ],
//                       );
//                     }).toList(),
//                     titlesData: FlTitlesData(
//                       topTitles: AxisTitles(
//                         sideTitles: SideTitles(showTitles: false),
//                       ),
//                       rightTitles: AxisTitles(
//                         sideTitles: SideTitles(showTitles: false),
//                       ),
//                       leftTitles: AxisTitles(
//                         sideTitles: SideTitles(
//                           showTitles: true,
//                           reservedSize: 40,
//                         ),
//                       ),
//                       bottomTitles: AxisTitles(
//                         sideTitles: SideTitles(
//                           showTitles: true,
//                           reservedSize: 30,
//                           getTitlesWidget: (value, meta) {
//                             if (value.toInt() % 3 == 0) {
//                               return SideTitleWidget(
//                                 axisSide: meta.axisSide,
//                                 child: Text(
//                                   '${value.toInt().toString().padLeft(2, '0')}:00',
//                                   style: const TextStyle(fontSize: 10),
//                                 ),
//                               );
//                             }
//                             return const SizedBox.shrink();
//                           },
//                         ),
//                       ),
//                     ),
//                     barTouchData: BarTouchData(
//                       touchTooltipData: BarTouchTooltipData(
//                         getTooltipColor: (touchedSpot) => Colors.blueGrey,
//                         getTooltipItem: (group, groupIndex, rod, rodIndex) {
//                           final kwh = rod.toY;
//                           return BarTooltipItem(
//                             '${kwh.toStringAsFixed(3)} kWh',
//                             const TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//                 ),
//         ),
//       ),
//     );
//   }
// }

// lib/screens/dashboard/pages/actual_dashboard_content.dart
import 'package:flutter/material.dart';
import '../../../models/device_model.dart';
import '../../../models/device_trending_data_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/device_service.dart';
import '../widgets/welcome_banner.dart';
>>>>>>> Stashed changes

class ActualDashboardContent extends StatefulWidget {
  const ActualDashboardContent({super.key});
  @override
  State<ActualDashboardContent> createState() => _ActualDashboardContentState();
}

class _ActualDashboardContentState extends State<ActualDashboardContent> {
<<<<<<< Updated upstream
  String _userName = 'User';
=======
  final AuthService _authService = AuthService();
  final DeviceService _deviceService = DeviceService();

  String _userName = 'User';
  List<Device> _devices = [];
  Device? _selectedDevice;
  DeviceTrendingData? _trendingData;
  bool _isLoading = true;
>>>>>>> Stashed changes

  @override
  void initState() {
    super.initState();
<<<<<<< Updated upstream
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final userDetails = await AuthService().getUserDetails();
    if (mounted) {
      setState(() {
        _userName = userDetails['name'] ?? 'User';
      });
=======
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Load user name first
      final userDetails = await _authService.getUserDetails();
      if (mounted) {
        setState(() {
          _userName = userDetails['name'] ?? 'User';
        });
      }

      // Then load devices
      _devices = await _deviceService.getDevices();
      if (mounted && _devices.isNotEmpty) {
        _selectedDevice = _devices.first;
        await _fetchTrendingData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  Future<void> _fetchTrendingData() async {
    if (_selectedDevice == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      _trendingData = await _deviceService.getTrendingData(_selectedDevice!.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading trending data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
>>>>>>> Stashed changes
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< Updated upstream
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Widget Banner Sapaan di bagian atas
        WelcomeBanner(userName: _userName),
        const SizedBox(height: 24),

        // Anda bisa menambahkan konten dashboard lainnya di sini
        const Text(
          'Analisis Data',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
=======
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WelcomeBanner(userName: _userName),
          const SizedBox(height: 24),
          DropdownButton<Device>(
            value: _selectedDevice,
            hint: const Text("Pilih Perangkat"),
            isExpanded: true,
            items: _devices
                .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                .toList(),
            onChanged: (device) {
              if (device != null) {
                setState(() {
                  _selectedDevice = device;
                });
                _fetchTrendingData();
              }
            },
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _trendingData == null
              ? const Center(
                  child: Text("Belum ada data tren untuk perangkat ini."),
                )
              : _buildTrendingCards(),
        ],
      ),
    );
  }

  Widget _buildTrendingCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2,
      children: [
        _buildSummaryCard('24 Jam Terakhir', _trendingData!.last24hKwh, 'kWh'),
        _buildSummaryCard('7 Hari Terakhir', _trendingData!.last7dKwh, 'kWh'),
        _buildSummaryCard('30 Hari Terakhir', _trendingData!.last30dKwh, 'kWh'),
        _buildSummaryCard(
          'Efisiensi',
          _trendingData!.currentEfficiency ?? 0,
          'BTU/Wh',
>>>>>>> Stashed changes
        ),
        // Contoh: Expanded(child: GridView(...) atau ListView(...))
      ],
    );
  }
<<<<<<< Updated upstream
}
=======

  Widget _buildSummaryCard(String title, double value, String unit) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              '${value.toStringAsFixed(2)} $unit',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
>>>>>>> Stashed changes
