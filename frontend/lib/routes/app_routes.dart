import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import 'route_names.dart';

class AppRouter {
  static Map<String, WidgetBuilder> routes = {
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.register: (_) => const RegisterScreen(),
    AppRoutes.dashboard: (_) => const DashboardScreen(),
  };
}
