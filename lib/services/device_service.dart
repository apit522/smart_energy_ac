// lib/services/device_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device_model.dart'; // Import model
import '../models/device_daily_summary_model.dart';
import '../models/device_monthly_summary_model.dart';
import '../models/device_trending_data_model.dart';
import '../services/auth_service.dart'; // Untuk mendapatkan token
import '../utils/constants.dart'; // Untuk AppConstants.baseUrl
import '../models/device_data_model.dart';
import '../models/device_data_hourly_model.dart';
import 'package:intl/intl.dart';

class DeviceService {
  final AuthService _authService = AuthService();

  Future<String> _getRequiredToken() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi tidak valid. Silakan login kembali.');
    }
    return token;
  }

  Future<List<Device>> getDevices() async {
    final token = await _authService.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/devices'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Device.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load devices');
    }
  }

  Future<Device> addDevice({
    required String name,
    String? location,
    required String uniqueId,
    int? btu,
    required int dayaVa,
  }) async {
    final token = await _authService.getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/devices'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'name': name,
        'location': location,
        'unique_id': uniqueId,
        'btu': btu,
        'daya_va': dayaVa,
      }),
    );

    if (response.statusCode == 201) {
      return Device.fromJson(json.decode(response.body));
    } else {
      throw Exception('Gagal menambah perangkat: ${response.body}');
    }
  }

  Future<Device> updateDevice({
    required int id,
    required String name,
    String? location,
    required String uniqueId,
    int? btu,
    required int dayaVa,
  }) async {
    final token = await _authService.getToken();
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/devices/$id'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'name': name,
        'location': location,
        'unique_id': uniqueId,
        'btu': btu,
        'daya_va': dayaVa,
      }),
    );

    if (response.statusCode == 200) {
      return Device.fromJson(json.decode(response.body));
    } else {
      throw Exception('Gagal mengupdate perangkat: ${response.body}');
    }
  }

  Future<void> deleteDevice(int id) async {
    final token = await _authService.getToken();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/devices/$id'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete device: ${response.body}');
    }
  }

  Future<List<DeviceData>> getDeviceData(
    int deviceId, {
    String period = '24h',
  }) async {
    final token = await _authService.getToken();
    final url = Uri.parse(
      '${AppConstants.baseUrl}/devices/$deviceId/data?period=$period',
    );
    final response = await http.get(
      url,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    // // TAMBAHKAN PRINT INI UNTUK DEBUGGING
    // print('DEBUG: Memanggil API URL: $url');
    // // TAMBAHKAN PRINT INI JUGA UNTUK MELIHAT RESPONS SERVER
    // print('DEBUG: API Response Status: ${response.statusCode}');
    // print('DEBUG: API Response Body: ${response.body}');

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => DeviceData.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load device data: ${response.body}');
    }
  }

  Future<List<DeviceDataHourly>> getHourlyData(
    int deviceId,
    DateTime date,
  ) async {
    final token = await _authService.getToken();
    final dateString = DateFormat('y-MM-dd').format(date);
    final url = Uri.parse(
      '${AppConstants.baseUrl}/devices/$deviceId/hourly-data?date=$dateString',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => DeviceDataHourly.fromJson(json)).toList();
    } else {
      throw Exception('Gagal memuat data per jam');
    }
  }

  Future<DeviceData?> getLatestData(int deviceId) async {
    final token = await _authService.getToken();
    final url = Uri.parse(
      '${AppConstants.baseUrl}/devices/$deviceId/latest-data',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      return DeviceData.fromJson(json.decode(response.body));
    } else if (response.body.isEmpty) {
      return null; // Tidak ada data
    } else {
      throw Exception('Gagal memuat data terbaru');
    }
  }

  // Method untuk mengambil data tren (untuk dashboard)
  Future<DeviceTrendingData?> getTrendingData(int deviceId) async {
    final token = await _getRequiredToken();
    final url = Uri.parse(
      '${AppConstants.baseUrl}/devices/$deviceId/summary?range=trending',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      return DeviceTrendingData.fromJson(json.decode(response.body));
    } else {
      // Mungkin belum ada data tren, jadi kembalikan null
      return null;
    }
  }

  // Method untuk mengambil ringkasan harian
  Future<List<DeviceDailySummary>> getDailySummary(
    int deviceId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await _getRequiredToken();
    final dateFormat = DateFormat('y-MM-dd');

    // Default 30 hari terakhir jika tidak ada tanggal yang diberikan
    final sDate = startDate != null
        ? dateFormat.format(startDate)
        : dateFormat.format(DateTime.now().subtract(const Duration(days: 29)));
    final eDate = endDate != null
        ? dateFormat.format(endDate)
        : dateFormat.format(DateTime.now());

    final url = Uri.parse(
      '${AppConstants.baseUrl}/devices/$deviceId/summary?range=daily&start_date=$sDate&end_date=$eDate',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => DeviceDailySummary.fromJson(json)).toList();
    } else {
      throw Exception('Gagal memuat ringkasan harian');
    }
  }

  // Method untuk mengambil ringkasan bulanan
  Future<List<DeviceMonthlySummary>> getMonthlySummary(
    int deviceId, {
    int? year,
  }) async {
    final token = await _getRequiredToken();
    final targetYear = year ?? DateTime.now().year;

    final url = Uri.parse(
      '${AppConstants.baseUrl}/devices/$deviceId/summary?range=monthly&year=$targetYear',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => DeviceMonthlySummary.fromJson(json)).toList();
    } else {
      throw Exception('Gagal memuat ringkasan bulanan');
    }
  }
}
