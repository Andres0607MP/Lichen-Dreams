import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'routes/route_names.dart';
import 'widgets/app_theme.dart';

void main() {
  runApp(const LichenDreamsApp());
}

class LichenDreamsApp extends StatelessWidget {
  const LichenDreamsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lichen Dreams',
      theme: AppTheme.lightTheme(),
      initialRoute: AppRoutes.login,
      routes: AppRouter.routes,
    );
  }
}
