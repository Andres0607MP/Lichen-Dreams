import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../routes/route_names.dart';

class LichenNavigation {
  LichenNavigation._();

  static final LichenNavigation instance = LichenNavigation._();

  final ValueNotifier<int> selectedIndex = ValueNotifier<int>(0);

  static const Map<String, int> _routeToIndex = {
    AppRoutes.dashboard: 0,
    AppRoutes.analisis: 1,
    AppRoutes.mapa: 2,
    AppRoutes.historial: 3,
    AppRoutes.perfil: 4,
  };

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

  void syncFromRoute(String? routeName) {
    if (routeName == null) return;
    final index = _routeToIndex[routeName];
    if (index != null) {
      sync(index);
    }
  }

  void goToTabReplacement(BuildContext context, int index) {
    final routeName = _indexToRoute[index];
    if (routeName == null) return;
    selectedIndex.value = index;
    Navigator.pushReplacementNamed(context, routeName);
  }

  static const Map<int, String> _indexToRoute = {
    0: AppRoutes.dashboard,
    1: AppRoutes.analisis,
    2: AppRoutes.mapa,
    3: AppRoutes.historial,
    4: AppRoutes.perfil,
  };

  Future<bool> handleBackNavigation(BuildContext context) async {
    debugPrint('HANDLE BACK EXECUTED');
    final currentIndex = selectedIndex.value;
    debugPrint('HANDLE BACK - currentIndex: $currentIndex');
    if (currentIndex != 0) {
      debugPrint('RETURNING TO HOME');
      goToTabReplacement(context, 0);
      return false;
    }
    debugPrint('SHOW EXIT DIALOG');
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir de Lichen Dreams?'),
        content: const Text('¿Estás seguro que deseas cerrar la aplicación?'),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('EXIT DIALOG - Cancelar');
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              debugPrint('EXIT CONFIRMED');
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    debugPrint('SHOW EXIT DIALOG result: $shouldExit');
    if (shouldExit == true) {
      debugPrint('APP EXIT REQUESTED');
      SystemNavigator.pop();
    }
    return false;
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

class LichenRouteObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    LichenNavigation.instance.syncFromRoute(previousRoute?.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    LichenNavigation.instance.syncFromRoute(route.settings.name);
  }
}