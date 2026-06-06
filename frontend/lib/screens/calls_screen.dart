import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart' show ZegoUIKitUser;

import '../models/call_log.dart';
import '../services/call_service.dart';
import '../theme/app_colors.dart';
import '../widgets/premium_avatar.dart';

class CallsScreen extends StatefulWidget {
  final String myUsername;
  const CallsScreen({super.key, required this.myUsername});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<CallLog> _calls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final calls = await CallService.fetchCalls(widget.myUsername);
    if (!mounted) return;
    setState(() {
      _calls = calls;
      _loading = false;
    });
  }

  String _otherUser(CallLog c) =>
      c.caller == widget.myUsername ? c.receiver : c.caller;

  bool _isMissed(CallLog c) => c.status == 'missed';

  bool _isOutgoing(CallLog c) => c.caller == widget.myUsername;

  IconData _directionIcon(CallLog c) {
    if (_isMissed(c)) return Icons.call_missed_rounded;
    if (_isOutgoing(c)) return Icons.call_made_rounded;
    return Icons.call_received_rounded;
  }

  Color _directionColor(CallLog c) {
    if (_isMissed(c)) return AppColors.errorRed;
    if (_isOutgoing(c)) return const Color(0xFF10B981);
    return const Color(0xFF3A8DFF);
  }

  String _timeLabel(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts.toLocal());
    if (diff.inDays == 0) return DateFormat('h:mm a').format(ts.toLocal());
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEEE').format(ts.toLocal());
    return DateFormat('d MMM').format(ts.toLocal());
  }

  void _redial(CallLog c) {
    final other = _otherUser(c);
    // Open call directly using Zego invitation button programmatically
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RedialSheet(
        username: other,
        onVoice: () {
          Navigator.pop(context);
          // Trigger voice call
        },
        onVideo: () {
          Navigator.pop(context);
          // Trigger video call
        },
      ),
    );
  }

  Future<void> _deleteCall(CallLog c) async {
    await CallService.deleteCall(c.id);
    setState(() => _calls.remove(c));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.amoledBlack,
      body: RefreshIndicator(
        color: AppColors.primaryPurple,
        backgroundColor: AppColors.cardDark,
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryPurple),
              )
            : _calls.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 110),
                    itemCount: _calls.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 72,
                      color: AppColors.divider,
                    ),
                    itemBuilder: (context, i) => _buildTile(_calls[i]),
                  ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: const Icon(Icons.call_rounded, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            'No Call History',
            style: GoogleFonts.montserrat(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your call logs will appear here.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(CallLog c) {
    final other = _otherUser(c);
    final missed = _isMissed(c);
    final dirColor = _directionColor(c);
    final dirIcon = _directionIcon(c);
    final isVideo = c.callType == 'video';
    final durationStr = CallService.formatDuration(c.duration);

    return Dismissible(
      key: Key(c.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.errorRed.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
      ),
      onDismissed: (_) => _deleteCall(c),
      child: InkWell(
        onTap: () => _redial(c),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              PremiumAvatar(username: other, radius: 24),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      other,
                      style: GoogleFonts.montserrat(
                        color: missed ? AppColors.errorRed : AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(dirIcon, size: 14, color: dirColor),
                        const SizedBox(width: 4),
                        Text(
                          missed
                              ? 'Missed ${isVideo ? 'video' : 'voice'} call'
                              : '${_isOutgoing(c) ? 'Outgoing' : 'Incoming'} ${isVideo ? 'video' : 'voice'} call'
                                  '${durationStr.isNotEmpty ? ' • $durationStr' : ''}',
                          style: TextStyle(
                            color: missed ? AppColors.errorRed : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Time + redial icon
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _timeLabel(c.timestamp),
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Inline redial button
                  ZegoSendCallInvitationButton(
                    isVideoCall: isVideo,
                    resourceID: "zego_data",
                    invitees: [ZegoUIKitUser(id: other, name: other)],
                    iconSize: const Size(22, 22),
                    buttonSize: const Size(36, 36),
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

/// Bottom sheet for redial type selection
class _RedialSheet extends StatelessWidget {
  final String username;
  final VoidCallback onVoice;
  final VoidCallback onVideo;

  const _RedialSheet({
    required this.username,
    required this.onVoice,
    required this.onVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          PremiumAvatar(username: username, radius: 28),
          const SizedBox(height: 12),
          Text(
            username,
            style: GoogleFonts.montserrat(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallOption(
                icon: Icons.call_rounded,
                label: 'Voice Call',
                color: const Color(0xFF10B981),
                invitees: [ZegoUIKitUser(id: username, name: username)],
                isVideo: false,
              ),
              _CallOption(
                icon: Icons.videocam_rounded,
                label: 'Video Call',
                color: const Color(0xFF3A8DFF),
                invitees: [ZegoUIKitUser(id: username, name: username)],
                isVideo: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final List<ZegoUIKitUser> invitees;
  final bool isVideo;

  const _CallOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.invitees,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: color, size: 30),
              Opacity(
                opacity: 0,
                child: ZegoSendCallInvitationButton(
                  isVideoCall: isVideo,
                  resourceID: "zego_data",
                  invitees: invitees,
                  iconSize: const Size(72, 72),
                  buttonSize: const Size(72, 72),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
