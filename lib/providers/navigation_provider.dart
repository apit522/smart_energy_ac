import 'package:flutter/material.dart';

enum AppPage { dashboard, konsumsiDaya, suhu, perangkat, editProfile }

class NavigationProvider with ChangeNotifier {
  AppPage _currentPage = AppPage.dashboard;
  bool _isMonitoringExpanded = false;

  AppPage get currentPage => _currentPage;
  bool get isMonitoringExpanded => _isMonitoringExpanded;

  void changePage(AppPage newPage) {
    _currentPage = newPage;
    // Jika halaman baru bukan bagian dari monitoring, tutup dropdown monitoring
    if (newPage != AppPage.konsumsiDaya && newPage != AppPage.suhu) {
      _isMonitoringExpanded = false;
    }
    notifyListeners();
  }

  void toggleMonitoringExpanded() {
    _isMonitoringExpanded = !_isMonitoringExpanded;
    notifyListeners();
  }

  String get currentPageTitle {
    switch (_currentPage) {
      case AppPage.dashboard:
        return 'Dashboard';
      case AppPage.konsumsiDaya:
        return 'Konsumsi Daya';
      case AppPage.suhu:
        return 'Suhu';
      case AppPage.perangkat:
        return 'Perangkat';
      case AppPage.editProfile:
        return 'Edit Profile';
      default:
        return 'Dashboard';
    }
  }
}