import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'routes/app_routes.dart';
import 'routes/route_names.dart';
import 'widgets/app_theme.dart';
import 'state/auth_state.dart';
import 'state/dashboard_state.dart';
import 'state/articles_state.dart';
import 'state/history_state.dart';
import 'state/profile_state.dart';
import 'state/map_state.dart';
import 'state/species_state.dart';
import 'state/users_state.dart';
import 'state/notifications_state.dart';
import 'state/analysis_state.dart';
import 'state/app_settings_state.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiService = ApiService();
  final authState = AuthState(apiService: apiService);
  await authState.initialize();
  runApp(LichenDreamsApp(authState: authState, apiService: apiService));
}

class LichenDreamsApp extends StatelessWidget {
  final AuthState authState;
  final ApiService apiService;
  const LichenDreamsApp({super.key, required this.authState, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authState),
        Provider.value(value: apiService),
        ChangeNotifierProvider(create: (_) => DashboardState(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => ArticlesState(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => HistoryState(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => ProfileState(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => MapState(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => SpeciesState(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => UsersState(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => AnalysisState(apiService: apiService)),
        ChangeNotifierProvider.value(value: NotificationsState.instance),
        ChangeNotifierProvider(create: (_) => AppSettingsState()),
      ],
      child: Consumer<AppSettingsState>(
        builder: (context, appSettings, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Lichen Dreams',
            theme: AppTheme.lightTheme(),
            initialRoute: AppRoutes.login,
            onGenerateRoute: AppRouter.generateRoute,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    appSettings.textScaleFactor,
                  ),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
