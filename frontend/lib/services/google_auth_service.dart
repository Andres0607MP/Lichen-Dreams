import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';

class GoogleAuthService {
  bool _initialized = false;
  Future<void>? _initializing;

  /// Inicializa el manejador de Google Sign-In (API 7.x). Se llama una sola
  /// vez y se espera antes de usar [signInAndGetIdToken].
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (_initializing != null) {
      await _initializing;
      return;
    }
    final completer = Completer<void>();
    _initializing = completer.future;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleClientId.isEmpty
            ? null
            : AppConfig.googleClientId,
      );
    } catch (e, stack) {
      completer.completeError(e, stack);
      rethrow;
    }
    _initialized = true;
    completer.complete();
    _initializing = null;
  }

  /// Diagnóstico temporal [GOOGLE-DEBUG]: extrae SOLO las claims de auditoría
  /// (aud/iss/sub/exp) del ID token para compararlas con el GOOGLE_CLIENT_ID
  /// del backend. NUNCA se imprime el token completo ni el payload completo.
  static String? _summarizeClaims(String? token) {
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      final aud = decoded['aud'];
      final iss = decoded['iss'];
      final sub = decoded['sub'];
      final exp = decoded['exp'];
      return 'aud=$aud iss=$iss sub=$sub exp=$exp';
    } catch (_) {
      return null;
    }
  }

  /// Abre Google Sign-In, permite elegir cuenta y devuelve el ID token.
  ///
  /// Devuelve `null` si el usuario cancela el flujo (no es un error fatal).
  /// El `serverClientId` pasado es el Client ID "Web" del proyecto en Google
  /// Cloud; se convierte en la audiencia del ID token y el backend lo valida
  /// como `GOOGLE_CLIENT_ID`.
  Future<String?> signInAndGetIdToken() async {
    await _ensureInitialized();

    try {
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;

      final summary = _summarizeClaims(idToken);
      debugPrint('[GOOGLE-DEBUG] claims del ID token (solo auditoría): $summary '
          '| GOOGLE_CLIENT_ID (frontend): ${AppConfig.googleClientId}');

      return idToken;
    } on GoogleSignInException catch (e) {
      debugPrint('[GOOGLE-DEBUG] GoogleSignInException: code=${e.code} '
          'description=${e.description} details=${e.details}');
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }
}