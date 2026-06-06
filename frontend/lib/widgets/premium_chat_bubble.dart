import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import 'premium_voice_bubble.dart';

class PremiumChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;
  final String? status;
  final String? countdown;
  final bool isDeletedEveryone;
  final String messageType;
  final VoidCallback? onImageTap;

  const PremiumChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
    this.status,
    this.countdown,
    this.isDeletedEveryone = false,
    this.messageType = 'text',
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Colors.white;
    final statusColor = isMe ? Colors.white70 : AppColors.primaryPurple;
    final bubbleColor = isDeletedEveryone
        ? const Color(0xFF1E1E22)
        : (isMe ? null : const Color(0xFF252529));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: (isMe && !isDeletedEveryone)
                ? const LinearGradient(
                    colors: [Color(0xFF7B2FF7), Color(0xFF3A8DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 20),
            ),
            border: Border.all(
              color: AppColors.glassBorder.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              if (isMe && !isDeletedEveryone)
                BoxShadow(
                  color: AppColors.primaryPurple.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDeletedEveryone)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.block_rounded,
                        color: Colors.white38,
                        size: 15,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'This message was deleted',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  )
                else if (messageType == 'image')
                  GestureDetector(
                    onTap: onImageTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Hero(
                        tag: message,
                        child: CachedNetworkImage(
                          imageUrl: message,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 200,
                            height: 150,
                            color: Colors.black12,
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.primaryPurple,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 200,
                            height: 150,
                            color: Colors.black26,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white24,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (messageType == 'voice')
                  PremiumVoiceBubble(
                    audioUrl: message,
                    isMe: isMe,
                  )
                else
                  Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (countdown != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.15)
                                : AppColors.primaryPurple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            countdown!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isMe
                                  ? Colors.white70
                                  : AppColors.primaryPurple,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        time,
                        style: TextStyle(
                          color: isMe && !isDeletedEveryone
                              ? Colors.white70
                              : AppColors.textTertiary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (status != null && !isDeletedEveryone) ...[
                        const SizedBox(width: 4),
                        Icon(
                          status == 'seen'
                              ? Icons.done_all_rounded
                              : status == 'delivered'
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                          size: 14,
                          color: status == 'seen'
                              ? const Color(0xFF3B82F6)
                              : statusColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}