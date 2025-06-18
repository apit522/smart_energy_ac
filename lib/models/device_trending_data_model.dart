// Sesuai skema tabel device_trending_data
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

  // factory DeviceTrendingData.fromJson(Map<String, dynamic> json) {
  //   return DeviceTrendingData(
  //     deviceId: json['device_id'],
  //     last24hKwh: (json['last_24h_kwh'] as num).toDouble(),
  //     last7dKwh: (json['last_7d_kwh'] as num).toDouble(),
  //     last30dKwh: (json['last_30d_kwh'] as num).toDouble(),
  //     currentEfficiency: (json['current_efficiency'] as num?)?.toDouble(),
  //     lastUpdated: DateTime.parse(json['last_updated']).toLocal(),
  //   );
  // }

  factory DeviceTrendingData.fromJson(Map<String, dynamic> json) {
    // Helper kecil untuk parsing yang aman
    double safeParseDouble(dynamic value) {
      return double.tryParse(value?.toString() ?? '0') ?? 0.0;
    }

    return DeviceTrendingData(
      deviceId: (json['device_id'] as num?)?.toInt() ?? 0,
      last24hKwh: safeParseDouble(json['last_24h_kwh']),
      last7dKwh: safeParseDouble(json['last_7d_kwh']),
      last30dKwh: safeParseDouble(json['last_30d_kwh']),
      currentEfficiency: safeParseDouble(json['current_efficiency']),
      lastUpdated: DateTime.parse(json['last_updated']).toLocal(),
    );
  }
}
