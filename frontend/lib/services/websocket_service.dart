import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/api_constants.dart';

class WSChatEvent {
  final String id;
  final String sender;
  final String receiver;
  final String message;
  final DateTime createdAt;

  /// "sent" | "delivered" | "seen"
  final String status;

  /// May be null when status is sent/delivered.
  final DateTime? seenAt;

  const WSChatEvent({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.message,
    required this.createdAt,
    required this.status,
    required this.seenAt,
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
    final idRaw = json['_id'] ?? json['id'];

    final createdAt = _parseDateTime(json['created_at'] ?? json['createdAt']);

    final seenAtRaw = json['seen_at'] ?? json['seenAt'];
    final seenAt = (seenAtRaw == null)
        ? null
        : (() {
            final parsed = _parseDateTime(seenAtRaw);
            return parsed.millisecondsSinceEpoch == 0 ? null : parsed;
          })();

    return WSChatEvent(
      id: (idRaw ?? '').toString(),
      sender: (json['sender'] ?? '').toString(),
      receiver: (json['receiver'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: createdAt,
      status: (json['status'] ?? 'sent').toString(),
      seenAt: seenAt,
    );
  }
}

class WebSocketService {
  final String username;
  WebSocketChannel? _channel;

  final StreamController<WSChatEvent> _events =
      StreamController<WSChatEvent>.broadcast();

  Stream<WSChatEvent> get events => _events.stream;

  // Caching factory singleton pattern
  static WebSocketService? _instance;

  factory WebSocketService({required String username}) {
    if (_instance == null || _instance!.username != username) {
      _instance?.disconnect();
      _instance = WebSocketService._internal(username);
    }
    return _instance!;
  }

  WebSocketService._internal(this.username);

  Future<void> connect() async {
    if (_channel != null) {
      print('[DEBUG] WebSocket already connected for user: $username');
      return;
    }

    print('[DEBUG] WebSocket connecting for user: $username');
    final wsUrl = '${ApiConstants.baseWsUrl}/ws/$username';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    print('[DEBUG] WebSocket connected for user: $username');

    _channel!.stream.listen(
      (dynamic raw) {
        try {
          final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
          final event = WSChatEvent.fromJson(decoded);
          print('[DEBUG] Message received: ${event.sender} -> ${event.receiver} : ${event.message}');
          _events.add(event);
        } catch (_) {
          // ignore malformed payload
        }
      },
      onError: (_) {},
      onDone: () {
        print('[DEBUG] WebSocket connection closed for user: $username');
        _channel = null;
      },
    );
  }

  void send({required String receiver, required String message}) {
    final channel = _channel;
    if (channel == null) {
      print('[DEBUG] WebSocket cannot send, channel is null');
      return;
    }

    channel.sink.add(jsonEncode({'receiver': receiver, 'message': message}));
  }

  Future<void> disconnect() async {
    if (_channel == null) return;
    print('[DEBUG] WebSocket disconnecting for user: $username');
    await _channel?.sink.close();
    _channel = null;
  }
}
