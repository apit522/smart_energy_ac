// lib/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart'; // Pastikan path ini benar
import '../utils/app_colors.dart'; // Jika Anda menggunakan AppColors

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _message; // Untuk menampilkan pesan sukses atau error

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _message = null; // Reset pesan
      });

      try {
        final result = await _authService.sendPasswordResetLink(_emailController.text);

        if (!mounted) return;

        if (result.containsKey('message') && (result['statusCode'] == null || result['statusCode'] < 400) ) {
          // Anggap sukses jika ada 'message' dan tidak ada 'error' atau status code < 400
          // Backend Laravel akan mengirimkan message seperti "We have emailed your password reset link!"
          setState(() {
            _message = result['message'] ?? "Jika email Anda terdaftar, link reset password telah dikirim.";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_message!), backgroundColor: Colors.green),
          );
        } else {
          // Tangani error dari backend
          String errMsg = "Gagal mengirim link reset.";
          if (result.containsKey('errors') && result['errors'] is Map) {
            var errors = result['errors'] as Map;
            // Ambil pesan error pertama dari field email jika ada
            if (errors.containsKey('email') && errors['email'] is List && (errors['email'] as List).isNotEmpty) {
              errMsg = (errors['email'] as List).first;
            } else {
              // Jika format error berbeda, coba ambil message umum
              errMsg = errors.entries.map((e) => '${(e.value as List).join(', ')}').join('\n');
            }
          } else if (result.containsKey('message')) {
            errMsg = result['message'];
          } else if (result.containsKey('error')) {
            errMsg = result['error'];
          }
          setState(() {
            _message = errMsg;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_message!), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _message = 'Terjadi kesalahan: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_message!), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lupa Password', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryColor, // Gunakan warna tema Anda
        leading: IconButton( // Menambahkan tombol kembali agar lebih user-friendly
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // DIBUNGKUS DENGAN SAFEAREA DI SINI
      body: SafeArea(
        child: Center( // Menengahkan konten
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox( // Memberi batas lebar
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Masukkan alamat email Anda yang terdaftar untuk menerima link reset password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your registered email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email tidak boleh kosong';
                        }
                        final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                        if (!emailRegex.hasMatch(value)) {
                          return 'Masukkan alamat email yang valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      onPressed: _sendResetLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16, color: Colors.white),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Kirim Link Reset', style: TextStyle(color: Colors.white)),
                    ),
                    if (_message != null) ...[ // Opsional: menampilkan pesan langsung di halaman
                      const SizedBox(height: 20),
                      Text(
                        _message!,
                        style: TextStyle(
                          color: _message!.toLowerCase().contains('gagal') || _message!.toLowerCase().contains('error')
                              ? Colors.red
                              : Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}