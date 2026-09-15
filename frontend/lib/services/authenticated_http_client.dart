import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class AuthenticatedHttpClient extends http.BaseClient {
  final http.Client _innerClient;
  final ApiService _apiService;

  AuthenticatedHttpClient(this._innerClient, this._apiService);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _innerClient.send(request).then((response) async {
      if (response.statusCode == 401) {
        // Try to refresh the token and retry once
        final refreshed = await _apiService.refreshSession();
        if (refreshed) {
          // Retry the original request
          return await _innerClient.send(request);
        } else {
          // Refresh failed, treat as unauthorized
          await _apiService.handleUnauthorized();
        }
      }
      return response;
    });
  }
}