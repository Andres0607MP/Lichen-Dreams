import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:frontend/state/dashboard_state.dart';
import 'package:frontend/state/articles_state.dart';
import 'package:frontend/state/catalog_state.dart';
import 'package:frontend/state/notifications_state.dart';
import 'package:frontend/state/analysis_state.dart';
import 'package:frontend/state/app_settings_state.dart';

Widget _dashboardApp() {
  final apiService = ApiService();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: AuthState(apiService: apiService)),
      Provider.value(value: apiService),
      ChangeNotifierProvider(create: (_) => DashboardState(apiService: apiService)),
      ChangeNotifierProvider(create: (_) => ArticlesState(apiService: apiService)),
      ChangeNotifierProvider(create: (_) => CatalogState(apiService: apiService)),
      ChangeNotifierProvider.value(value: NotificationsState.instance),
      ChangeNotifierProvider(create: (_) => AnalysisState(apiService: apiService)),
      ChangeNotifierProvider(create: (_) => AppSettingsState()),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const DashboardScreen(),
    ),
  );
}

void main() {
  testWidgets('dashboard layouts cleanly with semantics enabled and bottom nav animating', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_dashboardApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 600));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.drag(find.byType(PageView).first, const Offset(-300, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    semantics.dispose();
  });
}