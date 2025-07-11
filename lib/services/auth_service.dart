// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import '../utils/constants.dart';

// Kunci untuk SharedPreferences
const String _tokenKey = 'auth_token';
const String _userNameKey = 'user_name';
const String _userEmailKey = 'user_email';
const String _userPhotoUrlKey = 'user_photo_url';
const String _rememberMeExpiryKey = 'remember_me_expiry';

class AuthService {
  Future<void> _getCsrfCookie() async {
    // Hanya jalankan ini jika platformnya adalah web, karena hanya relevan untuk autentikasi SPA
    if (kIsWeb) {
      try {
        // Ganti dengan URL backend Anda yang sesungguhnya jika berbeda
        final url = Uri.parse(
          '${AppConstants.baseUrl.replaceAll('/api', '')}/sanctum/csrf-cookie',
        );
        print('DEBUG: Requesting CSRF cookie from $url');
        await http.get(url);
        print('DEBUG: CSRF cookie request sent successfully.');
      } catch (e) {
        print('Error getting CSRF cookie: $e');
        throw Exception(
          'Tidak dapat terhubung ke server. Periksa koneksi Anda.',
        );
      }
    }
  }

  Future<void> _saveUserData(
    Map<String, dynamic> userData,
    bool rememberMe,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, userData['access_token']);
    if (userData.containsKey('user')) {
      await prefs.setString(_userNameKey, userData['user']['name'] ?? '');
      await prefs.setString(_userEmailKey, userData['user']['email'] ?? '');
      await prefs.setString(
        _userPhotoUrlKey,
        userData['user']['profile_photo_url'] ?? '',
      );
      print(
        'AuthService saved user_photo_url: ${userData['user']['profile_photo_url']}',
      );
    }

    if (rememberMe) {
      final expiryTime = DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
      await prefs.setInt(_rememberMeExpiryKey, expiryTime);
      print(
        'Remember Me: Expiry set to ${DateTime.fromMillisecondsSinceEpoch(expiryTime)}',
      );
    } else {
      await prefs.remove(_rememberMeExpiryKey);
      print('Remember Me: Not active, expiry cleared.');
    }
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    // Panggil CSRF cookie sebelum register
    await _getCsrfCookie();

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
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> login(
    String nameOrUsername,
    String password,
    bool rememberMe,
  ) async {
    // Panggil CSRF cookie sebelum login
    await _getCsrfCookie();

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'name': nameOrUsername,
        'password': password,
      }),
    );

    print('DEBUG: Login API Response Status: ${response.statusCode}');
    print('DEBUG: Login API Response Body: ${response.body}');

    if (response.statusCode >= 400) {
      // Jika status code adalah error (seperti 419, 422, 500), kembalikan body error
      return jsonDecode(response.body);
    }

    final data = jsonDecode(response.body);
    if (data.containsKey('access_token')) {
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
      'token': prefs.getString(_tokenKey),
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
      }
    }
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userPhotoUrlKey);
    await prefs.remove(_rememberMeExpiryKey);
    print('User logged out, all session data cleared.');
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> checkAutoLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_tokenKey);
    final int? expiryTimestamp = prefs.getInt(_rememberMeExpiryKey);

    if (token == null || token.isEmpty) {
      await _clearSessionDataOnExpiryOrInvalid();
      return false;
    }

    if (expiryTimestamp != null) {
      final DateTime expiryDate = DateTime.fromMillisecondsSinceEpoch(
        expiryTimestamp,
      );
      if (expiryDate.isBefore(DateTime.now())) {
        await _clearSessionDataOnExpiryOrInvalid();
        return false;
      }
      return true;
    } else {
      // Perilaku baru: jika tidak ada expiry, anggap sebagai sesi biasa (tetap login saat refresh)
      return true;
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
        ),
      );
    } else if (!kIsWeb && profileImage_io != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_photo',
          profileImage_io.path,
          contentType: MediaType(
            'image',
            profileImage_io.path.split('.').last.toLowerCase(),
          ),
        ),
      );
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(
        'AuthService updateProfile - Response Status Code: ${response.statusCode}',
      );
      print('AuthService updateProfile - Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data.containsKey('user')) {
          // Update data user di SharedPreferences setelah profil berhasil diupdate
          await prefs.setString(
            _userNameKey,
            data['user']['name'] ?? currentName,
          );
          await prefs.setString(
            _userEmailKey,
            data['user']['email'] ?? currentEmail,
          );
          await prefs.setString(
            _userPhotoUrlKey,
            data['user']['profile_photo_url'] ?? '',
          );
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
    final String? token = prefs.getString(_tokenKey);
    if (token == null) {
      return {'error': 'Not authenticated'};
    }

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/user/change-password'),
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

    print(
      'AuthService changePassword - Response Status Code: ${response.statusCode}',
    );
    print('AuthService changePassword - Response Body: ${response.body}');

    try {
      final data = jsonDecode(response.body);
      return data; // Kembalikan data JSON jika ada
    } catch (e) {
      // Jika body bukan JSON (misalnya hanya string pesan atau error HTML)
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'message': response.body,
        }; // Anggap sebagai pesan sukses jika status code OK
      }
      return {
        'error': response.body.isNotEmpty
            ? response.body
            : 'Failed to change password',
        'statusCode': response.statusCode,
      };
    }
  }

  Future<Map<String, dynamic>> sendPasswordResetLink(String email) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/forgot-password'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, String>{'email': email}),
    );

    print(
      'AuthService sendPasswordResetLink - Response Status Code: ${response.statusCode}',
    );
    print(
      'AuthService sendPasswordResetLink - Response Body: ${response.body}',
    );

    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        data['statusCode'] = response.statusCode;
      }
      return data;
    } catch (e) {
      // Jika body bukan JSON (misalnya hanya string pesan atau error HTML)
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'message': response.body.isNotEmpty
              ? response.body
              : 'Request successful',
          'statusCode': response.statusCode,
        };
      }
      return {
        'error': response.body.isNotEmpty
            ? response.body
            : 'Failed to send reset link',
        'statusCode': response.statusCode,
      };
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/reset-password'),
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

    print(
      'AuthService resetPassword - Response Status Code: ${response.statusCode}',
    );
    print('AuthService resetPassword - Response Body: ${response.body}');

    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        data['statusCode'] = response.statusCode;
      }
      return data;
    } catch (e) {
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'message': response.body.isNotEmpty
              ? response.body
              : 'Password reset successful',
          'statusCode': response.statusCode,
        };
      }
      return {
        'error': response.body.isNotEmpty
            ? response.body
            : 'Failed to reset password',
        'statusCode': response.statusCode,
      };
    }
  }
}
