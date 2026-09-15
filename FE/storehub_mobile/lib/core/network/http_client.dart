import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';

class HttpClient {
  static final HttpClient _instance = HttpClient._internal();
  late final Dio dio;

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
      ),
    );
  }

  static HttpClient get instance => _instance;

  // Wrapper cho phương thức GET
  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters, Options? options}) async {
    return await dio.get(path,
        queryParameters: queryParameters, options: options);
  }

  // Wrapper cho phương thức POST
  Future<Response> post(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Options? options}) async {
    return await dio.post(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  // Wrapper cho phương thức PUT
  Future<Response> put(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Options? options}) async {
    return await dio.put(path,
        data: data, queryParameters: queryParameters, options: options);
  }

  // Wrapper cho phương thức DELETE
  Future<Response> delete(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Options? options}) async {
    return await dio.delete(path,
        data: data, queryParameters: queryParameters, options: options);
  }
}
