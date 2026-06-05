import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/conversation.dart';
import '../theme/app_colors.dart';
import '../widgets/premium_avatar.dart';
import '../widgets/unread_badge.dart';

class PremiumConversationTile extends StatelessWidget {
  final String username;
  final String lastMessage;
  final int unreadCount;
  final DateTime? timestamp;
  final VoidCallback onTap;

  const PremiumConversationTile({
    super.key,
    required this.username,
    required this.lastMessage,
    required this.unreadCount,
    required this.onTap,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = timestamp != null
        ? DateFormat('HH:mm').format(timestamp!)
        : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cardDark.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.glassBorder.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              PremiumAvatar(username: username, radius: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (timeStr.isNotEmpty)
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  if (unreadCount > 0) ...[
                    const SizedBox(height: 6),
                    UnreadBadge(count: unreadCount),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}