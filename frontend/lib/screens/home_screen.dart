import 'dart:async';

import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';
import '../services/conversation_service.dart';
import '../services/home_conversation_ws_service.dart';

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

  StreamSubscription<Conversation>? _wsSub;
  HomeConversationWebSocket? _homeWs;

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

  @override
  void initState() {
    super.initState();

    // Load conversations and start websocket updates.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final myUsername = await _getUsername();
      if (myUsername.isEmpty) return;

      _homeWs = HomeConversationWebSocket(myUsername: myUsername);
      await _homeWs!.connect();

      _wsSub = _homeWs!.allConversationUpdates.listen((conv) {
        // Update both sender+receiver side: UI uses the same `other` mapping.
        // Replace entry + bubble it to top by sorting.
        if (!mounted) return;

        setState(() {
          _conversationByUser[conv.username] = conv;
        });
      });

      await _loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _conversationByUser.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? conversations
        : conversations
              .where((c) => c.username.toLowerCase().contains(query))
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShadowChat X'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search chats',
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) {
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
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _searchLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (_searchError != null &&
                          _searchController.text.trim().isNotEmpty)
                    ? Center(
                        child: Text(
                          _searchError!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : (_searchController.text.trim().isNotEmpty)
                    ? _foundUsers.isEmpty
                          ? const Center(child: Text('No users found'))
                          : ListView.separated(
                              itemCount: _foundUsers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final u = _foundUsers[index];
                                final otherUsername =
                                    u['username']?.toString() ?? '';

                                if (otherUsername.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                // Only show users (real users from MongoDB), not dummy entries.
                                return Card(
                                  color: const Color(0xFF121212),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      otherUsername,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _conversationByUser.containsKey(
                                            otherUsername,
                                          )
                                          ? _conversationByUser[otherUsername]!
                                                .lastMessage
                                          : 'Tap to chat',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    trailing:
                                        _conversationByUser.containsKey(
                                              otherUsername,
                                            ) &&
                                            _conversationByUser[otherUsername]!
                                                    .unreadCount >
                                                0
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              '${_conversationByUser[otherUsername]!.unreadCount}',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          )
                                        : null,
                                    onTap: () {
                                      Navigator.of(context).pushNamed(
                                        '/chat',
                                        arguments: {'userName': otherUsername},
                                      );
                                    },
                                  ),
                                );
                              },
                            )
                    : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : filtered.isEmpty
                    ? const Center(child: Text('No conversations yet'))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final conv = filtered[index];
                          final time = conv.timestamp.toLocal();
                          final timeStr =
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

                          return Card(
                            color: const Color(0xFF121212),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              title: Text(
                                conv.username,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                conv.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (conv.unreadCount > 0)
                                    Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '${conv.unreadCount}',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  '/chat',
                                  arguments: {'userName': conv.username},
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
