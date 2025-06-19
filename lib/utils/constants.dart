// lib/utils/constants.dart
class AppConstants {
  // Ganti dengan IP Address lokal Anda jika menjalankan di emulator Android, JANGAN localhost atau 127.0.0.1
  // Jika menggunakan emulator Android, IP address PC Anda di jaringan lokal (misal: 192.168.1.10)
  // Jika menggunakan web atau emulator iOS, localhost atau 127.0.0.1:8000 bisa bekerja.
  // Untuk kemudahan, saat development di emulator Android, gunakan IP PC Anda.
  // Cari tahu IP Anda (misal: 'ipconfig' di Windows, 'ifconfig' di macOS/Linux)
  static const String baseUrl =
      'http://127.0.0.1:8000/api'; // 10.0.2.2 adalah alias untuk localhost PC dari emulator Android
  //static const String baseUrl = 'http://172.16.95.80:8000/api'; // Ganti X.X dengan IP Anda
}
