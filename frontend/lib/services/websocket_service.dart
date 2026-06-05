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

  final bool isDeletedEveryone;
  final List<String> deletedFor;

  const WSChatEvent({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.message,
    required this.createdAt,
    required this.status,
    required this.seenAt,
    this.isDeletedEveryone = false,
    this.deletedFor = const [],
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

    final isDeletedEveryone = json['is_deleted_everyone'] as bool? ?? false;
    final deletedForRaw = json['deleted_for'];
    final deletedFor = deletedForRaw is List
        ? List<String>.from(deletedForRaw.map((x) => x.toString()))
        : const <String>[];

    return WSChatEvent(
      id: (idRaw ?? '').toString(),
      sender: (json['sender'] ?? '').toString(),
      receiver: (json['receiver'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: createdAt,
      status: (json['status'] ?? 'sent').toString(),
      seenAt: seenAt,
      isDeletedEveryone: isDeletedEveryone,
      deletedFor: deletedFor,
    );
  }
}

class WSTypingEvent {
  final String sender;
  final String receiver;
  final bool isTyping;

  const WSTypingEvent({
    required this.sender,
    required this.receiver,
    required this.isTyping,
  });
}

class WSStatusEvent {
  final String username;
  final bool isOnline;
  final DateTime? lastSeen;

  const WSStatusEvent({
    required this.username,
    required this.isOnline,
    this.lastSeen,
  });
}

class WebSocketService {
  final String username;
  WebSocketChannel? _channel;

  final StreamController<WSChatEvent> _events =
      StreamController<WSChatEvent>.broadcast();
  Stream<WSChatEvent> get events => _events.stream;

  final StreamController<WSTypingEvent> _typingEvents =
      StreamController<WSTypingEvent>.broadcast();
  Stream<WSTypingEvent> get typingEvents => _typingEvents.stream;

  static final StreamController<WSStatusEvent> _statusController =
      StreamController<WSStatusEvent>.broadcast();
  static Stream<WSStatusEvent> get statusStream => _statusController.stream;

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
          final type = decoded['type']?.toString();

          if (type == 'typing') {
            final sender = decoded['sender']?.toString() ?? '';
            final receiver = decoded['receiver']?.toString() ?? '';
            _typingEvents.add(WSTypingEvent(
              sender: sender,
              receiver: receiver,
              isTyping: true,
            ));
          } else if (type == 'status') {
            final username = decoded['username']?.toString() ?? '';
            final isOnline = decoded['is_online'] as bool? ?? false;
            final lastSeenRaw = decoded['last_seen'];
            DateTime? lastSeen;
            if (lastSeenRaw != null) {
              lastSeen = DateTime.tryParse(lastSeenRaw.toString());
            }
            _statusController.add(WSStatusEvent(
              username: username,
              isOnline: isOnline,
              lastSeen: lastSeen,
            ));
          } else if (type == 'delete_everyone') {
            final event = WSChatEvent.fromJson(decoded);
            print('[DEBUG] Message deleted for everyone: ${event.id}');
            _events.add(event);
          } else {
            final event = WSChatEvent.fromJson(decoded);
            print('[DEBUG] Message received: ${event.sender} -> ${event.receiver} : ${event.message}');
            _events.add(event);
          }
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

  void sendTyping({required String receiver}) {
    final channel = _channel;
    if (channel == null) {
      print('[DEBUG] WebSocket cannot send typing, channel is null');
      return;
    }

    channel.sink.add(jsonEncode({
      'type': 'typing',
      'receiver': receiver,
    }));
  }

  Future<void> disconnect() async {
    if (_channel == null) return;
    print('[DEBUG] WebSocket disconnecting for user: $username');
    await _channel?.sink.close();
    _channel = null;
  }
}
