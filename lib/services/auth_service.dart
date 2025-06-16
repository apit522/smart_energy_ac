// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io' as io; // Memberi alias untuk File dari dart:io
import 'dart:typed_data'; // Untuk Uint8List
import 'package:flutter/foundation.dart' show kIsWeb; // Untuk mengecek platform
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart'; // Untuk MediaType
import '../utils/constants.dart'; // Pastikan AppConstants.baseUrl ada di sini

// Kunci untuk SharedPreferences
const String _tokenKey = 'auth_token';
const String _userNameKey = 'user_name';
const String _userEmailKey = 'user_email';
const String _userPhotoUrlKey = 'user_photo_url';
const String _rememberMeExpiryKey = 'remember_me_expiry';

class AuthService {
  // Method internal untuk menyimpan data user dan token
  // Sekarang juga menangani logika "Remember Me"
  Future<void> _saveUserData(Map<String, dynamic> userData, bool rememberMe) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, userData['access_token']);
    if (userData.containsKey('user')) {
      await prefs.setString(_userNameKey, userData['user']['name'] ?? '');
      await prefs.setString(_userEmailKey, userData['user']['email'] ?? '');
      await prefs.setString(_userPhotoUrlKey, userData['user']['profile_photo_url'] ?? '');
      print('AuthService saved user_photo_url: ${userData['user']['profile_photo_url']}');
    }

    if (rememberMe) {
      // Simpan timestamp kedaluwarsa "Remember Me" (1 hari dari sekarang)
      final expiryTime = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
      await prefs.setInt(_rememberMeExpiryKey, expiryTime);
      print('Remember Me: Expiry set to ${DateTime.fromMillisecondsSinceEpoch(expiryTime)}');
    } else {
      // Jika "Remember Me" tidak dicentang, hapus timestamp kedaluwarsa yang mungkin ada
      await prefs.remove(_rememberMeExpiryKey);
      print('Remember Me: Not active, expiry cleared.');
    }
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String password, String passwordConfirmation) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/register'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data.containsKey('access_token')) {
      // Untuk registrasi, kita anggap "Remember Me" tidak aktif secara default,
      // atau Anda bisa menambahkan parameter rememberMe ke fungsi register jika perlu.
      // Saat ini, _saveUserData akan dipanggil dari login dengan status rememberMe.
      // Jika ingin menyimpan data user langsung setelah register (tanpa login otomatis),
      // Anda perlu memutuskan apakah akan mengaktifkan "Remember Me" di sini.
      // Untuk konsistensi, sebaiknya _saveUserData dipanggil dari login.
      // Jika register langsung login, maka tidak perlu _saveUserData di sini.
      // Anggap saja register tidak langsung login dan tidak ada "remember me".
      // Jika register langsung login, maka panggil _saveUserData(data, false); atau dengan parameter rememberMe.
    }
    return data;
  }

  Future<Map<String, dynamic>> login(String nameOrUsername, String password, bool rememberMe) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'name': nameOrUsername, // <-- UBAH KEY MENJADI 'name'
        'password': password,
      }),
    );
    final data = jsonDecode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) && data.containsKey('access_token')) {
      await _saveUserData(data, rememberMe);
    }
    return data;
  }

  Future<Map<String, String?>> getUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_userNameKey),
      'email': prefs.getString(_userEmailKey),
      'photo_url': prefs.getString(_userPhotoUrlKey),
      'token': prefs.getString(_tokenKey), // Menggunakan _tokenKey yang sudah didefinisikan
    };
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_tokenKey);

    if (token != null) {
      try {
        await http.post(
          Uri.parse('${AppConstants.baseUrl}/logout'),
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      } catch (e) {
        print("Error during API logout call: $e");
        // Tetap lanjutkan proses logout di sisi klien meskipun API call gagal
      }
    }
    // Hapus semua data sesi yang relevan
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userPhotoUrlKey);
    await prefs.remove(_rememberMeExpiryKey); // Penting untuk menghapus expiry saat logout
    print('User logged out, all session data cleared.');
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Method baru untuk mengecek status auto login berdasarkan "Remember Me"
  Future<bool> checkAutoLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_tokenKey);
    final int? expiryTimestamp = prefs.getInt(_rememberMeExpiryKey);

    if (token == null || token.isEmpty) {
      print('Auto Login Check: No token found.');
      await _clearSessionDataOnExpiryOrInvalid(); // Pastikan semua bersih jika token tidak ada
      return false;
    }

    if (expiryTimestamp != null) { // Hanya periksa expiry jika "Remember Me" pernah aktif
      final DateTime expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
      if (expiryDate.isBefore(DateTime.now())) {
        print('Auto Login Check: remember_me_expiry is in the past. Clearing session.');
        await _clearSessionDataOnExpiryOrInvalid();
        return false;
      }
      // "Remember Me" aktif dan belum kedaluwarsa
      print('Auto Login Check: Token found and remember_me_expiry is valid. User can auto-login.');
      return true;
    } else {
      // Token ada, tapi "Remember Me" tidak aktif.
      // Untuk perilaku "tetap login selama refresh", kita return true di sini.
      // Server akan memvalidasi token pada request API berikutnya.
      // Jika token ini dimaksudkan untuk sesi yang sangat singkat, logika lain mungkin diperlukan.
      print('Auto Login Check: Token found, but no remember_me_expiry (Remember Me was not checked). Treating as active session for now.');
      return true; // <--- PERUBAHAN DI SINI
    }
  }

  // Helper untuk membersihkan semua data sesi jika sesi kedaluwarsa atau tidak valid
  Future<void> _clearSessionDataOnExpiryOrInvalid() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userPhotoUrlKey);
    await prefs.remove(_rememberMeExpiryKey);
    print('Session data cleared due to expiry or invalid state.');
  }

  // Fungsi isLoggedIn() bisa dipertimbangkan untuk diganti atau disesuaikan
  // karena checkAutoLoginStatus() lebih spesifik untuk alur startup.
  Future<bool> isLoggedIn() async {
    // Untuk pengecekan umum apakah ada token (tanpa memperdulikan remember me expiry untuk saat ini)
    // Atau bisa juga memanggil checkAutoLoginStatus
    // return await getToken() != null; // Versi sederhana sebelumnya
    return await checkAutoLoginStatus(); // Menggunakan logika yang sama dengan auto login
  }

  Future<Map<String, dynamic>> updateProfile({
    required String currentName,
    String? newName,
    String? currentEmail,
    String? newEmail,
    Uint8List? profileImageBytes,
    String? profileImageFileName,
    io.File? profileImage_io,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_tokenKey);
    if (token == null) {
      return {'error': 'Not authenticated'};
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.baseUrl}/user/profile'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      request.fields['name'] = newName;
    }

    if (newEmail != null && newEmail.isNotEmpty && newEmail != currentEmail) {
      request.fields['email'] = newEmail;
    }

    if (kIsWeb && profileImageBytes != null && profileImageFileName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'profile_photo',
          profileImageBytes,
          filename: profileImageFileName,
          // contentType: MediaType('image', 'jpeg'), // Opsional, bisa diset jika tahu pasti
        ),
      );
    } else if (!kIsWeb && profileImage_io != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_photo',
          profileImage_io.path,
          contentType: MediaType('image', profileImage_io.path.split('.').last.toLowerCase()),
        ),
      );
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('AuthService updateProfile - Response Status Code: ${response.statusCode}');
      print('AuthService updateProfile - Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data.containsKey('user')) {
          // Update data user di SharedPreferences setelah profil berhasil diupdate
          await prefs.setString(_userNameKey, data['user']['name'] ?? currentName);
          await prefs.setString(_userEmailKey, data['user']['email'] ?? currentEmail);
          await prefs.setString(_userPhotoUrlKey, data['user']['profile_photo_url'] ?? '');
        }
        return data;
      } else {
        return data; // Kembalikan error dari server
      }
    } catch (e) {
      print('AuthService updateProfile - CATCH error: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_tokenKey); // Gunakan konstanta _tokenKey
    if (token == null) {
      return {'error': 'Not authenticated'};
    }

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/user/change-password'), // Endpoint baru
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, String>{
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      }),
    );

    print('AuthService changePassword - Response Status Code: ${response.statusCode}');
    print('AuthService changePassword - Response Body: ${response.body}');

    // Tidak perlu decode jika hanya pesan sukses/error, tapi jika ada data user baru, decode
    // Jika backend hanya mengembalikan message, tidak perlu jsonDecode jika tidak ingin error saat body kosong atau bukan JSON
    try {
      final data = jsonDecode(response.body);
      return data; // Kembalikan data JSON jika ada
    } catch (e) {
      // Jika body bukan JSON (misalnya hanya string pesan atau error HTML)
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'message': response.body}; // Anggap sebagai pesan sukses jika status code OK
      }
      return {'error': response.body.isNotEmpty ? response.body : 'Failed to change password', 'statusCode': response.statusCode};
    }
  }

  Future<Map<String, dynamic>> sendPasswordResetLink(String email) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/forgot-password'), // Endpoint baru
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'email': email,
      }),
    );

    print('AuthService sendPasswordResetLink - Response Status Code: ${response.statusCode}');
    print('AuthService sendPasswordResetLink - Response Body: ${response.body}');

    try {
      final data = jsonDecode(response.body);
      // Tambahkan status code ke data agar bisa dicek di UI jika perlu
      // Meskipun status code sudah ada di response.statusCode
      // Ini berguna jika jsonDecode berhasil tapi status code bukan 2xx
      if (data is Map<String, dynamic>) { // Pastikan data adalah Map
        data['statusCode'] = response.statusCode;
      }
      return data;
    } catch (e) {
      // Jika body bukan JSON (misalnya hanya string pesan atau error HTML)
      if (response.statusCode == 200 || response.statusCode == 201) { // Sukses tapi body bukan JSON? Jarang terjadi
        return {'message': response.body.isNotEmpty ? response.body : 'Request successful', 'statusCode': response.statusCode};
      }
      return {'error': response.body.isNotEmpty ? response.body : 'Failed to send reset link', 'statusCode': response.statusCode};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/reset-password'), // Endpoint baru
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'token': token,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );

    print('AuthService resetPassword - Response Status Code: ${response.statusCode}');
    print('AuthService resetPassword - Response Body: ${response.body}');

    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        data['statusCode'] = response.statusCode;
      }
      return data;
    } catch (e) {
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'message': response.body.isNotEmpty ? response.body : 'Password reset successful', 'statusCode': response.statusCode};
      }
      return {'error': response.body.isNotEmpty ? response.body : 'Failed to reset password', 'statusCode': response.statusCode};
    }
  }
}