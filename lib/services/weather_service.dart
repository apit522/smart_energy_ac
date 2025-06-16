// lib/services/weather_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_keys.dart'; // Import API key Anda

class WeatherService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  Future<Map<String, dynamic>> getCurrentWeather(String city) async {
    try {
      // Buat URL dengan query parameters
      final uri = Uri.parse('$_baseUrl?q=$city&appid=$openWeatherApiKey&units=metric');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        // Jika request berhasil, parse JSON
        return json.decode(response.body);
      } else {
        // Jika gagal, lempar exception dengan pesan error dari API
        throw Exception('Failed to load weather data: ${json.decode(response.body)['message']}');
      }
    } catch (e) {
      // Tangani error koneksi atau lainnya
      throw Exception('Failed to connect to weather service: $e');
    }
  }
}