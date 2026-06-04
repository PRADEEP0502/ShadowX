import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';

class ApiService {
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      // backend usually returns {"detail": "..."}
      return body is Map<String, dynamic>
          ? body
          : {'message': 'Register failed'};
    }

    return body is Map<String, dynamic> ? body : {'message': 'Register failed'};
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      return body is Map<String, dynamic> ? body : {'message': 'Login failed'};
    }

    return body is Map<String, dynamic> ? body : {'message': 'Login failed'};
  }
}
