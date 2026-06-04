class Conversation {
  final String username;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;

  const Conversation({
    required this.username,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final username = (json['username'] ?? '').toString();
    final lastMessage = (json['last_message'] ?? '').toString();
    final rawTs = json['timestamp'];

    DateTime parsed;
    if (rawTs is String) {
      parsed =
          DateTime.tryParse(rawTs) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else if (rawTs is int) {
      parsed = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      parsed = DateTime.fromMillisecondsSinceEpoch(0);
    }

    final unreadCountRaw = json['unread_count'];
    final unreadCount = (unreadCountRaw == null)
        ? 0
        : int.tryParse(unreadCountRaw.toString()) ?? 0;

    return Conversation(
      username: username,
      lastMessage: lastMessage,
      timestamp: parsed,
      unreadCount: unreadCount,
    );
  }
}
