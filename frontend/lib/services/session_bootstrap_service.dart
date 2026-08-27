import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/profile_state.dart';
import '../state/dashboard_state.dart';
import '../state/history_state.dart';
import '../state/articles_state.dart';
import '../state/map_state.dart';
import '../state/notifications_state.dart';

class SessionBootstrapService {
  SessionBootstrapService._();

  static const Duration _criticalTimeout = Duration(seconds: 4);
  static const Duration _backgroundTimeout = Duration(seconds: 6);
  static const Duration _mapTimeout = Duration(seconds: 10);

  static Future<void> initializeAuthenticatedSession(
    BuildContext context, {
    void Function(String label, int durationMs)? onTiming,
    void Function(String error)? onError,
  }) async {
    final sw = Stopwatch()..start();

    Future<void> timed(String label, Future<void> Function() fn, Duration timeout) async {
      final t0 = DateTime.now();
      try {
        await fn().timeout(timeout);
        final dt = DateTime.now().difference(t0).inMilliseconds;
        onTiming?.call(label, dt);
      } catch (e) {
        final dt = DateTime.now().difference(t0).inMilliseconds;
        onTiming?.call('$label: ERROR after ${dt}ms', dt);
        onError?.call('$label: $e');
      }
    }

    bool criticalSuccess = true;
    String? criticalError;

    try {
      await Future.wait([
        timed('ProfileState', () => context.read<ProfileState>().loadProfile(), _criticalTimeout),
        timed('DashboardState', () => context.read<DashboardState>().loadStats(), _criticalTimeout),
      ]);
    } catch (e) {
      criticalSuccess = false;
      criticalError = e.toString();
    }

    if (!criticalSuccess) {
      onError?.call('critical failed: $criticalError');
      return;
    }

    final historyState = context.read<HistoryState>();
    final articlesState = context.read<ArticlesState>();
    final mapState = context.read<MapState>();

    await Future.wait([
      timed('HistoryState', () => historyState.loadHistory(), _backgroundTimeout),
      timed('ArticlesState', () => articlesState.loadArticles(), _backgroundTimeout),
      timed('MapState', () => mapState.loadPoints(), _mapTimeout),
      timed('NotificationsState', () => NotificationsState.instance.loadNotifications(force: true), _backgroundTimeout),
    ]);

    sw.stop();
    onTiming?.call('total', sw.elapsedMilliseconds);
  }
}
