// top_bar_widget.dart
import 'package:flutter/material.dart';
import '../../login_screen.dart';
import '../../../services/auth_service.dart';

class TopBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? userName;
  final String? userEmail;
  final String? profilePhotoUrl;
  final VoidCallback? onProfileTap; // Callback untuk navigasi ke Edit Profile
  final VoidCallback? onLogoutTap; // Callback khusus untuk logout jika perlu dipisah
  final Widget? leading;

  const TopBarWidget({
    super.key,
    required this.title,
    this.userName,
    this.userEmail, // Tambahkan ini
    this.profilePhotoUrl,
    this.onProfileTap,
    this.onLogoutTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService(); // Anda mungkin tidak membutuhkannya di sini jika callback sudah dihandle

    // Widget untuk area user yang bisa diklik
    Widget userAreaButton = Row(
      mainAxisSize: MainAxisSize.min, // Agar tidak mengambil ruang berlebih
      children: <Widget>[
        // Nama User (sekarang di kiri foto)
        if (userName != null)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              userName!,
              style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                  fontSize: 14),
            ),
          ),
        CircleAvatar(
          backgroundImage: (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty)
              ? NetworkImage(profilePhotoUrl!)
              : null,
          backgroundColor: Colors.grey[300],
          child: (profilePhotoUrl == null || profilePhotoUrl!.isEmpty)
              ? const Icon(Icons.person_outline, color: Colors.grey, size: 20)
              : null,
          radius: 18,
        ),
        // Icon dropdown kecil, opsional jika seluruh area diklik
        // Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
      ],
    );

    return Material(
      elevation: 1.0,
        child: SafeArea( // <-- TAMBAHKAN SAFEAREA DI SINI
        bottom: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        height: preferredSize.height,
        child: Row(
          children: <Widget>[
            if (leading != null) leading!,
            if (leading != null) const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Menggunakan PopupMenuButton dengan child kustom
            PopupMenuButton<String>(
              // Offset untuk menyesuaikan posisi dropdown agar muncul di bawah area user
              offset: const Offset(0, 40), // Sesuaikan nilai Y jika perlu
              // Tooltip bisa dihilangkan jika tidak perlu
              // tooltip: 'User Menu',
              // Menghilangkan ikon panah default dengan menyediakan child kustom
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0), // Beri sedikit padding agar mudah diklik
                child: userAreaButton, // Widget yang memicu popup
              ),
              onSelected: (value) async {
                if (value == 'profile') {
                  onProfileTap?.call();
                } else if (value == 'logout') {
                  // Jika onLogoutTap disediakan, gunakan itu. Jika tidak, handle logout di sini.
                  if (onLogoutTap != null) {
                    onLogoutTap!();
                  } else {
                    await authService.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                            (Route<dynamic> route) => false,
                      );
                    }
                  }
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                // Header Dropdown (Nama dan Email) - Dibuat sebagai PopupMenuItem yang tidak bisa dipilih
                PopupMenuItem<String>(
                  enabled: false, // Agar tidak bisa diklik
                  value: 'header', // Nilai unik
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName ?? 'User Name',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        userEmail ?? 'Email',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(), // Garis pemisah
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined,
                          color: Colors.grey[700], size: 20),
                      const SizedBox(width: 12),
                      const Text('Profile Settings'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red[600], size: 20),
                      const SizedBox(width: 12),
                      Text('Log out', style: TextStyle(color: Colors.red[600])),
                    ],
                  ),
                ),
              ],
              // Kustomisasi bentuk dropdown jika perlu
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              // Kustomisasi warna background dropdown jika perlu
              color: Color(0xFFEFF3F3),
            ),
          ],
        ),
      ),
        ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}