import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

import '../services/auth_storage.dart';
import '../services/message_service.dart';
import '../services/websocket_service.dart';

// Screenshot protection (FLAG_SECURE) is best-effort and primarily works on Android.
// If you build for iOS/desktop, verify platform support in flutter_windowmanager docs.

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final String _userName;
  WebSocketService? _ws;
  StreamSubscription<WSChatEvent>? _wsSub;

  final _messageController = TextEditingController();

  Future<String> _getMyUsername() async {
    return (await AuthStorage.getUsername()) ?? '';
  }

  bool _loading = true;
  String? _error;
  final List<ChatMessage> _messages = [];

  Timer? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final name = (args is Map && args['userName'] is String)
        ? args['userName'] as String
        : 'User';
    _userName = name;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _wsSub?.cancel();
    _ws?.disconnect();
    _messageController.dispose();
    super.dispose();
  }

  int _remainingSeconds(ChatMessage m) {
    if (m.status != 'seen') return 0;
    if (m.seenAt == null) return 0;

    final now = DateTime.now().toUtc();
    final seenAtUtc = m.seenAt!.toUtc();
    const vanishSeconds = 60;

    final elapsed = now.difference(seenAtUtc).inSeconds;
    final remaining = vanishSeconds - elapsed;
    return remaining;
  }

  bool _isExpired(ChatMessage m) {
    if (m.status != 'seen') return false;
    final remaining = _remainingSeconds(m);
    return remaining <= 0;
  }

  Future<void> _markReceivedAsSeen() async {
    // Mark messages as seen when chat opens.
    // We only mark messages that are received from the other user.
    // Backend requires message_id, but our current GET excludes _id.
    // So with current backend, we can only do UI vanish locally.
    // Once backend returns _id in GET, this will work.
    final me = await _getMyUsername();
    if (me.isEmpty) return;

    final toMark = _messages.where((m) => m.sender != me && m.status != 'seen');

    for (final m in toMark) {
      final id = m.id;
      if (id == null || id.isEmpty) continue;
      await MessageService.markMessageSeen(messageId: id);
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final me = await _getMyUsername();
    if (me.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      return;
    }

    final msgs = await MessageService.fetchMessages(
      user1: me,
      user2: _userName,
    );

    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..addAll(msgs);
      _loading = false;
    });

    // Start countdown ticker (1Hz) for seen messages.
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        // Remove expired messages immediately from UI.
        _messages.removeWhere((m) => _isExpired(m));
      });
    });

    // Best-effort mark-as-seen.
    try {
      await _markReceivedAsSeen();
    } catch (e) {
      // Ignore to keep UI working even if backend doesn't return ids.
    }
  }

  @override
  void initState() {
    super.initState();

    // Prevent screenshots/screen recording (Android best-effort).
    // Add flags as early as possible.
    FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initWebSocket();
      await _loadMessages();
    });
  }

  Future<void> _initWebSocket() async {
    _ws?.disconnect();
    await _wsSub?.cancel();

    final me = await _getMyUsername();
    if (me.isEmpty) return;

    _ws = WebSocketService(username: me);
    await _ws!.connect();

    _wsSub = _ws!.events.listen((event) async {
      // Only show events related to this chat screen pair.
      final me = await _getMyUsername();
      if (me.isEmpty) return;

      final belongsToChat =
          (event.sender == _userName && event.receiver == me) ||
          (event.sender == me && event.receiver == _userName);
      if (!belongsToChat) return;

      if (!mounted) return;

      // Append immediately for UX.
      setState(() {
        _messages.add(
          ChatMessage(
            sender: event.sender,
            receiver: event.receiver,
            message: event.message,
            createdAt: event.createdAt,
            status: 'sent',
            seenAt: null,
            id: null,
          ),
        );
      });
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final receiver = _userName;

    try {
      // Send via WebSocket (real-time) and let backend persist + broadcast.
      _ws?.send(receiver: receiver, message: text);

      // Immediately clear for UX.
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_userName)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _messages.isEmpty
                  ? const Center(child: Text('No messages yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final m = _messages[index];
                        // Determine UI alignment based on logged-in username.
                        // If username isn't loaded yet, we fallback to sender comparison.
                        final isMe = m.sender == m.sender;

                        final align = isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft;
                        final color = isMe
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF1A1A1A);
                        final textColor = isMe ? Colors.black : Colors.white;

                        final created = m.createdAt.toLocal();
                        final createdStr =
                            '${created.year.toString().padLeft(4, '0')}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

                        final remaining = _remainingSeconds(m);
                        final showTimer = m.status == 'seen' && remaining > 0;

                        return Align(
                          alignment: align,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: const BoxConstraints(maxWidth: 320),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: DefaultTextStyle.merge(
                              style: TextStyle(color: textColor),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'From: ${m.sender}  →  To: ${m.receiver}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    m.message,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 6),
                                  if (showTimer)
                                    Align(
                                      alignment: isMe
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Colors.black26
                                              : Colors.white10,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          '${remaining}s',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Created: $createdStr',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.extended(
                    onPressed: _send,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                    label: const Text('Send'),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
