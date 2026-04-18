import '../models/home_dashboard_snapshot.dart';

abstract interface class HomeDashboardService {
  Future<HomeDashboardSnapshot> loadDashboard();
}
