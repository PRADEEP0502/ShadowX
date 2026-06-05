import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/active_chat_tracker.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/message_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_colors.dart';
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
  StreamSubscription<WSStatusEvent>? _statusSub;
  StreamSubscription<WSTypingEvent>? _typingSub;

  final _messageController = TextEditingController();

  bool _loading = true;
  String? _error;
  final List<ChatMessage> _messages = [];

  Timer? _ticker;
  Timer? _typingTimer;

  bool _otherUserOnline = false;
  DateTime? _otherUserLastSeen;
  bool _otherUserTyping = false;
  DateTime? _lastTypingSent;

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
      await _fetchUserPresence();
    });
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    ActiveChatTracker.activeUser = null;
    _ticker?.cancel();
    _typingTimer?.cancel();
    _wsSub?.cancel();
    _statusSub?.cancel();
    _typingSub?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _messageController.text;
    if (text.isEmpty) return;
    final now = DateTime.now();
    if (_lastTypingSent == null || now.difference(_lastTypingSent!).inSeconds >= 2) {
      _lastTypingSent = now;
      _ws?.sendTyping(receiver: _userName);
    }
  }

  Future<void> _fetchUserPresence() async {
    try {
      final profile = await ApiService.fetchUserProfile(_userName);
      if (!mounted) return;
      setState(() {
        _otherUserOnline = profile['is_online'] as bool? ?? false;
        final lastSeenRaw = profile['last_seen'];
        if (lastSeenRaw != null) {
          _otherUserLastSeen = DateTime.tryParse(lastSeenRaw.toString());
        }
      });
    } catch (_) {}
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
    _statusSub?.cancel();
    _typingSub?.cancel();

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
          isDeletedEveryone: event.isDeletedEveryone,
          deletedFor: event.deletedFor,
        );

        if (idx >= 0) {
          _messages[idx] = newMessage;
        } else {
          _messages.add(newMessage);
        }
      });
    });

    _statusSub = WebSocketService.statusStream.listen((event) {
      if (event.username == _userName) {
        if (!mounted) return;
        setState(() {
          _otherUserOnline = event.isOnline;
          if (event.lastSeen != null) {
            _otherUserLastSeen = event.lastSeen;
          }
        });
      }
    });

    _typingSub = _ws!.typingEvents.listen((event) {
      if (event.sender == _userName && event.receiver == _myUsername) {
        if (!mounted) return;
        setState(() {
          _otherUserTyping = true;
        });
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _otherUserTyping = false;
            });
          }
        });
      }
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

  Widget _buildSubtitleWidget() {
    if (_otherUserTyping) {
      return Text(
        'is typing...',
        style: GoogleFonts.montserrat(
          color: AppColors.primaryPurple,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (_otherUserOnline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Online',
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    if (_otherUserLastSeen != null) {
      final timeStr = DateFormat('HH:mm').format(_otherUserLastSeen!.toLocal());
      return Text(
        'Last seen $timeStr',
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 11,
        ),
      );
    }
    return const Text(
      'Offline',
      style: TextStyle(
        color: AppColors.textTertiary,
        fontSize: 11,
      ),
    );
  }

  void _showMessageActions(BuildContext context, ChatMessage m) {
    final isMyMessage = m.sender == _myUsername;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: AppColors.glassBorder.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Colors.white),
                  title: const Text('Copy', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _copyMessageText(m);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  title: const Text('Delete for Me', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessageForMe(m);
                  },
                ),
                if (isMyMessage)
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: AppColors.errorRed),
                    title: const Text('Delete for Everyone', style: TextStyle(color: AppColors.errorRed)),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessageForEveryone(m);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: Colors.white),
                  title: const Text('Message Info', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showMessageInfo(m);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _copyMessageText(ChatMessage m) {
    Clipboard.setData(ClipboardData(text: m.message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        backgroundColor: AppColors.primaryPurple,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteMessageForMe(ChatMessage m) async {
    if (m.id == null) return;
    try {
      await MessageService.deleteForMe(messageId: m.id!, username: _myUsername);
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((msg) => msg.id == m.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _deleteMessageForEveryone(ChatMessage m) async {
    if (m.id == null) return;
    try {
      await MessageService.deleteForEveryone(messageId: m.id!, username: _myUsername);
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((msg) => msg.id == m.id);
        if (idx >= 0) {
          _messages[idx] = ChatMessage(
            id: m.id,
            sender: m.sender,
            receiver: m.receiver,
            message: 'This message was deleted',
            createdAt: m.createdAt,
            status: m.status,
            seenAt: m.seenAt,
            isDeletedEveryone: true,
            deletedFor: m.deletedFor,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  void _showMessageInfo(ChatMessage m) {
    final sentTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(m.createdAt.toLocal());
    final seenTimeStr = m.seenAt != null
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(m.seenAt!.toLocal())
        : 'N/A';

    String statusText = 'Sent';
    IconData statusIcon = Icons.done_rounded;
    Color statusColor = AppColors.textSecondary;

    if (m.status == 'seen') {
      statusText = 'Read / Seen';
      statusIcon = Icons.done_all_rounded;
      statusColor = const Color(0xFF3B82F6);
    } else if (m.status == 'delivered') {
      statusText = 'Delivered';
      statusIcon = Icons.done_all_rounded;
      statusColor = AppColors.textSecondary;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: AppColors.glassBorder.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Info',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Message:',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m.isDeletedEveryone ? 'This message was deleted' : m.message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontStyle: m.isDeletedEveryone ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                const Divider(color: AppColors.divider, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sent',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sentTimeStr,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                    const Icon(Icons.send_rounded, color: AppColors.primaryPurple, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Icon(statusIcon, color: statusColor, size: 20),
                  ],
                ),
                if (m.status == 'seen') ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Read Time',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            seenTimeStr,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                      const Icon(Icons.visibility_rounded, color: Color(0xFF3B82F6), size: 20),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _userName,
                    style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildSubtitleWidget(),
                ],
              ),
            ),
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

                           return GestureDetector(
                             onLongPress: m.isDeletedEveryone
                                 ? null
                                 : () => _showMessageActions(context, m),
                             child: PremiumChatBubble(
                               message: m.message,
                               isMe: finalIsMe,
                               time: _formatTime(m.createdAt),
                               status: m.status,
                               countdown: showTimer ? '$remaining' : null,
                               isDeletedEveryone: m.isDeletedEveryone,
                             ),
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
