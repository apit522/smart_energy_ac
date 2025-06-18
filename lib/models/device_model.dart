// lib/models/device_model.dart
class Device {
  final int id;
  final String name;
  final String? location;
  final String uniqueId;
  final int? btu;
  final String? lastSeenAt;
  final int? dayaVa;
  final double? tarifPerKwh;

  Device({
    required this.id,
    required this.name,
    this.location,
    required this.uniqueId,
    this.btu,
    this.lastSeenAt,
    this.dayaVa,
    this.tarifPerKwh,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      location: json['location'],
      uniqueId: json['unique_id'],
      btu: json['btu'],
      lastSeenAt: json['last_seen_at'],
      dayaVa: json['daya_va'],
      tarifPerKwh: (json['tarif_per_kwh'] != null)
          ? double.tryParse(json['tarif_per_kwh'].toString())
          : null,
    );
  }
}
