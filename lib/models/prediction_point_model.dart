// lib/models/prediction_point_model.dart

class PredictionPoint {
  final int hour;
  final double predictedKwh;

  PredictionPoint({
    required this.hour,
    required this.predictedKwh, // Ganti nama properti
  });
}
