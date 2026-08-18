import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/loading_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/admin_users_screen.dart';
import '../screens/analysis_screen.dart';
import '../screens/history_screen.dart';
import '../screens/map_screen.dart';
import '../screens/map_explorer_screen.dart';
import '../screens/developer_map_screen.dart';
import '../screens/liquenpedia_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/location_screen.dart';
import '../screens/species_screen.dart';
import '../screens/settings_screen.dart';
import 'route_names.dart';

class AppRouter {
  static Map<String, WidgetBuilder> routes = {
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.register: (_) => const RegisterScreen(),
    AppRoutes.loading: (_) => const LoadingScreen(),
    AppRoutes.dashboard: (_) => const DashboardScreen(),
    AppRoutes.adminUsers: (_) => const AdminUsersScreen(),
    AppRoutes.analisis: (_) => const AnalysisScreen(),
    AppRoutes.historial: (_) => const HistoryScreen(),
    AppRoutes.mapa: (_) => const MapScreen(),
    AppRoutes.mapExplorer: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final pointId = args is int ? args : 0;
      return MapExplorerScreen(pointId: pointId);
    },
    AppRoutes.developerMap: (_) => const DeveloperMapScreen(),
    AppRoutes.perfil: (_) => const ProfileScreen(),
    AppRoutes.liquenpedia: (_) => const LiquenpediaScreen(),
    AppRoutes.location: (_) => const LocationScreen(),
    AppRoutes.species: (_) => const SpeciesScreen(),
    AppRoutes.configuracion: (_) => const SettingsScreen(),
  };

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(
        builder: builder,
        settings: settings,
      );
    }
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text('No route found for ${settings.name}'),
        ),
      ),
    );
  }
}
