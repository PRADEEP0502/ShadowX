import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:intl/intl.dart';

import '../services/active_chat_tracker.dart';
import '../services/auth_storage.dart';
import '../services/message_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/premium_avatar.dart';
import '../widgets/premium_chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final String _userName;
  String _myUsername = '';
  WebSocketService? _ws;
  StreamSubscription<WSChatEvent>? _wsSub;

  final _messageController = TextEditingController();

  bool _loading = true;
  String? _error;
  final List<ChatMessage> _messages = [];

  Timer? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    _userName = (args is Map && args['userName'] is String)
        ? args['userName'] as String
        : 'User';
    ActiveChatTracker.activeUser = _userName;
  }

  @override
  void initState() {
    super.initState();

    FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _myUsername = (await AuthStorage.getUsername()) ?? '';
      await _initWebSocket();
      await _loadMessages();
    });
  }

  @override
  void dispose() {
    ActiveChatTracker.activeUser = null;
    _ticker?.cancel();
    _wsSub?.cancel();
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
    if (m.status != 'seen' || m.seenAt == null) return false;
    final diff = DateTime.now().toUtc().difference(m.seenAt!.toUtc());
    return diff.inSeconds >= 60;
  }

  Future<void> _markReceivedAsSeen() async {
    if (_myUsername.isEmpty) return;

    final toMark = _messages.where(
      (m) => m.sender != _myUsername && m.status != 'seen',
    );

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

    if (_myUsername.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      return;
    }

    final msgs = await MessageService.fetchMessages(
      user1: _myUsername,
      user2: _userName,
    );

    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..addAll(msgs);
      _loading = false;
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => _isExpired(m));
      });
    });

    try {
      await _markReceivedAsSeen();
    } catch (_) {}
  }

  Future<void> _initWebSocket() async {
    await _wsSub?.cancel();

    if (_myUsername.isEmpty) return;

    _ws = WebSocketService(username: _myUsername);
    await _ws!.connect();

    _wsSub = _ws!.events.listen((event) async {
      final belongsToChat =
          (event.sender == _userName && event.receiver == _myUsername) ||
          (event.sender == _myUsername && event.receiver == _userName);
      if (!belongsToChat) return;

      if (event.sender != _myUsername && event.id.isNotEmpty) {
        try {
          await MessageService.markMessageSeen(messageId: event.id);
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        final idx = (event.id.isNotEmpty)
            ? _messages.indexWhere((m) => m.id == event.id)
            : -1;

        final newMessage = ChatMessage(
          id: event.id.isNotEmpty ? event.id : null,
          sender: event.sender,
          receiver: event.receiver,
          message: event.message,
          createdAt: event.createdAt,
          status: event.status,
          seenAt: event.seenAt,
        );

        if (idx >= 0) {
          _messages[idx] = newMessage;
        } else {
          _messages.add(newMessage);
        }
      });
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final receiver = _userName;
      _ws?.send(receiver: receiver, message: text);
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  String _formatTime(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.amoledBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            PremiumAvatar(username: _userName, radius: 18),
            const SizedBox(width: 12),
            Text(_userName, style: AppTextStyles.headlineMedium),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _PatternPainter())),
          Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryPurple,
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: TextStyle(color: AppColors.errorRed),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          final finalIsMe = m.sender == _myUsername;
                          final remaining = _remainingSeconds(m);
                          final showTimer = m.status == 'seen' && remaining > 0;

                          return PremiumChatBubble(
                            message: m.message,
                            isMe: finalIsMe,
                            time: _formatTime(m.createdAt),
                            status: m.status,
                            countdown: showTimer ? '$remaining' : null,
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.glassBorder.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.amoledBlack,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.glassBorder.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textHint,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.send_rounded,
                                color: AppColors.primaryPurple,
                              ),
                              onPressed: _send,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryPurple.withOpacity(0.03)
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;
    for (var y = 0.0; y < size.height; y += spacing) {
      for (var x = 0.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
