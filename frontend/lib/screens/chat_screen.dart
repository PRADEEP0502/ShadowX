import 'package:flutter/material.dart';

import '../services/mock_chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final String _userName;
  final _messageController = TextEditingController();
  final List<_Bubble> _bubbles = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final name = (args is Map && args['userName'] is String)
        ? args['userName'] as String
        : 'User';
    _userName = name;

    if (_bubbles.isEmpty) {
      final initial = MockChatService.messagesFor(_userName);
      for (final msg in initial) {
        _bubbles.add(_Bubble(text: msg, fromMe: false));
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _bubbles.add(_Bubble(text: text, fromMe: true));
    _messageController.clear();
    setState(() {});

    // Lightweight mock reply.
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _bubbles.add(_Bubble(text: 'Got it ✅', fromMe: false));
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_userName)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _bubbles.length,
                itemBuilder: (context, index) {
                  final b = _bubbles[index];
                  final align = b.fromMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft;
                  final color = b.fromMe
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFF1A1A1A);
                  final textColor = b.fromMe ? Colors.black : Colors.white;

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
                      child: Text(b.text, style: TextStyle(color: textColor)),
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

class _Bubble {
  final String text;
  final bool fromMe;

  _Bubble({required this.text, required this.fromMe});
}
