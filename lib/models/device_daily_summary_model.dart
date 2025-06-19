// Sesuai skema tabel device_daily_summaries
class DeviceDailySummary {
  final DateTime summaryDate;
  final int samplesCount;
  final double avgWatt;
  final double minWatt;
  final double maxWatt;
  final double avgTemperature;
  final double avgVoltage;
  final double avgCurrent;
  final double totalKwh;

  DeviceDailySummary({
    required this.summaryDate,
    required this.samplesCount,
    required this.avgWatt,
    required this.minWatt,
    required this.maxWatt,
    required this.avgTemperature,
    required this.avgVoltage,
    required this.avgCurrent,
    required this.totalKwh,
  });

  // factory DeviceDailySummary.fromJson(Map<String, dynamic> json) {
  //   return DeviceDailySummary(
  //     summaryDate: DateTime.parse(json['summary_date']),
  //     samplesCount: json['samples_count'],
  //     avgWatt: (json['avg_watt'] as num).toDouble(),
  //     minWatt: (json['min_watt'] as num).toDouble(),
  //     maxWatt: (json['max_watt'] as num).toDouble(),
  //     avgTemperature: (json['avg_temperature'] as num).toDouble(),
  //     avgVoltage: (json['avg_voltage'] as num).toDouble(),
  //     avgCurrent: (json['avg_current'] as num).toDouble(),
  //     totalKwh: (json['total_kwh'] as num).toDouble(),
  //   );
  // }

  factory DeviceDailySummary.fromJson(Map<String, dynamic> json) {
    // Helper kecil untuk parsing yang aman
    double safeParseDouble(dynamic value) {
      return double.tryParse(value?.toString() ?? '0') ?? 0.0;
    }

    return DeviceDailySummary(
      summaryDate: DateTime.parse(json['summary_date']),
      // Gunakan helper untuk semua field numerik
      samplesCount: (json['samples_count'] as num?)?.toInt() ?? 0,
      avgWatt: safeParseDouble(json['avg_watt']),
      minWatt: safeParseDouble(json['min_watt']),
      maxWatt: safeParseDouble(json['max_watt']),
      avgTemperature: safeParseDouble(json['avg_temperature']),
      avgVoltage: safeParseDouble(json['avg_voltage']),
      avgCurrent: safeParseDouble(json['avg_current']),
      totalKwh: safeParseDouble(json['total_kwh']),
    );
  }
}
