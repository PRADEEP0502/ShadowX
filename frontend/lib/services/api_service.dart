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

  static Future<List<dynamic>> searchUsers({required String username}) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/users/search',
    ).replace(queryParameters: {'username': username});

    final response = await http.get(uri);
    if (response.statusCode >= 400) {
      return [];
    }

    final body = jsonDecode(response.body);
    return body is List ? body : [];
  }

  // ─── OTP ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> sendRegisterOtp({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/otp/send-register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception((body['detail'] ?? body['message'] ?? 'Failed to send OTP').toString());
    }
    return body is Map<String, dynamic> ? body : {};
  }

  static Future<Map<String, dynamic>> verifyRegisterOtp({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/otp/verify-register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception((body['detail'] ?? body['message'] ?? 'OTP verification failed').toString());
    }
    return body is Map<String, dynamic> ? body : {};
  }

  static Future<Map<String, dynamic>> sendForgotOtp({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/otp/send-forgot'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception((body['detail'] ?? body['message'] ?? 'Failed to send OTP').toString());
    }
    return body is Map<String, dynamic> ? body : {};
  }

  static Future<Map<String, dynamic>> verifyForgotOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/otp/verify-forgot'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp, 'new_password': newPassword}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception((body['detail'] ?? body['message'] ?? 'Password reset failed').toString());
    }
    return body is Map<String, dynamic> ? body : {};
  }

  // ─── PROFILE ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchUserProfile(String username) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/users/profile/$username'),
      headers: const {'Accept': 'application/json'},
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception((body['detail'] ?? 'Failed to fetch profile').toString());
    }
    return body is Map<String, dynamic> ? body : {};
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    required String currentUsername,
    required String newUsername,
    required String email,
    required String? avatar,
    required String status,
    required bool notificationPush,
    required bool notificationSound,
    required bool notificationVibrate,
    required bool notificationPreview,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/users/profile/update'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'current_username': currentUsername,
        'new_username': newUsername,
        'email': email,
        'avatar': avatar,
        'status': status,
        'notification_push': notificationPush,
        'notification_sound': notificationSound,
        'notification_vibrate': notificationVibrate,
        'notification_preview': notificationPreview,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception((body['detail'] ?? 'Failed to update profile').toString());
    }
    return body is Map<String, dynamic> ? body : {};
  }

  static Future<Map<String, dynamic>> changePassword({
    required String username,
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/users/profile/change-password'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception((body['detail'] ?? 'Failed to change password').toString());
    }
    return body is Map<String, dynamic> ? body : {};
  }
}

