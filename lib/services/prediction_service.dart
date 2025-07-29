// lib/services/prediction_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/daily_prediction_point_model.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class PredictionService {
  final AuthService _authService = AuthService();

  Future<String> _getRequiredToken() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesi tidak valid. Silakan login kembali.');
    }
    return token;
  }

  Future<List<DailyPredictionPoint>> get7DayPrediction(int deviceId) async {
    final token = await _getRequiredToken();
    // PERBAIKAN: Ganti endpoint jika berbeda, jika sama biarkan saja
    final url = Uri.parse('${AppConstants.baseUrl}/predict-usage/$deviceId');

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);

      // === PERBAIKAN UTAMA: LOGIKA PARSING SESUAI RESPON API ===
      if (responseData.containsKey('prediction') &&
          responseData['prediction'] is Map) {
        final predictionMap =
            responseData['prediction'] as Map<String, dynamic>;

        // 1. Ambil data dari kunci 'ensemble'
        if (predictionMap.containsKey('ensemble') &&
            predictionMap['ensemble'] is List) {
          final whList = predictionMap['ensemble'] as List;

          // 2. Ubah list (yang berisi data Wh) menjadi List<DailyPredictionPoint>
          return whList.asMap().entries.map((entry) {
            int dayIndex = entry.key; // index 0 sampai 6
            // 3. Konversi dari Wh ke kWh
            double kwhValue = (entry.value as num).toDouble() / 1000.0;
            // 4. Buat tanggal untuk setiap prediksi (hari + 1, hari + 2, dst.)
            DateTime predictionDate = DateTime.now().add(
              Duration(days: dayIndex + 1),
            );

            return DailyPredictionPoint(
              date: predictionDate,
              predictedKwh: kwhValue,
            );
          }).toList();
        }
      }

      // Jika struktur tidak sesuai, lempar error
      throw Exception('Format respons prediksi dari server tidak valid.');
    } else {
      final errorBody = json.decode(response.body);
      final errorMessage = errorBody['error'] ?? 'Gagal memuat data prediksi.';
      throw Exception(errorMessage);
    }
  }
}
