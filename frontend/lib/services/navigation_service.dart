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

  static const Set<String> tabRoutes = {
    AppRoutes.dashboard,
    AppRoutes.analisis,
    AppRoutes.mapa,
    AppRoutes.historial,
    AppRoutes.perfil,
  };

  static const Map<int, String> _indexToRoute = {
    0: AppRoutes.dashboard,
    1: AppRoutes.analisis,
    2: AppRoutes.mapa,
    3: AppRoutes.historial,
    4: AppRoutes.perfil,
  };

  void navigateTo(int index) {
    selectedIndex.value = index;
  }

  void navigateToTab(BuildContext context, int index) {
    if (index < 0 || index > 4) return;
    selectedIndex.value = index;
    final routeName = _indexToRoute[index];
    if (routeName == null) return;
    Navigator.pushReplacementNamed(context, routeName);
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
    if (!tabRoutes.contains(routeName)) return;
    final index = _routeToIndex[routeName];
    if (index != null) {
      sync(index);
    }
  }

  void goToTabReplacement(BuildContext context, int index) {
    navigateToTab(context, index);
  }

  bool isTabRoute(String? routeName) {
    if (routeName == null) return false;
    return tabRoutes.contains(routeName);
  }

  Future<bool> handleBackNavigation(BuildContext context) async {
    final currentIndex = selectedIndex.value;
    if (!isTabRoute(ModalRoute.of(context)?.settings.name)) {
      Navigator.pop(context);
      return false;
    }
    if (currentIndex != 0) {
      navigateToTab(context, 0);
      return false;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir de Lichen Dreams?'),
        content: const Text('¿Estás seguro que deseas cerrar la aplicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
    return false;
  }

  void goToDashboard(BuildContext context) {
    navigateToTab(context, 0);
  }

  void goToAnalysis(BuildContext context) {
    navigateToTab(context, 1);
  }

  void goToMap(BuildContext context) {
    navigateToTab(context, 2);
  }

  void goToHistory(BuildContext context) {
    navigateToTab(context, 3);
  }

  void goToProfile(BuildContext context) {
    navigateToTab(context, 4);
  }
}

class LichenRouteObserver extends NavigatorObserver {
  void _syncIfTabRoute(Route<dynamic>? route) {
    final routeName = route?.settings.name;
    if (routeName == null) return;
    if (!LichenNavigation.tabRoutes.contains(routeName)) return;
    LichenNavigation.instance.syncFromRoute(routeName);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _syncIfTabRoute(previousRoute);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _syncIfTabRoute(route);
  }
}