// In-app chat: conversations list + chat thread (customer ↔ provider).
// Conversations are tied to a booking. Live updates come from Supabase
// Realtime on the messages table (migration 003 adds it to the publication).
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';
import '../repository.dart';
import '../theme.dart';
import '../l10n/strings.dart';

String _timeLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final time =
      '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  if (day == today) return time;
  if (day == today.subtract(const Duration(days: 1))) return tr('chat_yesterday');
  return '${dt.day}/${dt.month}/${dt.year}';
}

// ---------------- Conversations list (Messages tab) ----------------

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});
  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Future<List<Conversation>> _convs;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _convs = fetchMyConversations();
    // Live badge: the list used to fetch once and then go stale — a
    // message read from a booking's Chat button, a mark-read that
    // lands after the list's refresh, or a new incoming message left
    // the unread badge wrong (seen 20 Nov 2026: badge stayed 1 after
    // the "Cash received: Rs. 1200" message was read, because the list
    // had been fetched before the mark-read landed). Any insert or
    // update on messages re-fetches the list.
    _channel = db.channel('my-conversations');
    for (final event in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update,
    ]) {
      _channel!.onPostgresChanges(
        event: event,
        schema: 'public',
        table: 'messages',
        callback: (_) => _refresh(),
      );
    }
    _channel!.subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      db.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final fresh = fetchMyConversations();
    if (mounted) setState(() => _convs = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('messages'))),
      body: FutureBuilder<List<Conversation>>(
        future: _convs,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(trf('chat_loadError', {'error': snap.error.toString()}),
                    textAlign: TextAlign.center),
              ),
            );
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 56, color: AppColors.inkSoft),
                    const SizedBox(height: 16),
                    Text(tr('chat_noChats'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      tr('chat_noChatsHint'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final c = list[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.tealLight,
                      child: Text(
                        c.otherPartyName.isNotEmpty
                            ? c.otherPartyName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(c.otherPartyName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (c.lastMessageAt != null)
                          Text(_timeLabel(c.lastMessageAt!),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.inkSoft)),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.serviceName,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.inkSoft)),
                        if (c.lastMessageText != null)
                          Text(c.lastMessageText!,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: c.unreadCount > 0
                        ? CircleAvatar(
                            radius: 11,
                            backgroundColor: AppColors.teal,
                            child: Text('${c.unreadCount}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white)),
                          )
                        : const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(conversation: c),
                      ));
                      if (mounted) _refresh();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------- Chat thread ----------------

class ChatDetailScreen extends StatefulWidget {
  final Conversation conversation;
  const ChatDetailScreen({super.key, required this.conversation});
  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  RealtimeChannel? _channel;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = db.auth.currentUser?.id;
    _load();
    _channel = subscribeToConversationMessages(
      widget.conversation.id,
      _onRealtimeMessage,
    );
  }

  @override
  void dispose() {
    if (_channel != null) {
      db.removeChannel(_channel!);
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final msgs = await fetchMessages(widget.conversation.id);
      await markMessagesRead(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = trf('chat_loadMessagesError', {'error': e.toString()});
        _loading = false;
      });
    }
  }

  void _onRealtimeMessage(ChatMessage msg) {
    if (!mounted) return;
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages = [..._messages, msg]);
    if (msg.senderId != _myId) {
      markMessagesRead(widget.conversation.id);
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await sendMessage(widget.conversation.id, text);
      _input.clear();
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (!_messages.any((m) => m.id == msg.id)) {
          _messages = [..._messages, msg];
        }
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trf('chat_sendError', {'error': e.toString()}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.otherPartyName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(c.serviceName,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Transparency note: chats may be reviewed by the admin.
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.tealLight,
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 16, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('chatAdminNote'),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                tr('chat_noMessages'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.inkSoft),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, i) {
                              final m = _messages[i];
                              final mine = m.senderId == _myId;
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.75,
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? AppColors.teal
                                        : AppColors.tealLight,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: mine
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.messageText ?? '',
                                        style: TextStyle(
                                          color: mine
                                              ? Colors.white
                                              : AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _timeLabel(m.createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: mine
                                              ? Colors.white70
                                              : AppColors.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: tr('chat_typeMessage'),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: AppColors.teal),
                    onPressed: _send,
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
