// lib/utils/url_helper_web.dart
import 'package:web/web.dart' as web;

// Implementasi ini HANYA untuk web.
void updateUrl(String path) {
  web.window.history.pushState(null, '', path);
}
