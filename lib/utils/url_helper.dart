// lib/utils/url_helper.dart

// Export implementasi stub secara default.
// Jika kondisi `dart.library.html` terpenuhi (artinya platformnya adalah web),
// maka export implementasi dari 'url_helper_web.dart'.
export 'url_helper_stub.dart' // Implementasi default (untuk mobile/non-web)
if (dart.library.html) 'url_helper_web.dart'; // Implementasi khusus web
