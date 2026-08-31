import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/screens/settings/licenses_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:frontend/state/dashboard_state.dart';
import 'package:frontend/state/articles_state.dart';
import 'package:frontend/state/history_state.dart';
import 'package:frontend/state/profile_state.dart';
import 'package:frontend/state/map_state.dart';
import 'package:frontend/state/users_state.dart';
import 'package:frontend/state/notifications_state.dart';
import 'package:frontend/state/analysis_state.dart';
import 'package:frontend/state/app_settings_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LicenciasScreen se renderiza sin tamaño infinito',
      (tester) async {
    final apiService = ApiService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthState(apiService: apiService)),
          Provider.value(value: apiService),
          ChangeNotifierProvider(create: (_) => DashboardState(apiService: apiService)),
          ChangeNotifierProvider(create: (_) => ArticlesState(apiService: apiService)),
          ChangeNotifierProvider(create: (_) => HistoryState(apiService: apiService)),
          ChangeNotifierProvider(create: (_) => ProfileState(apiService: apiService)),
          ChangeNotifierProvider(create: (_) => MapState(apiService: apiService)),
          ChangeNotifierProvider(create: (_) => UsersState(apiService: apiService)),
          ChangeNotifierProvider(create: (_) => AnalysisState(apiService: apiService)),
          ChangeNotifierProvider.value(value: NotificationsState.instance),
          ChangeNotifierProvider(create: (_) => AppSettingsState()),
        ],
        child: const MaterialApp(
          home: LicensesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // No debe haber excepciones de layout (Infinity/NaN/needsLayout).
    expect(tester.takeException(), isNull);
    expect(find.text('Licencias'), findsWidgets);
  });
}