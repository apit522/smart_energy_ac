//lib\models\device_trending_data_model.dart
class DeviceTrendingData {
  final int deviceId;
  final double last24hKwh;
  final double last7dKwh;
  final double last30dKwh;
  final double? currentEfficiency;
  final DateTime lastUpdated;

  DeviceTrendingData({
    required this.deviceId,
    required this.last24hKwh,
    required this.last7dKwh,
    required this.last30dKwh,
    this.currentEfficiency,
    required this.lastUpdated,
  });

  factory DeviceTrendingData.fromJson(Map<String, dynamic> json) {
    // Helper kecil untuk parsing yang aman
    double safeParseDouble(dynamic value) {
      return double.tryParse(value?.toString() ?? '0') ?? 0.0;
    }

    // Helper untuk parsing integer yang aman dari string atau angka
    int safeParseInt(dynamic value) {
      return int.tryParse(value?.toString() ?? '0') ?? 0;
    }

    return DeviceTrendingData(
      // ✅ PERBAIKAN: Gunakan helper parsing yang aman
      deviceId: safeParseInt(json['device_id']),

      last24hKwh: safeParseDouble(json['last_24h_kwh']),
      last7dKwh: safeParseDouble(json['last_7d_kwh']),
      last30dKwh: safeParseDouble(json['last_30d_kwh']),

      // Ini juga sudah diperbaiki sebelumnya untuk menangani null
      currentEfficiency: json['current_efficiency'] != null
          ? safeParseDouble(json['current_efficiency'])
          : null,

      lastUpdated: DateTime.parse(json['last_updated']).toLocal(),
    );
  }
}
