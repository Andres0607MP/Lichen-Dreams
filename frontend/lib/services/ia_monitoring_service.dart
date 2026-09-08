import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/ia_diagnostic.dart';
import '../models/ia_event.dart';
import '../models/ia_health.dart';
import '../models/ia_metrics.dart';
import 'api_service.dart';

typedef IaEventCallback = void Function(IaEvent event);
typedef IaErrorCallback = void Function(String error);

class IaMonitoringService {
  final ApiService _apiService;
  final http.Client _client;

  IaMonitoringService(this._apiService, {http.Client? client})
      : _client = client ?? http.Client();

  /// GET /ia/health
  Future<IaHealth> getHealth() async {
    final response = await _apiService.getProtectedJson('/ia/health');
    return IaHealth.fromJson(response);
  }

  /// GET /ia/metrics
  Future<IaMetrics> getMetrics() async {
    final response = await _apiService.getProtectedJson('/ia/metrics');
    return IaMetrics.fromJson(response);
  }

  /// GET /ia/diagnostics — diagnóstico determinístico de la IA.
  Future<IaDiagnostic> getDiagnostics() async {
    final response = await _apiService.getProtectedJson('/ia/diagnostics');
    return IaDiagnostic.fromJson(response);
  }

  /// GET /ia/events (SSE en tiempo real)
  ///
  /// El backend envía eventos SSE continuos. Cada conexión recibe su propia
  /// cola y un *replay* de eventos históricos. Sin `limit`, el stream
  /// permanece abierto indefinidamente hasta que el cliente se desconecta.
  Stream<IaEvent> connectEvents({
    IaErrorCallback? onError,
    VoidCallback? onComplete,
  }) {
    final controller =
        StreamController<IaEvent>.broadcast(onCancel: () => disconnect());

    _activeControllers.add(controller);

    _beginStreaming(
      controller: controller,
      uri: AppConfig.buildUri('/ia/events'),
      onError: onError,
      onComplete: onComplete,
    );

    return controller.stream;
  }

  final List<StreamController<IaEvent>> _activeControllers = [];
  StreamSubscription? _activeSubscription;

  /// Buffer persistente entre chunks TCP. Los eventos SSE pueden fragmentarse
  /// a través de múltiples chunks. Acumulamos hasta encontrar el terminador
  /// `\n\n` que delimita cada evento.
  final StringBuffer _sseBuffer = StringBuffer();

  void _beginStreaming({
    required StreamController<IaEvent> controller,
    required Uri uri,
    IaErrorCallback? onError,
    VoidCallback? onComplete,
  }) async {
    try {
      final token = await _apiService.getToken();
      final headers = <String, String>{
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final request = http.Request('GET', uri)..headers.addAll(headers);

      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        final msg = 'Error ${response.statusCode}: $errorBody';
        if (!controller.isClosed && !_disposed) controller.addError(msg);
        onError?.call(msg);
        _finish(controller, onComplete);
        return;
      }

      _activeSubscription = response.stream.listen(
        (chunk) {
          _parseSseChunk(
            chunk,
            (eventType, dataJson) {
              final event = IaEvent.fromSse(eventType, dataJson);
              if (!controller.isClosed && !_disposed) {
                controller.add(event);
              }
            },
          );
        },
        onDone: () {
          _finish(controller, onComplete);
        },
        onError: (e) {
          if (!controller.isClosed && !_disposed) controller.addError(e.toString());
          onError?.call(e.toString());
          _finish(controller, onComplete);
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!controller.isClosed && !_disposed) controller.addError(e.toString());
      onError?.call(e.toString());
      _finish(controller, onComplete);
    }
  }

  void _finish(
    StreamController<IaEvent> controller,
    VoidCallback? onComplete,
  ) {
    _activeControllers.remove(controller);
    _activeSubscription = null;
    _sseBuffer.clear();
    if (!controller.isClosed) controller.close();
    onComplete?.call();
  }

  void _parseSseChunk(
    List<int> chunk,
    void Function(String eventType, String dataJson) onData,
  ) {
    _sseBuffer.write(utf8.decode(chunk, allowMalformed: true));
    final text = _sseBuffer.toString();
    _sseBuffer.clear();

    final eventSeparator = '\n\n';
    final parts = text.split(eventSeparator);

    // The last part may be incomplete (no trailing \n\n), keep it for next chunk
    final incomplete = parts.removeLast();
    if (incomplete.isNotEmpty) {
      _sseBuffer.write(incomplete);
    }

    for (final part in parts) {
      _parseCompleteSseEvent(part, onData);
    }
  }

  void _parseCompleteSseEvent(
    String part,
    void Function(String eventType, String dataJson) onData,
  ) {
    String eventType = 'message';
    final dataLines = <String>[];

    for (final line in LineSplitter().convert(part)) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }

    final dataJson = dataLines.join('\n');
    if (dataJson.isNotEmpty || eventType != 'message') {
      onData(eventType, dataJson);
    }
  }

  bool _disposed = false;

  void disconnect() {
    _activeSubscription?.cancel();
    _activeSubscription = null;
    _sseBuffer.clear();
    for (final c in List.of(_activeControllers)) {
      if (!c.isClosed) c.close();
    }
    _activeControllers.clear();
  }

  void dispose() {
    _disposed = true;
    disconnect();
  }
}
