// sidebar_widget.dart
import 'package:flutter/material.dart';
import '../dashboard_layout_screen.dart'; // Untuk enum AppPage
import 'navigation_list_item.dart'; // Widget kustom kita

class SidebarWidget extends StatelessWidget {
  final AppPage selectedPage;
  final Function(AppPage, String) onNavigate;

  const SidebarWidget({
    super.key,
    required this.selectedPage,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF178189); // Warna dari desain Anda
    // Warna dari desain Anda (biru-abu tua) untuk item aktif
    const activeItemBackground = Color(0xFF178189); // Contoh, sesuaikan dengan warna di gambar
    const sidebarBackgroundColor = Colors.white;
    final Color defaultTextColor = Colors.grey[700]!;
    final Color defaultIconColor = Colors.grey[600]!;

    return Material(
      elevation: 2.0,
      child: Container(
        width: 250,
        color: sidebarBackgroundColor,
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.start, // Kita akan atur alignment per item
          children: <Widget>[
            const SizedBox(height: 20), // Spasi di atas logo
            // Logo di Tengah
            Center(
              child: Image.asset(
                'assets/images/logo.png', // Pastikan path logo benar
                height: 60, // Sesuaikan tinggi logo
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.ac_unit, size: 50, color: activeColor),
              ),
            ),
            const SizedBox(height: 15),
            // Garis di Bawah Logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Divider(height: 1, color: Colors.grey[300]),
            ),
            const SizedBox(height: 25),

            // Item Navigasi Dashboard
            // Menggunakan Container untuk memberi background pada item yang aktif
            // dan padding agar mirip desain
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: NavigationListItem(
                title: 'Dashboard',
                icon: Icons.dashboard_outlined, // Contoh ikon
                isSelected: selectedPage == AppPage.dashboard,
                activeColor: activeColor, // Warna teks dan ikon saat aktif
                activeBackgroundColor: activeItemBackground, // Warna background saat aktif
                defaultTextColor: defaultTextColor,
                defaultIconColor: defaultIconColor,
                onTap: () => onNavigate(AppPage.dashboard, 'Dashboard'),
              ),
            ),

            // Item Navigasi Monitoring (ExpansionTile)
            // Agar sejajar, kita atur paddingnya sama dengan NavigationListItem lain
            // dan pastikan properti ExpansionTile diatur untuk visual yang diinginkan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const PageStorageKey<String>('monitoringExpansionTile'),
                  // Untuk membuat "Monitoring" sejajar, kita bisa atur leading dan title secara manual
                  // atau menggunakan NavigationListItem sebagai title jika lebih kompleks
                  // Berdasarkan desain, sepertinya leading icon sejajar dengan Dashboard & Perangkat
                  leading: Icon(
                    Icons.monitor_heart_outlined, // Contoh ikon
                    color: (selectedPage == AppPage.konsumsiDaya || selectedPage == AppPage.suhu)
                        ? activeColor // Jika salah satu sub-item aktif, ikon Monitoring juga bisa aktif
                        : defaultIconColor,
                    size: 24, // Sesuaikan ukuran ikon
                  ),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0), // Padding internal ExpansionTile
                  title: Text(
                    'Monitoring',
                    style: TextStyle(
                        color: (selectedPage == AppPage.konsumsiDaya || selectedPage == AppPage.suhu)
                            ? activeColor
                            : defaultTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.normal // Tidak bold agar mirip desain
                    ),
                  ),
                  // Panah akan muncul di kanan secara default
                  // iconColor: activeColor, // Warna panah saat expand
                  // collapsedIconColor: defaultIconColor, // Warna panah saat collapse
                  initiallyExpanded: selectedPage == AppPage.konsumsiDaya || selectedPage == AppPage.suhu,
                  childrenPadding: const EdgeInsets.only(left: 0), // Indentasi untuk sub-item diatur di NavigationListItem
                  children: <Widget>[
                    // Sub-item Konsumsi Daya
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0), // Hapus padding horizontal jika sudah diatur di NavigationListItem
                      child: NavigationListItem(
                        title: 'Konsumsi Daya',
                        icon: Icons.power_outlined, // Tambahkan ikon untuk Konsumsi Daya
                        isSubItem: true,
                        isSelected: selectedPage == AppPage.konsumsiDaya,
                        activeColor: activeColor,
                        activeBackgroundColor: activeItemBackground,
                        defaultTextColor: defaultTextColor,
                        defaultIconColor: defaultIconColor,
                        onTap: () => onNavigate(AppPage.konsumsiDaya, 'Konsumsi Daya'),
                      ),
                    ),
                    // Sub-item Suhu
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
                      child: NavigationListItem(
                        title: 'Suhu',
                        icon: Icons.thermostat_outlined, // Tambahkan ikon untuk Suhu
                        isSubItem: true,
                        isSelected: selectedPage == AppPage.suhu,
                        activeColor: activeColor,
                        activeBackgroundColor: activeItemBackground,
                        defaultTextColor: defaultTextColor,
                        defaultIconColor: defaultIconColor,
                        onTap: () => onNavigate(AppPage.suhu, 'Suhu'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Item Navigasi Perangkat
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: NavigationListItem(
                title: 'Perangkat',
                icon: Icons.devices_other_outlined, // Contoh ikon
                isSelected: selectedPage == AppPage.perangkat,
                activeColor: activeColor,
                activeBackgroundColor: activeItemBackground,
                defaultTextColor: defaultTextColor,
                defaultIconColor: defaultIconColor,
                onTap: () => onNavigate(AppPage.perangkat, 'Perangkat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}