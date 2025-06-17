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

  // State untuk filter
  String _selectedPeriod = '24h';

  // State untuk rata-rata suhu
  double _avgTemperature = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchUserDevices();
  }

  Future<void> _fetchUserDevices() async {
    setState(() {
      _isLoading = true;
    });
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
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDeviceData() async {
    if (_selectedDevice == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await _deviceService.getDeviceData(
        _selectedDevice!.id,
        period: _selectedPeriod,
      );
      if (mounted) {
        setState(() {
          _deviceData = data;
          _calculateAverageTemperature(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat data suhu: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateAverageTemperature(List<DeviceData> data) {
    if (data.isEmpty) {
      setState(() {
        _avgTemperature = 0.0;
      });
      return;
    }
    final avg =
        data.map((d) => d.temperature).reduce((a, b) => a + b) / data.length;
    setState(() {
      _avgTemperature = avg;
    });
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
                      _buildChartCard(),
                      const SizedBox(height: 16),
                      _buildAverageTemperatureChip(),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Row(
          children: [
            // Dropdown Periode
            Expanded(
              flex: 1,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  items: const [
                    DropdownMenuItem(value: '24h', child: Text('Harian')),
                    DropdownMenuItem(value: '7d', child: Text('Mingguan')),
                    DropdownMenuItem(value: '30d', child: Text('Bulanan')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedPeriod = value;
                      });
                      _fetchDeviceData();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Dropdown Perangkat
            Expanded(
              flex: 2,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Device>(
                  value: _selectedDevice,
                  isExpanded: true,
                  hint: const Text('Perangkat'),
                  items: _devices
                      .map(
                        (device) => DropdownMenuItem(
                          value: device,
                          child: Text(
                            device.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (device) {
                    if (device != null) {
                      setState(() {
                        _selectedDevice = device;
                      });
                      _fetchDeviceData();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final List<FlSpot> spots = _deviceData
        .map(
          (d) => FlSpot(
            d.timestamp.millisecondsSinceEpoch.toDouble(),
            d.temperature,
          ),
        )
        .toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Grafik Suhu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 2,
              child: spots.length < 2
                  ? const Center(
                      child: Text('Data tidak cukup untuk menampilkan grafik.'),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: (value, meta) => Text(
                                meta.formattedValue,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: _getBottomTitles(spots),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
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
                            color: Colors.orange,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => Colors.black,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final yValue = spot.y.toStringAsFixed(1);
                                return LineTooltipItem(
                                  '$yValue °C',
                                  const TextStyle(color: Colors.white),
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

  AxisTitles _getBottomTitles(List<FlSpot> spots) {
    if (spots.length < 2) {
      return AxisTitles(sideTitles: SideTitles(showTitles: false));
    }
    final double minX = spots.first.x;
    final double maxX = spots.last.x;
    final double interval = (maxX - minX) > 0 ? (maxX - minX) / 4 : 1;

    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        interval: interval,
        getTitlesWidget: (value, meta) {
          if (value == meta.min || value == meta.max)
            return const SizedBox.shrink();
          final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
          // *** PERBAIKAN ZONA WAKTU ***
          final String formattedTime = DateFormat(
            'HH:mm',
          ).format(dateTime.toLocal());
          return SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(
              formattedTime,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAverageTemperatureChip() {
    return Chip(
      avatar: const Icon(
        Icons.thermostat_outlined,
        color: AppColors.primaryColor,
      ),
      label: Text(
        'Rata-rata: ${_avgTemperature.toStringAsFixed(1)} °C',
        style: const TextStyle(
          color: AppColors.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: AppColors.primaryColor.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      labelStyle: const TextStyle(fontSize: 14),
    );
  }
}
