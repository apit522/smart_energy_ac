// lib/screens/login_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard/dashboard_layout_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../utils/url_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // _usernameController sekarang akan digunakan untuk input 'name'
  final TextEditingController _nameController = TextEditingController(); // Ganti nama variabel agar lebih jelas
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        // Panggil login dengan _nameController.text sebagai argumen pertama
        final result = await _authService.login(
          _nameController.text, // Mengirimkan isi dari input nama
          _passwordController.text,
          _rememberMe,
        );

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        if (result.containsKey('access_token')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login Berhasil!')),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardLayoutScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['message'] ??
                    'Login Gagal! Nama atau password salah.')), // Sesuaikan pesan error
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // DIBUNGKUS DENGAN SAFEAREA DI SINI
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Panel Kiri (Promotional)
                  if (MediaQuery.of(context).size.width > 800)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF178189), Color(0xFF073A3E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Image.asset(
                                'assets/images/side_image.png',
                                height: 200,
                                errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image, size: 100, color: Colors.white54),
                              ),
                            ),
                            const SizedBox(height: 30),
                            const Text('Smart Energy AC',textAlign: TextAlign.left, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 10),
                            const Text('Choice for Efficient Cooling', style: TextStyle(fontSize: 24, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  if (MediaQuery.of(context).size.width > 800) const SizedBox(width: 40),

                  // Panel Kanan (Form Login)
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Image.asset('assets/images/logo.png', height: 80,
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.lightbulb_outline, size: 60, color: Color(0xFF178189)),
                            ),
                            const SizedBox(height: 20),
                            const Text('Dashboard Login', textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF073A3E)),
                            ),
                            const SizedBox(height: 30),
                            // TextFormField untuk Name
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                  labelText: 'Name',
                                  hintText: 'Enter your Name',
                                  filled: true,
                                  fillColor: Color(0xFFF0F0F0),
                                  border: OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                      borderRadius: BorderRadius.all(Radius.circular(8)))),
                              keyboardType: TextInputType.name,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Nama tidak boleh kosong';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // TextFormField untuk Password
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter your Password',
                                  filled: true,
                                  fillColor: const Color(0xFFF0F0F0),
                                  border: const OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                      borderRadius: BorderRadius.all(Radius.circular(8))),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordObscured
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey[600],
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordObscured = !_isPasswordObscured;
                                      });
                                    },
                                  )),
                              obscureText: _isPasswordObscured,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password tidak boleh kosong';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            CheckboxListTile(
                              title: const Text("Remember Me"),
                              value: _rememberMe,
                              onChanged: (newValue) {
                                setState(() {
                                  _rememberMe = newValue!;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              activeColor: const Color(0xFF178189),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Lupa Password?',
                                    style: TextStyle(
                                      color: Color(0xFF178189),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF178189),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(fontSize: 18, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(child: RichText(
                              text: TextSpan(
                                text: "Don't have an account? ",
                                style: const TextStyle(color: Colors.black54, fontSize: 14),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: 'Sign up',
                                    style: const TextStyle(
                                      color: Color(0xFF178189),
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (context) => const RegisterScreen()),
                                        );
                                      },
                                  ),
                                ],
                              ),
                            ),),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}