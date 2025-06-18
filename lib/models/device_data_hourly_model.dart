// lib/models/device_data_hourly_model.dart
class DeviceDataHourly {
  final DateTime hourTimestamp;
  final double wattAvg;
  final double kwhTotal;
  final double costTotal;

  DeviceDataHourly({
    required this.hourTimestamp,
    required this.wattAvg,
    required this.kwhTotal,
    required this.costTotal,
  });

  factory DeviceDataHourly.fromJson(Map<String, dynamic> json) {
    return DeviceDataHourly(
      hourTimestamp: DateTime.parse(json['hour_timestamp']).toLocal(),
      wattAvg: (json['watt_avg'] as num).toDouble(),
      kwhTotal: (json['kwh_total'] as num).toDouble(),
      costTotal: (json['cost_total'] as num).toDouble(),
    );
  }
}
