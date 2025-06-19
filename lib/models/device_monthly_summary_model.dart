// Sesuai skema tabel device_monthly_summaries
class DeviceMonthlySummary {
  final int summaryYear;
  final int summaryMonth;
  final double avgWatt;
  final double totalKwh;
  final double peakWatt;
  final double avgTemperature;

  DeviceMonthlySummary({
    required this.summaryYear,
    required this.summaryMonth,
    required this.avgWatt,
    required this.totalKwh,
    required this.peakWatt,
    required this.avgTemperature,
  });

  // factory DeviceMonthlySummary.fromJson(Map<String, dynamic> json) {
  //   return DeviceMonthlySummary(
  //     summaryYear: json['summary_year'],
  //     summaryMonth: json['summary_month'],
  //     avgWatt: (json['avg_watt'] as num).toDouble(),
  //     totalKwh: (json['total_kwh'] as num).toDouble(),
  //     peakWatt: (json['peak_watt'] as num).toDouble(),
  //     avgTemperature: (json['avg_temperature'] as num).toDouble(),
  //   );
  // }

  factory DeviceMonthlySummary.fromJson(Map<String, dynamic> json) {
    // Helper kecil untuk parsing yang aman
    double safeParseDouble(dynamic value) {
      return double.tryParse(value?.toString() ?? '0') ?? 0.0;
    }

    return DeviceMonthlySummary(
      summaryYear: (json['summary_year'] as num?)?.toInt() ?? 0,
      summaryMonth: (json['summary_month'] as num?)?.toInt() ?? 0,
      avgWatt: safeParseDouble(json['avg_watt']),
      totalKwh: safeParseDouble(json['total_kwh']),
      peakWatt: safeParseDouble(json['peak_watt']),
      avgTemperature: safeParseDouble(json['avg_temperature']),
    );
  }
}
