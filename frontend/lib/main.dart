import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'routes/route_names.dart';

void main() {
  runApp(const LichenDreamsApp());
}

class LichenDreamsApp extends StatelessWidget {
  const LichenDreamsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF2F7D32);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lichen Dreams',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F3),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Color(0xFF1E1E1E),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF18301F),
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF18301F),
          ),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF5A665D)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD9E1D6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD9E1D6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: seedColor, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
        ),
      ),
      initialRoute: AppRoutes.login,
      routes: AppRouter.routes,
    );
  }
}
