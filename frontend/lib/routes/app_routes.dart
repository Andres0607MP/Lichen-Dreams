import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/recover_with_code_screen.dart';
import '../screens/recovery_code_screen.dart';
import '../screens/verify_email_screen.dart';
import '../screens/loading_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/admin_users_screen.dart';
import '../screens/admin_notifications_screen.dart';
import '../screens/analysis_screen.dart';
import '../screens/history_screen.dart';
import '../screens/map_screen.dart';
import '../screens/map_explorer_screen.dart';
import '../screens/developer_map_screen.dart';
import '../screens/liquenpedia_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/location_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/settings/account_settings_screen.dart';
import '../screens/settings/privacy_settings_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/appearance_settings_screen.dart';
import '../screens/settings/information_settings_screen.dart';
import '../screens/settings/legal_settings_screen.dart';
import '../screens/settings/terms_conditions_screen.dart';
import '../screens/settings/environmental_report_screen.dart';
import '../screens/settings/environmental_reports_screen.dart';
import '../screens/settings/help_screen.dart';
import '../screens/settings/licenses_screen.dart';
import '../screens/catalogs_screen.dart';
import '../screens/admin_species_screen.dart';
import '../screens/admin_zones_screen.dart';
import '../screens/species_detail_screen.dart';
import 'route_names.dart';

class AppRouter {
  static Map<String, WidgetBuilder> routes = {
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.register: (_) => const RegisterScreen(),
    AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
    AppRoutes.resetPassword: (_) => const ResetPasswordScreen(),
    AppRoutes.recoverWithCode: (_) => const RecoverWithCodeScreen(),
    AppRoutes.recoveryCode: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final code = args is String ? args : '';
      return RecoveryCodeScreen(code: code);
    },
    AppRoutes.verifyEmail: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final email = args is String ? args : '';
      return VerifyEmailScreen(email: email);
    },
    AppRoutes.loading: (_) => const LoadingScreen(),
    AppRoutes.dashboard: (_) => const DashboardScreen(),
    AppRoutes.adminUsers: (_) => const AdminUsersScreen(),
    AppRoutes.adminNotifications: (_) => const AdminNotificationsScreen(),
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
    AppRoutes.species: (_) => const AdminSpeciesScreen(),
    AppRoutes.configuracion: (_) => const SettingsScreen(),
    AppRoutes.accountSettings: (_) => const AccountSettingsScreen(),
    AppRoutes.privacySettings: (_) => const PrivacySettingsScreen(),
    AppRoutes.notificationSettings: (_) => const NotificationSettingsScreen(),
    AppRoutes.appearanceSettings: (_) => const AppearanceSettingsScreen(),
    AppRoutes.informationSettings: (_) => const InformationSettingsScreen(),
    AppRoutes.legalSettings: (_) => const LegalSettingsScreen(),
    AppRoutes.termsConditionsSettings: (_) => const TermsConditionsScreen(),
    AppRoutes.environmentalReports: (_) => const EnvironmentalReportsScreen(),
    AppRoutes.environmentalReport: (_) => const EnvironmentalReportScreen(),
    AppRoutes.helpSettings: (_) => const HelpScreen(),
    AppRoutes.licensesSettings: (_) => const LicensesScreen(),
    AppRoutes.catalogsSettings: (_) => const CatalogsScreen(),
    AppRoutes.adminSpeciesSettings: (_) => const AdminSpeciesScreen(),
    AppRoutes.adminZonesSettings: (_) => const AdminZonesScreen(),
    AppRoutes.speciesDetail: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final species = args is Map<String, dynamic> ? args : <String, dynamic>{};
      return SpeciesDetailScreen(species: species);
    },
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
