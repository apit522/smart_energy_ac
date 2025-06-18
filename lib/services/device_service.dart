// lib/services/device_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device_model.dart'; // Import model
import '../services/auth_service.dart'; // Untuk mendapatkan token
import '../utils/constants.dart'; // Untuk AppConstants.baseUrl
import '../models/device_data_model.dart';

class DeviceService {
  final AuthService _authService = AuthService();

  Future<List<Device>> getDevices() async {
    final token = await _authService.getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/devices'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Device.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load devices');
    }
  }

  Future<Device> addDevice(String name, String uniqueId, int? btu) async {
    final token = await _authService.getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/devices'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'name': name,
        'unique_id': uniqueId,
        'btu': btu,
      }),
    );

    if (response.statusCode == 201) {
      return Device.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to add device: ${response.body}');
    }
  }

  Future<Device> updateDevice(int id, String name, String uniqueId, int? btu) async {
    final token = await _authService.getToken();
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/devices/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'name': name,
        'unique_id': uniqueId,
        'btu': btu,
      }),
    );

    if (response.statusCode == 200) {
      return Device.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update device: ${response.body}');
    }
  }

  Future<void> deleteDevice(int id) async {
    final token = await _authService.getToken();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/devices/$id'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete device: ${response.body}');
    }
  }

  Future<List<DeviceData>> getDeviceData(int deviceId, {String period = '24h'}) async {
    final token = await _authService.getToken();
    final url = Uri.parse('${AppConstants.baseUrl}/devices/$deviceId/data?period=$period');
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => DeviceData.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load device data: ${response.body}');
    }
  }



}