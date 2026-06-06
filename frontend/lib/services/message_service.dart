import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/constants/api_constants.dart';

class ChatMessage {
  final String sender;
  final String receiver;
  final String message;
  final DateTime createdAt;

  // WhatsApp status fields
  final String status; // "sent" | "delivered" | "seen"
  final DateTime? seenAt;

  // Mongo id
  final String? id;

  final bool isDeletedEveryone;
  final List<String> deletedFor;
  final String messageType;

  const ChatMessage({
    required this.sender,
    required this.receiver,
    required this.message,
    required this.createdAt,
    required this.status,
    required this.seenAt,
    required this.id,
    this.isDeletedEveryone = false,
    this.deletedFor = const [],
    this.messageType = 'text',
  });

  static DateTime _parseDateTime(dynamic raw) {
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is double) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    final statusRaw = json['status'];
    final seenAtRaw = json['seen_at'];

    final created = createdAtRaw == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : _parseDateTime(createdAtRaw);

    final seenAt = (seenAtRaw == null)
        ? null
        : (() {
            final parsed = _parseDateTime(seenAtRaw);
            return parsed.millisecondsSinceEpoch == 0 ? null : parsed;
          })();

    final isDeletedEveryone = json['is_deleted_everyone'] as bool? ?? false;
    final deletedForRaw = json['deleted_for'];
    final deletedFor = deletedForRaw is List
        ? List<String>.from(deletedForRaw.map((x) => x.toString()))
        : const <String>[];

    final messageType = (json['message_type'] ?? 'text').toString();

    return ChatMessage(
      id: (json['_id'] ?? json['id'])?.toString(),
      sender: (json['sender'] ?? '').toString(),
      receiver: (json['receiver'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: created,
      status: (statusRaw ?? 'sent').toString(),
      seenAt: seenAt,
      isDeletedEveryone: isDeletedEveryone,
      deletedFor: deletedFor,
      messageType: messageType,
    );
  }
}

class MessageService {
  const MessageService._();

  static Future<void> sendMessage({
    required String sender,
    required String receiver,
    required String message,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/messages');

    final response = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'sender': sender,
        'receiver': receiver,
        'message': message,
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('Failed to send message');
    }
  }

  static Future<List<ChatMessage>> fetchMessages({
    required String user1,
    required String user2,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/messages/$user1/$user2');

    final response = await http.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode >= 400) {
      return const [];
    }

    final body = jsonDecode(response.body);
    if (body is! List) return const [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList(growable: false);
  }

  static Future<void> markMessageSeen({required String messageId}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/messages/$messageId/seen');
    final response = await http.post(uri);
    if (response.statusCode >= 400) {
      throw Exception('Failed to mark message seen');
    }
  }

  static Future<void> deleteForMe({
    required String messageId,
    required String username,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/messages/$messageId/delete-for-me');
    final response = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'username': username}),
    );
    if (response.statusCode >= 400) {
      throw Exception('Failed to delete message for me');
    }
  }

  static Future<void> deleteForEveryone({
    required String messageId,
    required String username,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/messages/$messageId/delete-everyone');
    final response = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'username': username}),
    );
    if (response.statusCode >= 400) {
      throw Exception('Failed to delete message for everyone');
    }
  }

  static Future<void> deleteConversation({
    required String user1,
    required String user2,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/messages/conversation/$user1/$user2');
    final response = await http.delete(uri);
    if (response.statusCode >= 400) {
      throw Exception('Failed to delete conversation');
    }
  }

  static Future<String> uploadImage(Uint8List bytes, String filename) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/messages/upload');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 400) {
      try {
        final detail = jsonDecode(response.body)['detail'] ?? 'Failed to upload image';
        throw Exception(detail);
      } catch (_) {
        throw Exception('Failed to upload image');
      }
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['url'] as String;
  }
}
