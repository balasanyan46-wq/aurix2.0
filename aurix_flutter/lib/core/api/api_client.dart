import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'token_store.dart';
import 'api_client_native.dart' if (dart.library.html) 'api_client_web.dart' as platform;

/// Central API client — single Dio instance for the entire app.
class ApiClient {
  ApiClient._();

  static const String _defaultBaseUrl = 'https://194.67.99.229';

  static final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static final Dio _dio = _createDio();

  static Dio get dio => _dio;

  /// Callback set by AuthStore to force sign-out when refresh fails.
  static VoidCallback? onSessionExpired;

  static Dio _createDio() {
    final d = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // JWT interceptor — attach access token
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = TokenStore.cachedToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (kDebugMode) {
          debugPrint('[API] ${options.method} ${options.path}');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          debugPrint(
              '[API] ERROR ${error.response?.statusCode} ${error.requestOptions.path}: '
              '${error.response?.data}');
        }
        handler.next(error);
      },
    ));

    // Auto-refresh interceptor — retry on 401
    d.interceptors.add(_RefreshInterceptor(d));

    // Accept self-signed certificate on native platforms
    // TODO: remove when real SSL cert is configured
    platform.configureDio(d);

    return d;
  }

  // ── Convenience methods ──────────────────────────────────

  static Future<Response> get(String path, {Map<String, dynamic>? query}) =>
      _dio.get(path, queryParameters: query);

  static Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  static Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  static Future<Response> delete(String path) => _dio.delete(path);

  /// Upload file as multipart.
  static Future<Response> uploadFile(
    String path,
    List<int> bytes,
    String fileName, {
    String fieldName = 'file',
    String? contentType,
  }) {
    final formData = FormData.fromMap({
      fieldName: MultipartFile.fromBytes(bytes, filename: fileName),
    });
    return _dio.post(path, data: formData);
  }
}

/// Interceptor that catches 401 responses, attempts a silent token refresh,
/// and retries the original request. If refresh fails — triggers sign-out.
class _RefreshInterceptor extends Interceptor {
  _RefreshInterceptor(this._dio);

  final Dio _dio;
  bool _isRefreshing = false;
  final List<_QueuedRequest> _queue = [];

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only handle 401 Unauthorized
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Don't try to refresh the refresh endpoint itself
    final path = err.requestOptions.path;
    if (path.contains('/auth/refresh') ||
        path.contains('/users/login') ||
        path.contains('/users/register')) {
      return handler.next(err);
    }

    // If already refreshing, queue this request
    if (_isRefreshing) {
      _queue.add(_QueuedRequest(err.requestOptions, handler));
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await TokenStore.readRefresh();
      if (refreshToken == null) {
        _failAll(err);
        _notifySessionExpired();
        return handler.next(err);
      }

      // Call refresh endpoint directly (bypass interceptors to avoid loop)
      final refreshDio = Dio(BaseOptions(
        baseUrl: ApiClient.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ));
      platform.configureDio(refreshDio);

      final res = await refreshDio.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });

      final body = res.data as Map<String, dynamic>;
      final newAccess = body['token'] as String;
      final newRefresh = body['refreshToken'] as String?;

      await TokenStore.save(newAccess);
      if (newRefresh != null) {
        await TokenStore.saveRefresh(newRefresh);
      }

      // Retry the original request with new token
      err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _dio.fetch(err.requestOptions);

      // Process queued requests
      _processQueue(newAccess);

      _isRefreshing = false;
      return handler.resolve(retryResponse);
    } catch (e) {
      debugPrint('[RefreshInterceptor] refresh failed: $e');
      _isRefreshing = false;
      _failAll(err);
      await TokenStore.clear();
      _notifySessionExpired();
      return handler.next(err);
    }
  }

  void _processQueue(String newToken) {
    for (final queued in _queue) {
      queued.options.headers['Authorization'] = 'Bearer $newToken';
      _dio.fetch(queued.options).then(
            (r) => queued.handler.resolve(r),
            onError: (e) => queued.handler.reject(e as DioException),
          );
    }
    _queue.clear();
  }

  void _failAll(DioException err) {
    for (final queued in _queue) {
      queued.handler.reject(err);
    }
    _queue.clear();
    _isRefreshing = false;
  }

  void _notifySessionExpired() {
    ApiClient.onSessionExpired?.call();
  }
}

class _QueuedRequest {
  final RequestOptions options;
  final ErrorInterceptorHandler handler;
  _QueuedRequest(this.options, this.handler);
}
