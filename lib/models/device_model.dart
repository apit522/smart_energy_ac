// lib/models/device_model.dart
class Device {
  final int id;
  final String name;
  final String uniqueId;
  final int? btu;
  final String? lastSeenAt;

  Device({
    required this.id,
    required this.name,
    required this.uniqueId,
    this.btu,
    this.lastSeenAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      uniqueId: json['unique_id'],
      btu: json['btu'],
      lastSeenAt: json['last_seen_at'],
    );
  }
}