// lib/models/device_data_model.dart
class DeviceData {
  final int id;
  final double watt;
  final double temperature;
  final double voltage;
  final double current;
  final DateTime createdAt;

  DeviceData({
    required this.id,
    required this.watt,
    required this.temperature,
    required this.voltage,
    required this.current,
    required this.createdAt,
  });

  factory DeviceData.fromJson(Map<String, dynamic> json) {
    return DeviceData(
      id: json['id'],
      watt: (json['watt'] as num).toDouble(),
      temperature: (json['temperature'] as num).toDouble(),
      voltage: (json['voltage'] as num).toDouble(),
      current: (json['current'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}