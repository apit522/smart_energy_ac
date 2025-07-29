// lib/models/daily_prediction_point_model.dart

class DailyPredictionPoint {
  /// Tanggal prediksi (misal: 24 Juli 2025)
  final DateTime date;

  /// Nilai prediksi energi dalam kWh untuk tanggal tersebut
  final double predictedKwh;

  DailyPredictionPoint({required this.date, required this.predictedKwh});
}
