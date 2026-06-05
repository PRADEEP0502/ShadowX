import 'dart:async';

import '../models/conversation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_service.dart';

/// Listens to the user's websocket channel and converts incoming WS messages
/// into updates for the WhatsApp-style conversation list.
class HomeConversationWebSocket {
  final String myUsername;
  final WebSocketService _ws;

  HomeConversationWebSocket({required this.myUsername})
    : _ws = WebSocketService(username: myUsername);

  Future<void> connect() => _ws.connect();
  void disconnect() => _ws.disconnect();

  Stream<WSChatEvent> get events => _ws.events;

  Stream<Conversation> onConversationUpdateFor(String otherUsername) {
    return _ws.events
        .where(
          (e) =>
              (e.sender == myUsername && e.receiver == otherUsername) ||
              (e.sender == otherUsername && e.receiver == myUsername),
        )
        .map(
          (e) => Conversation(
            username: otherUsername,
            lastMessage: e.message,
            timestamp: e.createdAt,
            unreadCount: 0,
          ),
        );
  }

  Stream<Conversation> get allConversationUpdates {
    // When a message arrives, we can determine the other participant.
    return _ws.events.map((e) {
      final other = e.sender == myUsername ? e.receiver : e.sender;
      return Conversation(
        username: other,
        lastMessage: e.message,
        timestamp: e.createdAt,
        unreadCount: 0,
      );
    });
  }
}
