import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_colors.dart';

class PremiumAvatar extends StatefulWidget {
  final String? username;
  final bool isOnline;
  final double radius;
  final VoidCallback? onTap;

  static final Map<String, String?> _avatarCache = {};
  static final Map<String, bool> _onlineCache = {};
  static final Map<String, DateTime?> _lastSeenCache = {};
  static final Map<String, Future<Map<String, dynamic>>> _pendingFetches = {};

  static void updateCache(String username, String? avatar) {
    _avatarCache[username] = avatar;
  }

  const PremiumAvatar({
    super.key,
    this.username,
    this.isOnline = false,
    this.radius = 20,
    this.onTap,
  });

  @override
  State<PremiumAvatar> createState() => _PremiumAvatarState();
}

class _PremiumAvatarState extends State<PremiumAvatar> {
  String? _avatar;
  bool _isOnline = false;
  StreamSubscription? _statusSub;

  final List<LinearGradient> _avatarGradients = [
    const LinearGradient(colors: [Color(0xFF7B2FF7), Color(0xFF3A8DFF)]),
    const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
    const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
    const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF3B82F6)]),
    const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
  ];

  @override
  void initState() {
    super.initState();
    _isOnline = widget.isOnline;
    _loadAvatarAndStatus();
    _subscribeToStatusUpdates();
  }

  @override
  void didUpdateWidget(covariant PremiumAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.username != oldWidget.username) {
      _isOnline = widget.isOnline;
      _loadAvatarAndStatus();
      _subscribeToStatusUpdates();
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  void _subscribeToStatusUpdates() {
    final name = widget.username;
    _statusSub?.cancel();
    if (name == null || name.isEmpty) return;

    _statusSub = WebSocketService.statusStream.listen((event) {
      if (event.username == name) {
        PremiumAvatar._onlineCache[name] = event.isOnline;
        if (event.lastSeen != null) {
          PremiumAvatar._lastSeenCache[name] = event.lastSeen;
        }
        if (mounted) {
          setState(() {
            _isOnline = event.isOnline;
          });
        }
      }
    });
  }

  Future<void> _loadAvatarAndStatus() async {
    final name = widget.username;
    if (name == null || name.isEmpty) {
      setState(() {
        _avatar = null;
        _isOnline = false;
      });
      return;
    }

    // Check static cache
    if (PremiumAvatar._avatarCache.containsKey(name)) {
      if (mounted) {
        setState(() {
          _avatar = PremiumAvatar._avatarCache[name];
          _isOnline = PremiumAvatar._onlineCache[name] ?? widget.isOnline;
        });
      }
      return;
    }

    // Check if fetch in progress
    if (PremiumAvatar._pendingFetches.containsKey(name)) {
      try {
        final profile = await PremiumAvatar._pendingFetches[name]!;
        if (!mounted || widget.username != name) return;
        final av = profile['avatar']?.toString();
        final online = profile['is_online'] as bool? ?? false;
        final lastSeenRaw = profile['last_seen'];
        DateTime? lastSeen;
        if (lastSeenRaw != null) {
          lastSeen = DateTime.tryParse(lastSeenRaw.toString());
        }

        PremiumAvatar._avatarCache[name] = av;
        PremiumAvatar._onlineCache[name] = online;
        if (lastSeen != null) {
          PremiumAvatar._lastSeenCache[name] = lastSeen;
        }

        setState(() {
          _avatar = av;
          _isOnline = online;
        });
      } catch (_) {}
      return;
    }

    // Start fetching
    final fetch = ApiService.fetchUserProfile(name);
    PremiumAvatar._pendingFetches[name] = fetch;

    try {
      final profile = await fetch;
      PremiumAvatar._pendingFetches.remove(name);
      final av = profile['avatar']?.toString();
      final online = profile['is_online'] as bool? ?? false;
      final lastSeenRaw = profile['last_seen'];
      DateTime? lastSeen;
      if (lastSeenRaw != null) {
        lastSeen = DateTime.tryParse(lastSeenRaw.toString());
      }

      PremiumAvatar._avatarCache[name] = av;
      PremiumAvatar._onlineCache[name] = online;
      if (lastSeen != null) {
        PremiumAvatar._lastSeenCache[name] = lastSeen;
      }

      if (!mounted || widget.username != name) return;
      setState(() {
        _avatar = av;
        _isOnline = online;
      });
    } catch (_) {
      PremiumAvatar._pendingFetches.remove(name);
    }
  }

  Widget _buildAvatarWidget() {
    final name = widget.username ?? '';
    final initials = name.isNotEmpty ? name.substring(0, name.length > 1 ? 2 : 1).toUpperCase() : '?';

    // 1. HTTP/HTTPS Image URL
    if (_avatar != null && (_avatar!.startsWith('http://') || _avatar!.startsWith('https://'))) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: AppColors.cardDark,
        backgroundImage: NetworkImage(_avatar!),
      );
    }

    // 2. Custom Gradient Initials
    if (_avatar != null && _avatar!.startsWith('initials:')) {
      final parts = _avatar!.split(':');
      final gradIdx = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final grad = _avatarGradients[gradIdx.clamp(0, _avatarGradients.length - 1)];

      return Container(
        width: widget.radius * 2,
        height: widget.radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: grad,
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: GoogleFonts.montserrat(
            fontSize: widget.radius * 0.75,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    // 3. Preset icon
    if (_avatar != null && _avatar!.startsWith('preset:')) {
      final index = int.tryParse(_avatar!.split(':')[1]) ?? 0;
      final List<IconData> icons = [
        Icons.face_retouching_natural_rounded,
        Icons.rocket_launch_rounded,
        Icons.sports_esports_rounded,
        Icons.palette_rounded,
        Icons.auto_awesome_rounded,
        Icons.cookie_rounded,
      ];
      final List<Color> colors = [
        Colors.purpleAccent,
        Colors.blueAccent,
        Colors.orangeAccent,
        Colors.pinkAccent,
        Colors.tealAccent,
        Colors.amberAccent,
      ];
      final icon = icons[index.clamp(0, icons.length - 1)];
      final color = colors[index.clamp(0, colors.length - 1)];

      return Container(
        width: widget.radius * 2,
        height: widget.radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: widget.radius * 0.9,
          color: color,
        ),
      );
    }

    // 4. Default gradient initials
    final gradient = _avatarGradients[0];
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.montserrat(
          fontSize: widget.radius * 0.75,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _isOnline ? const Color(0xFF10B981) : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        children: [
          _buildAvatarWidget(),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: widget.radius * 0.5,
              height: widget.radius * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                border: Border.all(
                  color: AppColors.amoledBlack,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}