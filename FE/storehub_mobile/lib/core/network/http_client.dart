import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';

class HttpClient {
  static final HttpClient _instance = HttpClient._internal();
  late final Dio dio;

  late final Dio _plainDio;

  bool _isRefreshing = false;
  final List<void Function(String?)> _pendingCallbacks = [];

  factory HttpClient() {
    return _instance;
  }

  HttpClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _plainDio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final isRefreshCall =
              error.requestOptions.path == ApiEndpoints.refreshToken;

          if (!isUnauthorized || isRefreshCall) {
            return handler.next(error);
          }

          final newToken = await _refreshAccessToken();
          if (newToken == null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('jwt_token');
            await prefs.remove('refresh_token');
            return handler.next(error);
          }

          try {
            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newToken';
            final response = await dio.fetch(retryOptions);
            return handler.resolve(response);
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        },
      ),
    );
  }

  Future<String?> _refreshAccessToken() async {
    if (_isRefreshing) {
      final completer = Completer<String?>();
      _pendingCallbacks.add((token) => completer.complete(token));
      return completer.future;
    }

    _isRefreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        _notifyPending(null);
        return null;
      }

      final response = await _plainDio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );
      final body = response.data;
      final data = body is Map && body['data'] is Map ? body['data'] : body;
      final newAccessToken = data['accessToken']?.toString();
      final newRefreshToken = data['refreshToken']?.toString();

      if (newAccessToken == null || newAccessToken.isEmpty) {
        _notifyPending(null);
        return null;
      }

      await prefs.setString('jwt_token', newAccessToken);
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await prefs.setString('refresh_token', newRefreshToken);
      }

      _notifyPending(newAccessToken);
      return newAccessToken;
    } on DioException {
      _notifyPending(null);
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  void _notifyPending(String? token) {
    for (final cb in _pendingCallbacks) {
      cb(token);
    }
    _pendingCallbacks.clear();
  }

  static HttpClient get instance => _instance;

  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters, Options? options}) async {
    return await dio.get(path,
        queryParameters: queryParameters, options: options);
  }

  Future<Response> post(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Options? options}) async {
    return await dio.post(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> put(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Options? options}) async {
    return await dio.put(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> delete(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Options? options}) async {
    return await dio.delete(path,
        data: data, queryParameters: queryParameters, options: options);
  }
}
