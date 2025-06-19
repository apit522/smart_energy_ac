// lib/services/prediction_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prediction_point_model.dart';
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

  // Method untuk mengambil data prediksi untuk besok
  Future<List<PredictionPoint>> getTomorrowPrediction(int deviceId) async {
    final token = await _getRequiredToken();
    final url = Uri.parse('${AppConstants.baseUrl}/predict-usage/$deviceId');

    print('DEBUG: Calling prediction API URL: $url');

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    print('DEBUG: Prediction API Response Status: ${response.statusCode}');
    print('DEBUG: Prediction API Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);

      // === PERBAIKAN LOGIKA PARSING DI SINI ===
      // 1. Periksa apakah 'prediction' adalah sebuah Map
      if (responseData.containsKey('prediction') &&
          responseData['prediction'] is Map) {
        final predictionMap =
            responseData['prediction'] as Map<String, dynamic>;

        // 2. Periksa apakah di dalamnya ada key 'predicted_kwh' yang merupakan List
        if (predictionMap.containsKey('predicted_kwh') &&
            predictionMap['predicted_kwh'] is List) {
          final kwhList = predictionMap['predicted_kwh'] as List;

          // 3. Ubah list angka (double) menjadi List<PredictionPoint>
          // Kita gunakan index dari list sebagai jam (0-23)
          return kwhList.asMap().entries.map((entry) {
            int hour = entry.key;
            double kwhValue = (entry.value as num).toDouble();
            return PredictionPoint(hour: hour, predictedKwh: kwhValue);
          }).toList();
        }
      }

      // Jika struktur tidak sesuai, lempar error
      throw Exception('Format respons prediksi tidak valid.');
    } else {
      throw Exception('Gagal memuat data prediksi.');
    }
  }
}
