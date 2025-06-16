// lib/screens/dashboard/widgets/welcome_banner.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../services/weather_service.dart';

class WelcomeBanner extends StatefulWidget {
  final String userName;

  const WelcomeBanner({super.key, required this.userName});

  @override
  State<WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<WelcomeBanner> {
  final WeatherService _weatherService = WeatherService();
  Map<String, dynamic>? _weatherData;
  bool _isLoading = true;
  String _errorMessage = '';

  // Tentukan breakpoint untuk mengubah layout ke mode mobile
  static const double mobileBreakpoint = 500;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    try {
      final data = await _weatherService.getCurrentWeather("Semarang");
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print(e);
      if (mounted) {
        setState(() {
          _errorMessage = "Gagal memuat data cuaca";
          _isLoading = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      return 'Selamat Pagi';
    } else if (hour < 15) {
      return 'Selamat Siang';
    } else if (hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  IconData _getWeatherIcon(String? iconCode) {
    if (iconCode == null) return Icons.cloud_off;
    switch (iconCode.substring(0, 2)) {
      case '01': return Icons.wb_sunny_outlined;
      case '02': case '03': case '04': return Icons.cloud_outlined;
      case '09': case '10': return Icons.grain_outlined;
      case '11': return Icons.thunderstorm_outlined;
      case '13': return Icons.ac_unit_outlined;
      case '50': return Icons.foggy;
      default: return Icons.cloud_outlined;
    }
  }

  // --- Helper Widget untuk bagian Kiri (Cuaca) ---
  Widget _buildWeatherSection() {
    final temperature = _weatherData?['main']?['temp']?.round().toString() ?? '--';
    final location = _weatherData?['name'] ?? 'Semarang';
    final weatherIconCode = _weatherData?['weather']?[0]?['icon'];

    return Row(
      children: [
        Icon(_getWeatherIcon(weatherIconCode), color: Colors.white, size: 60), // Ukuran ikon disesuaikan
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(location, style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text(
              '$temperature°C',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40, // Ukuran font disesuaikan
                fontWeight: FontWeight.w300,
              ),
            ),
            const Text('Outdoor Temperature', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  // --- Helper Widget untuk bagian Kanan (Sapaan) ---
  Widget _buildGreetingSection({bool isMobile = false}) {
    return Column(
      // Jika mobile, alignment teks rata kiri. Jika tidak, rata kanan.
      crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Halo ${widget.userName},',
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: isMobile ? TextAlign.start : TextAlign.end,
        ),
        Text(
          _getGreeting(),
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 28 : 36, // Ukuran font lebih kecil di mobile
            fontWeight: FontWeight.bold,
          ),
          textAlign: isMobile ? TextAlign.start : TextAlign.end,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF178189),
            Color(0xFF073A3E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.white70)))
          : Column(
        children: [
          // ==========================================================
          // INTI PERUBAHAN ADA DI SINI: MENGGUNAKAN LAYOUTBUILDER
          // ==========================================================
          LayoutBuilder(
            builder: (context, constraints) {
              // Cek apakah lebar saat ini kurang dari breakpoint mobile
              bool isMobile = constraints.maxWidth < mobileBreakpoint;

              if (isMobile) {
                // Tampilan Mobile: Gunakan Column
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWeatherSection(),
                    const SizedBox(height: 16), // Beri spasi antar bagian
                    _buildGreetingSection(isMobile: true),
                  ],
                );
              } else {
                // Tampilan Desktop/Web: Gunakan Row
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 3, child: _buildWeatherSection()),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildGreetingSection(isMobile: false)),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 15),
          const Divider(color: Colors.white30),
          const SizedBox(height: 5),
          // Bagian Bawah (Tanggal) - Tetap sama
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}