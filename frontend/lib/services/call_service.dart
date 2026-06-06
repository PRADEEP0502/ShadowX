import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/call_log.dart';

class CallService {
  static Future<CallLog?> saveCall({
    required String caller,
    required String receiver,
    required String callType,
    required String status,
    int duration = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/calls'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'caller': caller,
          'receiver': receiver,
          'call_type': callType,
          'status': status,
          'duration': duration,
        }),
      );
      if (response.statusCode >= 400) return null;
      final body = jsonDecode(response.body);
      return CallLog.fromJson(body as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<List<CallLog>> fetchCalls(String username) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/calls/$username'),
      );
      if (response.statusCode >= 400) return [];
      final body = jsonDecode(response.body);
      if (body is List) {
        return body
            .map((e) => CallLog.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> deleteCall(String callId) async {
    try {
      await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/calls/$callId'),
      );
    } catch (_) {}
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
