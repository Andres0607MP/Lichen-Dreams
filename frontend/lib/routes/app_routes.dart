import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/analysis_screen.dart';
import '../screens/result_screen.dart';
import '../screens/map_screen.dart';
import '../screens/liquenpedia_screen.dart';
import '../screens/admin_users_screen.dart';
import 'route_names.dart';

class AppRouter {
  static Map<String, WidgetBuilder> routes = {
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.register: (_) => const RegisterScreen(),
    AppRoutes.dashboard: (_) => const DashboardScreen(),
    AppRoutes.adminUsers: (_) => const AdminUsersScreen(),
    AppRoutes.analisis: (_) => const AnalysisScreen(),
    AppRoutes.historial: (_) => const ResultScreen(),
    AppRoutes.mapa: (_) => const MapScreen(),
    AppRoutes.perfil: (_) => const LiquenPediaScreen(),
  };
}
