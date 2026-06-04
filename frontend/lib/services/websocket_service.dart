import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/api_constants.dart';

class WSChatEvent {
  final String sender;
  final String receiver;
  final String message;
  final DateTime createdAt;

  const WSChatEvent({
    required this.sender,
    required this.receiver,
    required this.message,
    required this.createdAt,
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

  factory WSChatEvent.fromJson(Map<String, dynamic> json) {
    // Backend sends `created_at`.
    // Some older payloads may send `createdAt`.
    final createdAt = _parseDateTime(
      json['created_at'] ?? json['createdAt'],
    );

    return WSChatEvent(
      sender: (json['sender'] ?? '').toString(),
      receiver: (json['receiver'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: createdAt,
    );
  }
}

class WebSocketService {
  final String username;
  WebSocketChannel? _channel;

  StreamController<WSChatEvent> _events =
      StreamController<WSChatEvent>.broadcast();

  Stream<WSChatEvent> get events => _events.stream;

  WebSocketService({required this.username});

  Future<void> connect() async {
    final wsUrl = '${ApiConstants.baseWsUrl}/ws/$username';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.stream.listen(
      (dynamic raw) {
        try {
          final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
          _events.add(WSChatEvent.fromJson(decoded));
        } catch (_) {
          // ignore malformed
        }
      },
      onError: (_) {
        // keep stream alive
      },
      onDone: () {
        // keep stream alive
      },
    );
  }

  void send({required String receiver, required String message}) {
    final channel = _channel;
    if (channel == null) return;

    channel.sink.add(jsonEncode({'receiver': receiver, 'message': message}));
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }
}

