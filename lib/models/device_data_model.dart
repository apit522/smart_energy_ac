// lib/models/device_data_model.dart
class DeviceData {
  final int id;
  final double watt;
  final double temperature;
  final double voltage;
  final double current;
  final DateTime timestamp;

  DeviceData({
    required this.id,
    required this.watt,
    required this.temperature,
    required this.voltage,
    required this.current,
    required this.timestamp,
  });

  factory DeviceData.fromJson(Map<String, dynamic> json) {
    // Helper untuk parsing aman
    int safeParseInt(dynamic value) {
      return int.tryParse(value?.toString() ?? '0') ?? 0;
    }

    double safeParseDouble(dynamic value) {
      return double.tryParse(value?.toString() ?? '0') ?? 0.0;
    }

    // Pastikan timestamp tidak null sebelum di-parse
    DateTime parseTimestamp(dynamic value) {
      if (value != null) {
        return DateTime.parse(value.toString()).toLocal();
      }
      return DateTime.now();
    }

    return DeviceData(
      id: safeParseInt(json['id']),
      watt: safeParseDouble(json['watt']),
      temperature: safeParseDouble(json['temperature']),
      voltage: safeParseDouble(json['voltage']),
      current: safeParseDouble(json['current']),
      timestamp: parseTimestamp(json['timestamp']),
    );
  }
}
