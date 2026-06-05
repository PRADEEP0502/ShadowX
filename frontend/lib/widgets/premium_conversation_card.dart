import 'package:flutter/material.dart';

import '../models/conversation.dart';

class PremiumConversationCard extends StatelessWidget {
  final Conversation conversation;
  final bool hasConversation;
  final VoidCallback onTap;
  final String timeStr;
  final String lastMessage;
  final String username;

  const PremiumConversationCard({
    super.key,
    required this.conversation,
    required this.hasConversation,
    required this.onTap,
    required this.timeStr,
    required this.lastMessage,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF2EE59D);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: green.withOpacity(0.18), width: 1),
          color: Colors.black.withOpacity(0.24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: green.withOpacity(0.15),
                  border: Border.all(color: green.withOpacity(0.35), width: 1),
                ),
                child: const Center(
                  child: Icon(Icons.person, color: Color(0xFF2EE59D), size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  if (conversation.unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: green.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: green.withOpacity(0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      child: Text(
                        '${conversation.unreadCount}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
