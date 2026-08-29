import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/widgets/app_theme.dart';
import 'package:frontend/widgets/google_sign_in_button.dart';

void main() {
  Widget buildApp({bool loading = false, VoidCallback? onPressed}) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryGreen),
      ),
      home: Scaffold(
        body: GoogleSignInButton(
          loading: loading,
          onPressed: onPressed,
        ),
      ),
    );
  }

  testWidgets('muestra el label y el icono de Google', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('muestra loading y no dispara onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      buildApp(
        loading: true,
        onPressed: () => taps++,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('dispara onPressed al pulsar', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      buildApp(onPressed: () => taps++),
    );

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    expect(taps, 1);
  });
}