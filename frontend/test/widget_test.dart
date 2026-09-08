// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/ia_monitoring_service.dart';
import 'package:frontend/state/ia_monitoring_state.dart';

void main() {
  testWidgets('renders the login screen', (WidgetTester tester) async {
    final apiService = ApiService();
    final iaMonitoringService = IaMonitoringService(apiService);
    final iaMonitoringState = IaMonitoringState(iaMonitoringService);
    await tester.pumpWidget(LichenDreamsApp(
      authState: AuthState(apiService: apiService),
      apiService: apiService,
      iaMonitoringService: iaMonitoringService,
      iaMonitoringState: iaMonitoringState,
    ));

    expect(find.text('Lichen Dreams'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear una cuenta'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
  });
}
