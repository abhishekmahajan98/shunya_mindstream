import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/session_service.dart';

/// Base URL — override via FLUTTER_API_URL env var at build time,
/// otherwise defaults to local backend.
const String kApiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://shunyamindstream-production.up.railway.app',
);

Dio createDio() {
  final dio = Dio(BaseOptions(
    baseUrl: kApiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(_AuthInterceptor(dio));
  return dio;
}

/// Singleton Dio instance used throughout the app.
final dio = createDio();

// ── Auth interceptor ──────────────────────────────────────────
class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  Future<void>? _refreshFuture;

  _AuthInterceptor(this._dio);

  Map<String, dynamic> _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return const {};
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(payloadString) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  bool _isTokenCloseToExpiry(String token) {
    try {
      final payload = _decodeJwt(token);
      final exp = payload['exp'] as int?;
      if (exp == null) return false;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      // Refresh if token expires in less than 5 minutes
      return expiryDate.difference(DateTime.now()).inSeconds < 300;
    } catch (_) {
      return true; // Treat as close to expiry if parsing fails
    }
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    String? token = await SessionService.getAccessToken();
    if (token != null) {
      if (_isTokenCloseToExpiry(token)) {
        // Start a shared proactive refresh if none is running
        if (_refreshFuture == null) {
          _refreshFuture = _tryRefresh().then((refreshed) async {
            if (!refreshed) {
              await SessionService.clearSession();
              SessionService.notifySessionExpired();
            }
          }).catchError((_) async {
            await SessionService.clearSession();
            SessionService.notifySessionExpired();
          }).whenComplete(() {
            _refreshFuture = null;
          });
        }
        await _refreshFuture;
        token = await SessionService.getAccessToken();
      }
      
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    debugPrint('🔴 [API ERROR] ${err.requestOptions.method} ${err.requestOptions.uri}');
    debugPrint('🔴 [STATUS] ${err.response?.statusCode}');
    debugPrint('🔴 [RESPONSE] ${err.response?.data}');
    
    final opts = err.requestOptions;

    // Retry once if 401 occurs and has not already been retried
    if (err.response?.statusCode == 401 && opts.extra['isRetry'] != true) {
      // Start a shared refresh if none is running
      if (_refreshFuture == null) {
        _refreshFuture = _tryRefresh().then((refreshed) async {
          if (!refreshed) {
            await SessionService.clearSession();
            SessionService.notifySessionExpired();
          }
        }).catchError((_) async {
          await SessionService.clearSession();
          SessionService.notifySessionExpired();
        }).whenComplete(() {
          _refreshFuture = null;
        });
      }

      try {
        await _refreshFuture;
        final newToken = await SessionService.getAccessToken();
        if (newToken != null) {
          opts.headers['Authorization'] = 'Bearer $newToken';
          opts.extra['isRetry'] = true;
          final response = await _dio.fetch(opts);
          handler.resolve(response);
          return;
        }
      } catch (_) {
        // Fall through to error handler
      }
    }
    handler.next(err);
  }

  Future<bool> _tryRefresh() async {
    final refresh = await SessionService.getRefreshToken();
    if (refresh == null) return false;
    try {
      final resp = await Dio().post(
        '$kApiBaseUrl/api/auth/refresh',
        data: {'refresh_token': refresh},
      );
      await SessionService.updateTokens(
        accessToken: resp.data['access_token'] as String,
        refreshToken: resp.data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Helper: extract error detail from Dio response.
String extractError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) return data['detail']?.toString() ?? e.message ?? 'Request failed';
    return e.message ?? 'Request failed';
  }
  return e.toString();
}
