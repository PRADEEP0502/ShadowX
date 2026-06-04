import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';
import '../models/conversation.dart';

class ConversationService {
  const ConversationService._();

  static Future<List<Conversation>> fetchConversations(String username) async {
    if (username.trim().isEmpty) return const [];

    final uri = Uri.parse('${ApiConstants.baseUrl}/conversations/$username');
    final res = await http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );

    if (res.statusCode >= 400) return const [];

    final body = jsonDecode(res.body);
    if (body is! List) return const [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(Conversation.fromJson)
        .toList(growable: false);
  }
}
