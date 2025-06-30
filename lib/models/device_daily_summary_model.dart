//lib\models\device_daily_summary_model.dart
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
