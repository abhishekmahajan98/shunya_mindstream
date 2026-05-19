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
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SessionService.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
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
    
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          // Retry original request with new token
          final newToken = await SessionService.getAccessToken();
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          final response = await _dio.fetch(opts);
          handler.resolve(response);
          return;
        }
      } catch (_) {
        // Refresh failed — clear session
        await SessionService.clearSession();
      } finally {
        _isRefreshing = false;
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
