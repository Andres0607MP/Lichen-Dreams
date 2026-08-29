import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/routes/route_names.dart';
import 'package:frontend/screens/recovery_code_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({String? code}) {
    return MaterialApp(
      routes: {
        AppRoutes.login: (_) => const Scaffold(
              body: Text('LoginScreen'),
            ),
      },
      home: RecoveryCodeScreen(code: code ?? 'LCHN-X7K4-P92M'),
    );
  }

  testWidgets('muestra el código de recuperación y las advertencias',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('LCHN-X7K4-P92M'), findsOneWidget);
    expect(find.text('¡Tu cuenta está lista!'), findsOneWidget);
    expect(
      find.textContaining('única forma de recuperar tu cuenta'),
      findsOneWidget,
    );
    expect(find.textContaining('Nunca lo compartas con nadie'), findsOneWidget);
    expect(find.text('Toca para copiar'), findsOneWidget);
  });

  testWidgets('navega al inicio de sesión al confirmar que guardó el código',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.text('Guardé mi código. Ir al inicio de sesión'));
    await tester.pumpAndSettle();

    expect(find.text('LoginScreen'), findsOneWidget);
  });
}