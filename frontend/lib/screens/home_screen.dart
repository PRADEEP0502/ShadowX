import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation.dart';
import '../services/active_chat_tracker.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/conversation_service.dart';
import '../services/message_service.dart';
import '../services/home_conversation_ws_service.dart';
import '../services/local_notifications.dart';
import '../services/websocket_service.dart';
import '../theme/app_colors.dart';
import '../widgets/floating_search_bar.dart';
import '../widgets/premium_conversation_tile.dart';
import 'profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<String> _getUsername() async {
    return (await AuthStorage.getUsername()) ?? '';
  }

  final _searchController = TextEditingController();

  Timer? _searchDebounce;
  bool _searchLoading = false;
  List<Map<String, dynamic>> _foundUsers = const [];
  String? _searchError;

  bool _loading = false;
  String? _error;

  final Map<String, Conversation> _conversationByUser = {};

  StreamSubscription<WSChatEvent>? _wsSub;
  HomeConversationWebSocket? _homeWs;

  String _myUsername = '';
  int _currentTabIndex = 0;

  List<String> _pinnedUsers = [];
  List<String> _mutedUsers = [];
  List<String> _archivedUsers = [];
  int _selectedCategoryIndex = 0; // 0 = All Messages, 1 = Archived

  @override
  void dispose() {
    _wsSub?.cancel();
    _homeWs?.disconnect();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final myUsername = await _getUsername();
      if (myUsername.isEmpty) return;

      final list = await ConversationService.fetchConversations(myUsername);
      if (!mounted) return;

      _conversationByUser
        ..clear()
        ..addEntries(list.map((c) => MapEntry(c.username, c)));

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _connectWebSocket(String myUsername) async {
    await _wsSub?.cancel();
    _homeWs?.disconnect();

    _homeWs = HomeConversationWebSocket(myUsername: myUsername);
    await _homeWs!.connect();

    _wsSub = _homeWs!.events.listen((event) {
      if (!mounted) return;

      final other = event.sender == myUsername ? event.receiver : event.sender;
      final isReceived = event.sender != myUsername;

      setState(() {
        final existing = _conversationByUser[other];
        final currentUnread = existing?.unreadCount ?? 0;

        final isCurrentlyChatting = ActiveChatTracker.activeUser == other;
        final increment = (isReceived && !isCurrentlyChatting && !event.isDeletedEveryone) ? 1 : 0;

        _conversationByUser[other] = Conversation(
          username: other,
          lastMessage: event.message,
          timestamp: event.createdAt,
          unreadCount: currentUnread + increment,
        );
      });

      if (isReceived && ActiveChatTracker.activeUser != event.sender) {
        if (_mutedUsers.contains(event.sender)) {
          print('[DEBUG] Notification suppressed for muted user: ${event.sender}');
          return;
        }
        try {
          print('[DEBUG] Notification triggered: ${event.sender} -> ${event.message}');
          LocalNotificationService.showMessageNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
            title: event.sender,
            body: event.message,
          );
        } catch (_) {}
      }
    });
  }

  void _handleUsernameChanged(String newUsername) async {
    setState(() {
      _myUsername = newUsername;
    });
    await _connectWebSocket(newUsername);
    await _loadConversations();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pinnedUsers = prefs.getStringList('pinned_users') ?? [];
      _mutedUsers = prefs.getStringList('muted_users') ?? [];
      _archivedUsers = prefs.getStringList('archived_users') ?? [];
    });
  }

  Future<void> _togglePin(String username) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_pinnedUsers.contains(username)) {
        _pinnedUsers.remove(username);
      } else {
        _pinnedUsers.add(username);
      }
    });
    await prefs.setStringList('pinned_users', _pinnedUsers);
  }

  Future<void> _toggleMute(String username) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_mutedUsers.contains(username)) {
        _mutedUsers.remove(username);
      } else {
        _mutedUsers.add(username);
      }
    });
    await prefs.setStringList('muted_users', _mutedUsers);
  }

  Future<void> _toggleArchive(String username) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_archivedUsers.contains(username)) {
        _archivedUsers.remove(username);
      } else {
        _archivedUsers.add(username);
        _pinnedUsers.remove(username); // Auto unpin archived
      }
    });
    await prefs.setStringList('pinned_users', _pinnedUsers);
    await prefs.setStringList('archived_users', _archivedUsers);
  }

  void _showConversationActions(BuildContext context, String username) {
    final isPinned = _pinnedUsers.contains(username);
    final isMuted = _mutedUsers.contains(username);
    final isArchived = _archivedUsers.contains(username);

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
                  leading: Icon(
                    isPinned ? Icons.pin_drop_rounded : Icons.push_pin_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    isPinned ? 'Unpin Chat' : 'Pin Chat',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _togglePin(username);
                  },
                ),
                ListTile(
                  leading: Icon(
                    isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    isMuted ? 'Unmute Chat' : 'Mute Chat',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleMute(username);
                  },
                ),
                ListTile(
                  leading: Icon(
                    isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    isArchived ? 'Unarchive Chat' : 'Archive Chat',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleArchive(username);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppColors.errorRed),
                  title: const Text('Delete Chat', style: TextStyle(color: AppColors.errorRed)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteConversation(username);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteConversation(String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: Text(
            'Delete Chat',
            style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete all messages in this conversation? This action cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await MessageService.deleteConversation(user1: _myUsername, user2: username);
        setState(() {
          _conversationByUser.remove(username);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation with $username deleted'),
            backgroundColor: AppColors.primaryPurple,
          ),
        );
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
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await LocalNotificationService.init();
      } catch (_) {}

      await _loadPrefs();

      final myUsername = await _getUsername();
      if (myUsername.isEmpty) return;

      setState(() {
        _myUsername = myUsername;
      });

      await _connectWebSocket(myUsername);
      await _loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _conversationByUser.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final isChatsTab = _currentTabIndex == 0;

    return Scaffold(
      backgroundColor: AppColors.amoledBlack,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => AppColors.primaryGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: Text(
            isChatsTab ? 'ShadowChat X' : 'My Profile',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GlowPainter(),
            ),
          ),
          IndexedStack(
            index: _currentTabIndex,
            children: [
              // Tab 0: Chats
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Welcome/Greeting header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16, top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _myUsername.isNotEmpty ? _myUsername : 'User',
                                  style: GoogleFonts.montserrat(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _currentTabIndex = 1),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryPurple.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7B2FF7).withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.cardDark,
                                  child: Text(
                                    _myUsername.isNotEmpty ? _myUsername.substring(0, 1).toUpperCase() : 'U',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FloatingSearchBar(
                        controller: _searchController,
                        hintText: 'Search users or chats...',
                        onChanged: _onSearchChanged,
                        onClear: () {
                          setState(() {
                            _foundUsers = const [];
                            _searchError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildCategoryChip('All Messages', 0),
                          const SizedBox(width: 8),
                          _buildCategoryChip('Archived (${_archivedUsers.length})', 1),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: _buildContent(conversations),
                      ),
                    ],
                  ),
                ),
              ),
              // Tab 1: Profile
              ProfileScreen(
                currentUsername: _myUsername,
                onUsernameChanged: _handleUsernameChanged,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardDark.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.glassBorder.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B2FF7).withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chats'),
              _buildNavItem(1, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7B2FF7).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B2FF7).withValues(alpha: 0.4) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? Colors.white : AppColors.textTertiary,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, int index) {
    final isSelected = _selectedCategoryIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7B2FF7).withValues(alpha: 0.15) : AppColors.cardDark.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B2FF7).withValues(alpha: 0.4) : AppColors.glassBorder.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _foundUsers = const [];
        _searchError = null;
      });
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () async {
        if (!mounted) return;
        setState(() {
          _searchLoading = true;
          _searchError = null;
        });

        try {
          final list = await ApiService.searchUsers(username: q);
          if (!mounted) return;
          setState(() {
            _foundUsers = list.cast<Map<String, dynamic>>();
            _searchLoading = false;
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _searchError = e.toString();
            _searchLoading = false;
          });
        }
      },
    );
  }

  Widget _buildContent(List<Conversation> conversations) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? conversations
        : conversations
            .where((c) => c.username.toLowerCase().contains(query))
            .toList();

    // 1. Filter by category
    List<Conversation> categoryFiltered;
    if (_selectedCategoryIndex == 1) {
      categoryFiltered = filtered.where((c) => _archivedUsers.contains(c.username)).toList();
    } else {
      categoryFiltered = filtered.where((c) => !_archivedUsers.contains(c.username)).toList();
    }

    // 2. Sort: Pinned first, then by timestamp descending
    categoryFiltered.sort((a, b) {
      final aPinned = _pinnedUsers.contains(a.username);
      final bPinned = _pinnedUsers.contains(b.username);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return b.timestamp.compareTo(a.timestamp);
    });

    if (_searchLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryPurple,
        ),
      );
    }

    if (_searchError != null && _searchController.text.trim().isNotEmpty) {
      return Center(
        child: Text(
          _searchError!,
          style: TextStyle(color: AppColors.errorRed),
        ),
      );
    }

    if (_searchController.text.trim().isNotEmpty) {
      if (_foundUsers.isEmpty) {
        return Center(
          child: Text(
            'No users found',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
      }

      return ListView.separated(
        itemCount: _foundUsers.length,
        padding: const EdgeInsets.only(bottom: 110),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final u = _foundUsers[index];
          final otherUsername = u['username']?.toString() ?? '';

          if (otherUsername.isEmpty) {
            return const SizedBox.shrink();
          }

          final hasConversation = _conversationByUser.containsKey(otherUsername);
          final conv = hasConversation ? _conversationByUser[otherUsername]! : null;

          return PremiumConversationTile(
            username: otherUsername,
            lastMessage:
                conv?.lastMessage ?? 'Tap to start a conversation',
            unreadCount: conv?.unreadCount ?? 0,
            timestamp: conv?.timestamp,
            isPinned: _pinnedUsers.contains(otherUsername),
            isMuted: _mutedUsers.contains(otherUsername),
            onLongPress: () => _showConversationActions(context, otherUsername),
            onTap: () async {
              await Navigator.of(context).pushNamed(
                '/chat',
                arguments: {'userName': otherUsername},
              );
              _loadConversations();
            },
          );
        },
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryPurple,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: AppColors.errorRed),
        ),
      );
    }

    if (categoryFiltered.isEmpty) {
      return Center(
        child: Text(
          _selectedCategoryIndex == 1 ? 'No archived conversations' : 'No conversations yet',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: categoryFiltered.length,
      padding: const EdgeInsets.only(bottom: 110),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final conv = categoryFiltered[index];
        return PremiumConversationTile(
          username: conv.username,
          lastMessage: conv.lastMessage,
          unreadCount: conv.unreadCount,
          timestamp: conv.timestamp,
          isPinned: _pinnedUsers.contains(conv.username),
          isMuted: _mutedUsers.contains(conv.username),
          onLongPress: () => _showConversationActions(context, conv.username),
          onTap: () async {
            await Navigator.of(context).pushNamed(
              '/chat',
              arguments: {'userName': conv.username},
            );
            _loadConversations();
          },
        );
      },
    );
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = const Color(0xFF7B2FF7).withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    final p2 = Paint()
      ..color = const Color(0xFF3A8DFF).withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.2), 160, p1);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.75), 180, p2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}