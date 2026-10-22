import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import 'token_store.dart';

/// Kết quả một lời gọi API thành công (HTTP 2xx).
class ApiResponse {
  final int? statusCode;

  /// Nội dung đã giải mã JSON (Map/List), hoặc chuỗi thô khi gọi với `plainText: true`.
  final dynamic data;

  const ApiResponse({this.statusCode, this.data});
}

enum ApiExceptionType { connectionTimeout, connectionError, badResponse }

/// Lỗi khi gọi API: lỗi mạng/timeout hoặc máy chủ trả mã khác 2xx.
/// Với lỗi từ máy chủ, [response] luôn có `data` là Map để đọc `data['message']`.
class ApiException implements Exception {
  final String? message;
  final ApiResponse? response;
  final ApiExceptionType type;

  const ApiException({
    this.message,
    this.response,
    required this.type,
  });

  @override
  String toString() => 'ApiException: ${message ?? type.name}';
}

/// Một tệp cần tải lên (multipart). [field] là tên trường form.
class ApiUploadFile {
  final String field;
  final String path;

  const ApiUploadFile(this.field, this.path);

  String get filename => path.split(RegExp(r'[/\\]')).last;
}

/// Nội dung multipart/form-data gồm các tệp, dùng làm `data` của [HttpClient.post].
class ApiMultipart {
  final List<ApiUploadFile> files;

  const ApiMultipart(this.files);
}

class HttpClient {
  static final HttpClient _instance = HttpClient._internal();

  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _uploadTimeout = Duration(seconds: 60);

  final http.Client _client = http.Client();

  bool _isRefreshing = false;
  final List<void Function(String?)> _pendingCallbacks = [];

  factory HttpClient() => _instance;

  HttpClient._internal();

  static HttpClient get instance => _instance;

  void updateBaseUrl(String newUrl) {
    ApiEndpoints.setBaseUrl(newUrl);
  }

  // ---------------------------------------------------------------------------
  // API công khai
  // ---------------------------------------------------------------------------

  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool plainText = false,
  }) =>
      _send('GET', path,
          queryParameters: queryParameters, plainText: plainText);

  Future<ApiResponse> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _send('POST', path, data: data, queryParameters: queryParameters);

  Future<ApiResponse> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _send('PUT', path, data: data, queryParameters: queryParameters);

  Future<ApiResponse> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _send('PATCH', path, data: data, queryParameters: queryParameters);

  Future<ApiResponse> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _send('DELETE', path, data: data, queryParameters: queryParameters);

  // ---------------------------------------------------------------------------
  // Gửi yêu cầu + tự làm mới token khi gặp 401
  // ---------------------------------------------------------------------------

  Future<ApiResponse> _send(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool plainText = false,
  }) async {
    final token = await TokenStore.instance.readAccessToken();
    var result = await _execute(
      method,
      path,
      data: data,
      queryParameters: queryParameters,
      plainText: plainText,
      accessToken: token,
    );

    final isRefreshCall = path == ApiEndpoints.refreshToken;
    if (result.statusCode == 401 && !isRefreshCall) {
      final newToken = await _refreshAccessToken();
      if (newToken != null) {
        result = await _execute(
          method,
          path,
          data: data,
          queryParameters: queryParameters,
          plainText: plainText,
          accessToken: newToken,
        );
      }
    }

    if (result.statusCode >= 200 && result.statusCode < 300) {
      return ApiResponse(statusCode: result.statusCode, data: result.data);
    }
    throw ApiException(
      type: ApiExceptionType.badResponse,
      message: 'Máy chủ trả về lỗi (HTTP ${result.statusCode})',
      response: ApiResponse(statusCode: result.statusCode, data: result.data),
    );
  }

  /// Thực hiện đúng một lần gọi. Không ném lỗi theo mã HTTP, chỉ ném khi lỗi mạng/timeout.
  Future<_RawResult> _execute(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool plainText = false,
    String? accessToken,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final timeout = data is ApiMultipart ? _uploadTimeout : _timeout;

    final http.BaseRequest request;
    if (data is ApiMultipart) {
      final multipart = http.MultipartRequest(method, uri);
      for (final file in data.files) {
        multipart.files.add(await http.MultipartFile.fromPath(
          file.field,
          file.path,
          filename: file.filename,
        ));
      }
      request = multipart;
    } else {
      final plain = http.Request(method, uri);
      if (data != null) {
        plain.headers['Content-Type'] = 'application/json; charset=utf-8';
        plain.body = data is String ? data : jsonEncode(data);
      }
      request = plain;
    }

    request.headers['Accept'] = plainText ? '*/*' : 'application/json';
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    try {
      final streamed = await _client.send(request).timeout(timeout);
      final response =
          await http.Response.fromStream(streamed).timeout(timeout);
      final text = utf8.decode(response.bodyBytes, allowMalformed: true);
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      return _RawResult(
        response.statusCode,
        ok ? _decodeBody(text, plainText) : _errorBody(text, response.statusCode),
      );
    } on TimeoutException {
      throw const ApiException(
        type: ApiExceptionType.connectionTimeout,
        message: 'Hết thời gian chờ phản hồi từ máy chủ. Vui lòng thử lại.',
      );
    } on SocketException {
      throw _connectionError();
    } on HandshakeException {
      throw _connectionError();
    } on http.ClientException {
      throw _connectionError();
    }
  }

  ApiException _connectionError() => const ApiException(
        type: ApiExceptionType.connectionError,
        message:
            'Không kết nối được tới máy chủ. Hãy kiểm tra mạng hoặc địa chỉ API.',
      );

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final String raw;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      raw = path;
    } else {
      raw = '${ApiEndpoints.baseUrl}${path.startsWith('/') ? '' : '/'}$path';
    }
    var uri = Uri.parse(raw);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final params = <String, dynamic>{...uri.queryParametersAll};
      queryParameters.forEach((key, value) {
        if (value == null) return;
        params[key] =
            value is Iterable ? value.map((e) => '$e').toList() : '$value';
      });
      uri = uri.replace(queryParameters: params);
    }
    return uri;
  }

  dynamic _decodeBody(String text, bool plainText) {
    if (plainText) return text;
    if (text.trim().isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  /// Thân phản hồi lỗi luôn là Map để nơi gọi đọc được `data['message']`.
  Map<String, dynamic> _errorBody(String text, int statusCode) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // không phải JSON (ví dụ trang lỗi HTML của máy chủ)
    }
    return {'message': 'Máy chủ phản hồi lỗi (HTTP $statusCode)'};
  }

  // ---------------------------------------------------------------------------
  // Làm mới token
  // ---------------------------------------------------------------------------

  Future<String?> _refreshAccessToken() async {
    if (_isRefreshing) {
      final completer = Completer<String?>();
      _pendingCallbacks.add((token) => completer.complete(token));
      return completer.future;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await TokenStore.instance.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await TokenStore.instance.clear();
        _notifyPending(null);
        return null;
      }

      final result = await _execute(
        'POST',
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      final status = result.statusCode;
      if (status < 200 || status >= 300) {
        if (status == 400 || status == 401 || status == 403) {
          await TokenStore.instance.clear();
        }
        _notifyPending(null);
        return null;
      }

      final body = result.data;
      final data = body is Map && body['data'] is Map ? body['data'] : body;
      final newAccessToken =
          data is Map ? data['accessToken']?.toString() : null;
      final newRefreshToken =
          data is Map ? data['refreshToken']?.toString() : null;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        _notifyPending(null);
        return null;
      }

      await TokenStore.instance.saveRefresh(newAccessToken, newRefreshToken);

      _notifyPending(newAccessToken);
      return newAccessToken;
    } catch (_) {
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
}

class _RawResult {
  final int statusCode;
  final dynamic data;

  const _RawResult(this.statusCode, this.data);
}
