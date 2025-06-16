import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard/dashboard_layout_screen.dart';
import 'package:provider/provider.dart';
import 'providers/navigation_provider.dart';
import 'services/auth_service.dart';
import 'screens/reset_password_screen.dart';

void main() async { // Ubah menjadi async
  WidgetsFlutterBinding.ensureInitialized(); // Wajib ada jika ada await sebelum runApp
  final AuthService authService = AuthService();
  bool autoLogin = await authService.checkAutoLoginStatus();
  runApp(MyApp(autoLogin: autoLogin));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key,required this.autoLogin});
  final bool autoLogin; // Terima status autoLogin

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart AC Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal, // Anda bisa sesuaikan ini
        textTheme: GoogleFonts.poppinsTextTheme( // Menggunakan Google Fonts (contoh)
          Theme.of(context).textTheme,
        ),
        scaffoldBackgroundColor: Colors.white, // Background utama putih seperti desain
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        print('DEBUG onGenerateRoute: Menerima rute -> ${settings.name}');

        // Mendapatkan path URL sebenarnya dari browser, ini lebih andal untuk web
        final uri = Uri.parse(Uri.base.toString());
        final path = uri.path; // Ini akan '/reset-password'
        print('DEBUG onGenerateRoute: Path dari URI.base -> $path');

        if (path.startsWith('/reset-password')) { // Gunakan path dari URI.base
          final token = uri.queryParameters['token'];
          final email = uri.queryParameters['email'];

          if (token != null && email != null) {
            return MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(token: token, email: email),
            );
          }
        }

        // Jika tidak ada path spesifik di URL (atau path-nya '/'),
        // gunakan logika auto-login untuk menentukan halaman awal.
        // Ini menggantikan fungsi `home`.
        return MaterialPageRoute(
          builder: (context) => autoLogin ? const DashboardLayoutScreen() : const LoginScreen(),
        );
      },
      // home: autoLogin ? const DashboardLayoutScreen() : const LoginScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
