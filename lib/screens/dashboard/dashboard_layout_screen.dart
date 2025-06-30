// dashboard_layout_screen.dart
import 'package:flutter/material.dart';
import 'package:smart_energy_ac/screens/dashboard/pages/DeviceScreen.dart';
import 'package:smart_energy_ac/screens/dashboard/pages/edit_profile_screen.dart';
import 'widgets/sidebar_widget.dart';
import 'widgets/top_bar_widget.dart';
import 'pages/actual_dashboard_content.dart';
import 'pages/konsumsi_daya_content.dart';
import 'pages/suhu_content.dart';
import 'pages/perangkat_content.dart';
import '../../services/auth_service.dart';
import 'widgets/welcome_banner.dart';

// Enum untuk mempermudah pengelolaan halaman
enum AppPage { dashboard, konsumsiDaya, suhu, perangkat, editProfile }

const double kMobileBreakpoint = 768.0; // Tentukan breakpoint untuk mobile

class DashboardLayoutScreen extends StatefulWidget {
  const DashboardLayoutScreen({super.key});

  @override
  State<DashboardLayoutScreen> createState() => _DashboardLayoutScreenState();
}

class _DashboardLayoutScreenState extends State<DashboardLayoutScreen> {
  AppPage _selectedPage = AppPage.dashboard;
  String _currentPageTitle = "Dashboard";
  final AuthService _authService = AuthService();
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>(); // Kunci untuk Scaffold

  String _userName = 'User';
  String? _userEmail;
  String? _userPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userDetails = await _authService.getUserDetails();
    if (mounted) {
      // Selalu cek mounted sebelum setState di async operation
      setState(() {
        _userName = userDetails['name'] ?? 'User';
        _userEmail = userDetails['email'];
        _userPhotoUrl = userDetails['photo_url'];
      });
    }
  }

  Future<void> refreshUserData() async {
    await _loadUserData();
  }

  Widget _getContentWidget() {
    switch (_selectedPage) {
      case AppPage.dashboard:
        return const ActualDashboardContent();
      case AppPage.konsumsiDaya:
        return const KonsumsiDayaContent();
      case AppPage.suhu:
        return const SuhuContent();
      case AppPage.perangkat:
        return const DeviceScreen();
      // case AppPage.editProfile: // Halaman edit profile akan dinavigasi secara terpisah
      //   return EditProfileScreen(onProfileUpdated: refreshUserData);
      default:
        return const ActualDashboardContent();
    }
  }

  void _navigateTo(AppPage page, String title, {bool isMobile = false}) {
    setState(() {
      _selectedPage = page;
      _currentPageTitle = title;
    });
    if (isMobile && _scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop(); // Tutup drawer jika di mobile
    }
  }

  void _onProfileTapped() {
    // Untuk edit profile, kita akan navigasi ke screen baru saja
    // tidak mengganti _selectedPage di sini, kecuali Anda mau EditProfileScreen jadi bagian dari konten utama
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                EditProfileScreen(onProfileUpdated: refreshUserData),
          ),
        )
        .then((_) {
          // Setelah kembali dari EditProfileScreen, refresh data user jika perlu
          // refreshUserData(); // Anda sudah memanggil ini via callback onProfileUpdated
        });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < kMobileBreakpoint;
        if (isMobile) {
          // Tampilan Mobile
          return Scaffold(
            key: _scaffoldKey,
            appBar: TopBarWidget(
              // Gunakan TopBarWidget sebagai AppBar
              title: _currentPageTitle,
              userName: _userName,
              userEmail: _userEmail,
              profilePhotoUrl: _userPhotoUrl,
              onProfileTap: _onProfileTapped,
              leading: IconButton(
                // Tombol menu untuk membuka drawer
                icon: const Icon(Icons.menu),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
            drawer: Drawer(
              // Sidebar menjadi Drawer
              child: SidebarWidget(
                selectedPage: _selectedPage,
                onNavigate: (page, title) =>
                    _navigateTo(page, title, isMobile: true),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _getContentWidget(),
              ),
            ),
          );
        } else {
          // Tampilan Desktop/Web (Layout Anda yang sudah ada)
          return Scaffold(
            // Tetap gunakan Scaffold untuk konsistensi background dan struktur
            backgroundColor: Colors.grey[100],
            body: Row(
              children: [
                SidebarWidget(
                  selectedPage: _selectedPage,
                  onNavigate: (page, title) =>
                      _navigateTo(page, title, isMobile: false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment
                        .stretch, // Agar TopBarWidget mengisi lebar
                    children: [
                      TopBarWidget(
                        title: _currentPageTitle,
                        userName: _userName,
                        userEmail: _userEmail,
                        profilePhotoUrl: _userPhotoUrl,
                        onProfileTap: _onProfileTapped,
                        // Tidak ada leading di sini untuk versi desktop
                      ),
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 36.0),
                      //   child: WelcomeBanner(userName: _userName),
                      // ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: _getContentWidget(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
