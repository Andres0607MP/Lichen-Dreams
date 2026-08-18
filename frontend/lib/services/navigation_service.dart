import 'package:flutter/material.dart';

import '../routes/route_names.dart';

class LichenNavigation {
  LichenNavigation._();

  static final LichenNavigation instance = LichenNavigation._();

  final ValueNotifier<int> selectedIndex = ValueNotifier<int>(0);

  void navigateTo(int index) {
    selectedIndex.value = index;
  }

  void reset() {
    selectedIndex.value = 0;
  }

  void sync(int index) {
    if (selectedIndex.value != index) {
      selectedIndex.value = index;
    }
  }

  void goToDashboard(BuildContext context) {
    selectedIndex.value = 0;
    Navigator.pushNamed(context, AppRoutes.dashboard);
  }

  void goToAnalysis(BuildContext context) {
    selectedIndex.value = 1;
    Navigator.pushNamed(context, AppRoutes.analisis);
  }

  void goToMap(BuildContext context) {
    selectedIndex.value = 2;
    Navigator.pushNamed(context, AppRoutes.mapa);
  }

  void goToHistory(BuildContext context) {
    selectedIndex.value = 3;
    Navigator.pushNamed(context, AppRoutes.historial);
  }

  void goToProfile(BuildContext context) {
    selectedIndex.value = 4;
    Navigator.pushNamed(context, AppRoutes.perfil);
  }
}