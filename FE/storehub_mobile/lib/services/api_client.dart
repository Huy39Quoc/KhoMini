import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String url) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse(url), headers: headers);
    return _handleResponse(response);
  }

  Future<dynamic> post(String url, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String url, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Server error (${response.statusCode})';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('message')) {
          errorMessage = errorBody['message'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }
}
