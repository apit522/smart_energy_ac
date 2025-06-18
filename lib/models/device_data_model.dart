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
    // Ambil string waktu dari JSON
    // Seharusnya sekarang kuncinya adalah 'timestamp'
    // String timestampString = json['timestamp'] ?? json['created_at'] ?? '';

    // // Jika string diakhiri dengan 'Z', hapus agar di-parse sebagai waktu lokal
    // if (timestampString.endsWith('Z')) {
    //   timestampString = timestampString.substring(
    //     0,
    //     timestampString.length - 1,
    //   );
    // }

    return DeviceData(
      id: json['id'],
      watt: (json['watt'] as num).toDouble(),
      temperature: (json['temperature'] as num).toDouble(),
      voltage: (json['voltage'] as num).toDouble(),
      current: (json['current'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
    );
  }
}
