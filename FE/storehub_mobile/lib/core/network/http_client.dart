import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HttpClient {
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
    final response =
        await http.get(Uri.parse(url), headers: await _getHeaders());
    return _parseResponse(response);
  }

  Future<dynamic> post(String url, {Map<String, dynamic>? body}) async {
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseResponse(response);
  }

  Future<dynamic> put(String url, {Map<String, dynamic>? body}) async {
    final response = await http.put(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseResponse(response);
  }

  Future<dynamic> delete(String url) async {
    final response =
        await http.delete(Uri.parse(url), headers: await _getHeaders());
    return _parseResponse(response);
  }

  dynamic _parseResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      String message = 'HTTP Error (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('message')) {
          message = body['message'];
        }
      } catch (_) {}
      throw Exception(message);
    }
  }
}
