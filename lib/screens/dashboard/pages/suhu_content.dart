// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:intl/intl.dart';
// import '../../../models/device_model.dart';
// import '../../../models/device_data_model.dart';
// import '../../../services/device_service.dart';
// import '../../../utils/app_colors.dart';

// class SuhuContent extends StatefulWidget {
//   const SuhuContent({super.key});

//   @override
//   State<SuhuContent> createState() => _SuhuContentState();
// }

// class _SuhuContentState extends State<SuhuContent> {
//   final DeviceService _deviceService = DeviceService();
//   List<Device> _devices = [];
//   Device? _selectedDevice;
//   List<DeviceData> _deviceData = [];
//   bool _isLoading = true;

//   // State untuk filter
//   String _selectedPeriod = '24h';

//   // State untuk rata-rata suhu
//   double _avgTemperature = 0.0;

//   @override
//   void initState() {
//     super.initState();
//     _fetchUserDevices();
//   }

//   Future<void> _fetchUserDevices() async {
//     setState(() {
//       _isLoading = true;
//     });
//     try {
//       final devices = await _deviceService.getDevices();
//       if (mounted) {
//         setState(() {
//           _devices = devices;
//           if (_devices.isNotEmpty) {
//             _selectedDevice = _devices.first;
//             _fetchDeviceData();
//           } else {
//             _isLoading = false;
//           }
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error memuat perangkat: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _fetchDeviceData() async {
//     if (_selectedDevice == null) {
//       setState(() {
//         _isLoading = false;
//       });
//       return;
//     }
//     setState(() {
//       _isLoading = true;
//     });
//     try {
//       final data = await _deviceService.getDeviceData(
//         _selectedDevice!.id,
//         period: _selectedPeriod,
//       );
//       if (mounted) {
//         setState(() {
//           _deviceData = data;
//           _calculateAverageTemperature(data);
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error memuat data suhu: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   void _calculateAverageTemperature(List<DeviceData> data) {
//     if (data.isEmpty) {
//       setState(() {
//         _avgTemperature = 0.0;
//       });
//       return;
//     }
//     final avg =
//         data.map((d) => d.temperature).reduce((a, b) => a + b) / data.length;
//     setState(() {
//       _avgTemperature = avg;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         _buildFilterBar(),
//         const SizedBox(height: 24),
//         _isLoading
//             ? const Expanded(child: Center(child: CircularProgressIndicator()))
//             : Expanded(
//                 child: SingleChildScrollView(
//                   child: Column(
//                     children: [
//                       _buildChartCard(),
//                       const SizedBox(height: 16),
//                       _buildAverageTemperatureChip(),
//                     ],
//                   ),
//                 ),
//               ),
//       ],
//     );
//   }

//   Widget _buildFilterBar() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
//         child: Row(
//           children: [
//             // Dropdown Periode
//             Expanded(
//               flex: 1,
//               child: DropdownButtonHideUnderline(
//                 child: DropdownButton<String>(
//                   value: _selectedPeriod,
//                   items: const [
//                     DropdownMenuItem(value: '24h', child: Text('Harian')),
//                     DropdownMenuItem(value: '7d', child: Text('Mingguan')),
//                     DropdownMenuItem(value: '30d', child: Text('Bulanan')),
//                   ],
//                   onChanged: (value) {
//                     if (value != null) {
//                       setState(() {
//                         _selectedPeriod = value;
//                       });
//                       _fetchDeviceData();
//                     }
//                   },
//                 ),
//               ),
//             ),
//             const SizedBox(width: 16),
//             // Dropdown Perangkat
//             Expanded(
//               flex: 2,
//               child: DropdownButtonHideUnderline(
//                 child: DropdownButton<Device>(
//                   value: _selectedDevice,
//                   isExpanded: true,
//                   hint: const Text('Perangkat'),
//                   items: _devices
//                       .map(
//                         (device) => DropdownMenuItem(
//                           value: device,
//                           child: Text(
//                             device.name,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                       )
//                       .toList(),
//                   onChanged: (device) {
//                     if (device != null) {
//                       setState(() {
//                         _selectedDevice = device;
//                       });
//                       _fetchDeviceData();
//                     }
//                   },
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildChartCard() {
//     final List<FlSpot> spots = _deviceData
//         .map(
//           (d) => FlSpot(
//             d.timestamp.millisecondsSinceEpoch.toDouble(),
//             d.temperature,
//           ),
//         )
//         .toList();

//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Grafik Suhu',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 20),
//             AspectRatio(
//               aspectRatio: 2,
//               child: spots.length < 2
//                   ? const Center(
//                       child: Text('Data tidak cukup untuk menampilkan grafik.'),
//                     )
//                   : LineChart(
//                       LineChartData(
//                         gridData: FlGridData(show: true),
//                         titlesData: FlTitlesData(
//                           leftTitles: AxisTitles(
//                             sideTitles: SideTitles(
//                               showTitles: true,
//                               reservedSize: 44,
//                               getTitlesWidget: (value, meta) => Text(
//                                 meta.formattedValue,
//                                 style: const TextStyle(fontSize: 10),
//                               ),
//                             ),
//                           ),
//                           bottomTitles: _getBottomTitles(spots),
//                           topTitles: AxisTitles(
//                             sideTitles: SideTitles(showTitles: false),
//                           ),
//                           rightTitles: AxisTitles(
//                             sideTitles: SideTitles(showTitles: false),
//                           ),
//                         ),
//                         borderData: FlBorderData(
//                           show: true,
//                           border: Border.all(color: Colors.grey.shade300),
//                         ),
//                         lineBarsData: [
//                           LineChartBarData(
//                             spots: spots,
//                             isCurved: true,
//                             color: Colors.orange,
//                             barWidth: 3,
//                             isStrokeCapRound: true,
//                             dotData: FlDotData(show: true),
//                             belowBarData: BarAreaData(
//                               show: true,
//                               color: Colors.orange.withOpacity(0.3),
//                             ),
//                           ),
//                         ],
//                         lineTouchData: LineTouchData(
//                           touchTooltipData: LineTouchTooltipData(
//                             getTooltipColor: (touchedSpot) => Colors.black,
//                             getTooltipItems: (touchedSpots) {
//                               return touchedSpots.map((spot) {
//                                 final yValue = spot.y.toStringAsFixed(1);
//                                 return LineTooltipItem(
//                                   '$yValue °C',
//                                   const TextStyle(color: Colors.white),
//                                 );
//                               }).toList();
//                             },
//                           ),
//                         ),
//                       ),
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   AxisTitles _getBottomTitles(List<FlSpot> spots) {
//     if (spots.length < 2) {
//       return AxisTitles(sideTitles: SideTitles(showTitles: false));
//     }
//     final double minX = spots.first.x;
//     final double maxX = spots.last.x;
//     final double interval = (maxX - minX) > 0 ? (maxX - minX) / 4 : 1;

//     return AxisTitles(
//       sideTitles: SideTitles(
//         showTitles: true,
//         reservedSize: 30,
//         interval: interval,
//         getTitlesWidget: (value, meta) {
//           if (value == meta.min || value == meta.max)
//             return const SizedBox.shrink();
//           final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
//           // *** PERBAIKAN ZONA WAKTU ***
//           final String formattedTime = DateFormat(
//             'HH:mm',
//           ).format(dateTime.toLocal());
//           return SideTitleWidget(
//             axisSide: meta.axisSide,
//             child: Text(
//               formattedTime,
//               style: const TextStyle(
//                 fontSize: 10,
//                 color: Colors.black54,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildAverageTemperatureChip() {
//     return Chip(
//       avatar: const Icon(
//         Icons.thermostat_outlined,
//         color: AppColors.primaryColor,
//       ),
//       label: Text(
//         'Rata-rata: ${_avgTemperature.toStringAsFixed(1)} °C',
//         style: const TextStyle(
//           color: AppColors.primaryColor,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//       backgroundColor: AppColors.primaryColor.withOpacity(0.15),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//       labelStyle: const TextStyle(fontSize: 14),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// Pastikan semua path import ini sudah benar
import '../../../models/device_model.dart';
import '../../../models/device_daily_summary_model.dart';
import '../../../services/device_service.dart';
import '../../../utils/app_colors.dart';

class SuhuContent extends StatefulWidget {
  const SuhuContent({super.key});

  @override
  State<SuhuContent> createState() => _SuhuContentState();
}

class _SuhuContentState extends State<SuhuContent> {
  final DeviceService _deviceService = DeviceService();

  bool _isLoading = true;
  List<Device> _devices = [];
  Device? _selectedDevice;
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(
      const Duration(days: 6),
    ), // Default 7 hari terakhir untuk suhu
    end: DateTime.now(),
  );

  List<DeviceDailySummary> _dailySummaries = [];
  double _periodAvgTemp = 0.0;
  double _periodMaxTemp = 0.0;
  double _periodMinTemp = 0.0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _fetchUserDevices();
    if (_selectedDevice != null) {
      await _fetchSummaryData();
    }
  }

  Future<void> _fetchUserDevices() async {
    setState(() {
      _isLoading = true;
    });
    try {
      _devices = await _deviceService.getDevices();
      if (mounted && _devices.isNotEmpty) {
        _selectedDevice = _devices.first;
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat perangkat: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _fetchSummaryData() async {
    if (_selectedDevice == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      _dailySummaries = await _deviceService.getDailySummary(
        _selectedDevice!.id,
        startDate: _selectedDateRange.start,
        endDate: _selectedDateRange.end,
      );
      _calculateStats();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat ringkasan suhu: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  void _calculateStats() {
    if (_dailySummaries.isEmpty) {
      _periodAvgTemp = 0;
      _periodMaxTemp = 0;
      _periodMinTemp = 0;
      return;
    }
    _periodAvgTemp =
        _dailySummaries.map((s) => s.avgTemperature).reduce((a, b) => a + b) /
        _dailySummaries.length;
    _periodMaxTemp = _dailySummaries
        .map((s) => s.avgTemperature)
        .reduce((a, b) => a > b ? a : b);
    _periodMinTemp = _dailySummaries
        .map((s) => s.avgTemperature)
        .reduce((a, b) => a < b ? a : b);
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchSummaryData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        const SizedBox(height: 24),
        _isLoading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
            : Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildChartCard(),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildFilterBar() {
    final dateFormat = DateFormat('d MMM y');
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
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
                  onChanged: (device) {
                    if (device != null) {
                      setState(() {
                        _selectedDevice = device;
                      });
                      _fetchSummaryData();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: _selectDateRange,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                '${dateFormat.format(_selectedDateRange.start)} - ${dateFormat.format(_selectedDateRange.end)}',
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.5 / 2,
      children: [
        _buildSummaryCard(
          'Suhu Rata-rata',
          _periodAvgTemp.toStringAsFixed(1),
          '°C',
          Icons.thermostat_outlined,
        ),
        _buildSummaryCard(
          'Suhu Tertinggi',
          _periodMaxTemp.toStringAsFixed(1),
          '°C',
          Icons.arrow_upward,
        ),
        _buildSummaryCard(
          'Suhu Terendah',
          _periodMinTemp.toStringAsFixed(1),
          '°C',
          Icons.arrow_downward,
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
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.orange.shade800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '$value$unit',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final List<FlSpot> spots = _dailySummaries.asMap().entries.map((entry) {
      int index = entry.key;
      DeviceDailySummary summary = entry.value;
      return FlSpot(index.toDouble(), summary.avgTemperature);
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              aspectRatio: 2,
              child: _dailySummaries.length < 2
                  ? const Center(
                      child: Text('Data tidak cukup untuk menampilkan grafik.'),
                    )
                  : LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: Colors.orange,
                            barWidth: 3,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                        ],
                        // ... (titlesData dan konfigurasi lain sama seperti di konsumsi_daya_content) ...
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
