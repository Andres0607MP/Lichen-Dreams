import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'routes/app_routes.dart';
import 'routes/route_names.dart';
import 'services/navigation_service.dart';
import 'services/notification_sound_service.dart';
import 'widgets/app_theme.dart';
import 'state/auth_state.dart';
import 'state/dashboard_state.dart';
import 'state/ia_monitoring_state.dart';
import 'state/connectivity_state.dart';
import 'services/ia_monitoring_service.dart';
import 'state/articles_state.dart';
import 'state/history_state.dart';
import 'state/profile_state.dart';
import 'state/map_state.dart';
import 'state/catalog_state.dart';
import 'state/users_state.dart';
import 'state/notifications_state.dart';
import 'state/analysis_state.dart';
import 'state/app_settings_state.dart';
import 'services/api_service.dart';
import 'services/android_notification_service.dart';
import 'services/connectivity_service.dart';
import 'package:flutter/widgets.dart';

void main() async {
   WidgetsFlutterBinding.ensureInitialized();
   debugPrint('APP START');
   await NotificationSoundService.instance.initialize();
   await AndroidNotificationService.instance.initialize();
   final apiService = ApiService();
   final authState = AuthState(apiService: apiService);
   final iaMonitoringService = IaMonitoringService(apiService);
   final iaMonitoringState = IaMonitoringState(iaMonitoringService);
   debugPrint('CHECKING STORED SESSION');
   await authState.initialize();
   // Initialize lifecycle observer for session validation
   authState.initLifecycle();
   // TODO: Add session validation logic
   debugPrint('TOKEN FOUND: ${authState.token != null && authState.token!.isNotEmpty}');
   debugPrint('USER RESTORED: ${authState.isAuthenticated}');
   debugPrint('AUTH READY');
   runApp(LichenDreamsApp(
     authState: authState,
     apiService: apiService,
     iaMonitoringService: iaMonitoringService,
     iaMonitoringState: iaMonitoringState,
   ));
 }

class _ConnectivityOverlay extends StatefulWidget {
  final Widget child;
  const _ConnectivityOverlay({required this.child});

  @override
  State<_ConnectivityOverlay> createState() => _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends State<_ConnectivityOverlay> {
  late final ConnectivityState _connectivityState;
  bool _isShowingSnackBar = false;

  @override
  void initState() {
    super.initState();
    _connectivityState = Provider.of<ConnectivityState>(context, listen: false);
    _connectivityState.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _connectivityState.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (!mounted) return;
    final status = _connectivityState.status;
    if (status == ConnectivityStatus.disconnected) {
      if (!_isShowingSnackBar) {
        _isShowingSnackBar = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión a internet'),
              duration: Duration(seconds: 3),
            ),
          ).closed.then((reason) {
            _isShowingSnackBar = false;
          });
        });
      }
    } else if (status == ConnectivityStatus.connected) {
      if (!_isShowingSnackBar) {
        _isShowingSnackBar = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conexión restaurada'),
              duration: Duration(seconds: 2),
            ),
          ).closed.then((reason) {
            _isShowingSnackBar = false;
          });
        });
      }
    }
    // Checking status: no UI needed
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class LichenDreamsApp extends StatelessWidget {
  final AuthState authState;
  final ApiService apiService;
  final IaMonitoringService iaMonitoringService;
  final IaMonitoringState iaMonitoringState;

  const LichenDreamsApp({
    super.key,
    required this.authState,
    required this.apiService,
    required this.iaMonitoringService,
    required this.iaMonitoringState,
  });

  @override
  Widget build(BuildContext context) {
    final initialRoute = authState.isAuthenticated ? AppRoutes.loading : AppRoutes.login;
    return MultiProvider(
       providers: [
         ChangeNotifierProvider.value(value: authState),
         Provider.value(value: apiService),
         Provider.value(value: iaMonitoringService),
         ChangeNotifierProvider.value(value: iaMonitoringState),
         ChangeNotifierProvider(create: (_) => DashboardState(apiService: apiService)),
         ChangeNotifierProvider(create: (_) => ArticlesState(apiService: apiService)),
         ChangeNotifierProvider(create: (_) => HistoryState(apiService: apiService)),
         ChangeNotifierProvider(create: (_) => ProfileState(apiService: apiService)),
         ChangeNotifierProvider(create: (_) => MapState(apiService: apiService)),
         ChangeNotifierProvider(create: (_) => CatalogState(apiService: apiService)),
         ChangeNotifierProvider(create: (_) => UsersState(apiService: apiService)),
         ChangeNotifierProvider(create: (_) => AnalysisState(apiService: apiService)),
         ChangeNotifierProvider.value(value: NotificationsState.instance),
         ChangeNotifierProvider(create: (_) => AppSettingsState()),
         ChangeNotifierProvider(create: (_) => ConnectivityState()),
       ],
      child: _ConnectivityOverlay(
        child: Consumer<AppSettingsState>(
          builder: (context, appSettings, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Lichen Dreams',
              theme: AppTheme.lightTheme(),
              darkTheme: AppTheme.darkTheme(),
              themeMode: appSettings.darkMode ? ThemeMode.dark : ThemeMode.light,
              initialRoute: initialRoute,
              onGenerateRoute: AppRouter.generateRoute,
              navigatorKey: LichenNavigation.navigatorKey,
              navigatorObservers: [LichenRouteObserver()],
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
      ),
    );
  }
}