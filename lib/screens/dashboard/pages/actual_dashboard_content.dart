// lib/screens/dashboard/pages/actual_dashboard_content.dart
import 'package:flutter/material.dart';
import '../widgets/welcome_banner.dart'; // Import widget banner
import '../../../services/auth_service.dart'; // Untuk mendapatkan nama user

class ActualDashboardContent extends StatefulWidget {
  const ActualDashboardContent({super.key});

  @override
  State<ActualDashboardContent> createState() => _ActualDashboardContentState();
}

class _ActualDashboardContentState extends State<ActualDashboardContent> {
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final userDetails = await AuthService().getUserDetails();
    if (mounted) {
      setState(() {
        _userName = userDetails['name'] ?? 'User';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Widget Banner Sapaan di bagian atas
        WelcomeBanner(userName: _userName),
        const SizedBox(height: 24),

        // Anda bisa menambahkan konten dashboard lainnya di sini
        const Text(
          'Analisis Data',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        // Contoh: Expanded(child: GridView(...) atau ListView(...))
      ],
    );
  }
}