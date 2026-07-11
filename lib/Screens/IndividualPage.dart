import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:talk_messenger/Model/ChatModel.dart';
import 'package:talk_messenger/Model/MessageModel.dart';
import 'package:talk_messenger/Screens/VideoCallScreen.dart';
import 'dart:io';
import 'dart:async';

// ─── Cores do tema (Verde LINE) ────────────────────────────────────────────
class _TalkColors {
  static const Color gradientStart = Color(0xFF06C755);
  static const Color gradientEnd = Color(0xFF06C755);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Tons escuros usados nos fundos da UI de "mensagem secreta"
  // (antes em roxo escuro — agora em verde escuro, mantendo o clima "dark").
  static const Color secretBubbleMine = Color(0xFF0F3D2E);
  static const Color secretDark = Color(0xFF0A2A20);
}

const String _defaultWallpaperAsset = 'assets/images/default_wallpaper.jpg';

// ─── Modelo de mensagem secreta local ─────────────────────────────────────
class _SecretMessage {
  final String id;
  final String senderId;
  final String content;
  final int ttlSeconds;
  final DateTime createdAt;
  DateTime? openedAt;
  int? secondsLeft;

  _SecretMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.ttlSeconds,
    required this.createdAt,
    this.openedAt,
    this.secondsLeft,
  });

  bool get isOpened => openedAt != null;
  bool get isMine =>
      senderId == Supabase.instance.client.auth.currentUser?.id;
}

// ─── Sticker packs ────────────────────────────────────────────────────────
class _StickerPack {
  final String name;
  final String slug;
  final int count;
  const _StickerPack({
    required this.name,
    required this.slug,
    required this.count,
  });
}

const _stickerPacks = [
  _StickerPack(name: 'Kakao Muzi', slug: 'kakao-muzi-1', count: 24),
  _StickerPack(
    name: 'Xiong Da',
    slug: 'xiong-da-tu-tusha-li-dong-tai-te-bie-pian',
    count: 24,
  ),
];

String _stickerUrl(String slug, int n) =>
    'https://s3.getstickerpack.com/storage/uploads/sticker-pack/$slug/sticker_$n.gif';

// ──────────────────────────────────────────────────────────────────────────

class IndividualPage extends StatefulWidget {
  final ChatModel chatModel;
  const IndividualPage({Key? key, required this.chatModel}) : super(key: key);

  @override
  State<IndividualPage> createState() => _IndividualPageState();
}

class _IndividualPageState extends State<IndividualPage>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  bool _loading = true;
  bool _hasText = false;
  RealtimeChannel? _channel;
  RealtimeChannel? _secretChannel;

  String? _wallpaperPath;
  bool _showEmojiPanel = false;
  late final TabController _emojiTabController;

  // ── Mensagens secretas ────────────────────────────────────────────────
  final List<_SecretMessage> _secretMessages = [];
  final Map<String, Timer> _countdownTimers = {};

  @override
  void initState() {
    super.initState();
    _emojiTabController =
        TabController(length: 1 + _stickerPacks.length, vsync: this);
    _messageController.addListener(() {
      setState(() => _hasText = _messageController.text.trim().isNotEmpty);
    });
    _loadWallpaper();
    _loadMessages();
    _subscribeMessages();
    _loadSecretMessages();
    _subscribeSecretMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _emojiTabController.dispose();
    _channel?.unsubscribe();
    _secretChannel?.unsubscribe();
    for (final t in _countdownTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  // ── Wallpaper ─────────────────────────────────────────────────────────
  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('chat_wallpaper');
    if (mounted) setState(() => _wallpaperPath = path);
  }

  // ── Mensagens normais ─────────────────────────────────────────────────
  Future<void> _loadMessages() async {
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('conversation_id', widget.chatModel.id)
          .order('created_at', ascending: true);

      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(
            (data as List).map((m) => MessageModel.fromMap(m)));
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeMessages() {
    _channel = Supabase.instance.client
        .channel('room-${widget.chatModel.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            if (!mounted) return;
            final record = payload.newRecord;
            final convId = record['conversation_id']?.toString();
            if (convId != widget.chatModel.id.toString()) return;
            final msg = MessageModel.fromMap(record);
            if (!_messages.any((m) => m.id == msg.id)) {
              setState(() => _messages.add(msg));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Mensagens secretas: carregar ──────────────────────────────────────
  Future<void> _loadSecretMessages() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final data = await Supabase.instance.client
          .from('secret_messages')
          .select()
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: true);

      if (!mounted) return;

      for (final row in (data as List)) {
        final sm = _secretMessageFromRow(row);
        if (sm == null) continue;
        if (sm.isOpened) {
          final exp =
              sm.openedAt!.add(Duration(seconds: sm.ttlSeconds));
          if (DateTime.now().isAfter(exp)) continue;
        }
        _secretMessages.add(sm);
        if (sm.isOpened) _startCountdown(sm);
      }

      if (mounted) setState(() {});
      _scrollToBottom();
    } catch (e) {
      debugPrint('Erro ao carregar mensagens secretas: $e');
    }
  }

  // ── Mensagens secretas: realtime ──────────────────────────────────────
  void _subscribeSecretMessages() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _secretChannel = Supabase.instance.client
        .channel('secret-${widget.chatModel.id}-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'secret_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final sm = _secretMessageFromRow(payload.newRecord);
            if (sm == null) return;
            if (!_secretMessages.any((s) => s.id == sm.id)) {
              setState(() => _secretMessages.add(sm));
              _scrollToBottom();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'secret_messages',
          callback: (payload) {
            if (!mounted) return;
            final row = payload.newRecord;
            final id = row['id']?.toString();
            if (id == null) return;
            final idx = _secretMessages.indexWhere((s) => s.id == id);
            if (idx == -1) return;
            final sm = _secretMessages[idx];
            if (!sm.isOpened && row['opened_at'] != null) {
              sm.openedAt = DateTime.parse(row['opened_at']);
              _startCountdown(sm);
              if (mounted) setState(() {});
            }
          },
        )
        .subscribe();
  }

  _SecretMessage? _secretMessageFromRow(Map<String, dynamic> row) {
    try {
      return _SecretMessage(
        id: row['id'],
        senderId: row['sender_id'],
        content: row['encrypted_content'] ?? '',
        ttlSeconds: row['ttl_seconds'] ?? 30,
        createdAt: DateTime.parse(row['created_at']),
        openedAt: row['opened_at'] != null
            ? DateTime.parse(row['opened_at'])
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Countdown local ───────────────────────────────────────────────────
  void _startCountdown(_SecretMessage sm) {
    _countdownTimers[sm.id]?.cancel();
    final exp = sm.openedAt!.add(Duration(seconds: sm.ttlSeconds));
    final remaining = exp.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      _destroySecret(sm.id);
      return;
    }
    sm.secondsLeft = remaining;
    _countdownTimers[sm.id] = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final left = exp.difference(DateTime.now()).inSeconds;
        if (left <= 0) {
          timer.cancel();
          _destroySecret(sm.id);
        } else {
          setState(() => sm.secondsLeft = left);
        }
      },
    );
  }

  void _destroySecret(String id) {
    _countdownTimers[id]?.cancel();
    _countdownTimers.remove(id);
    if (mounted) {
      setState(() => _secretMessages.removeWhere((s) => s.id == id));
    }
    Supabase.instance.client
        .from('secret_messages')
        .delete()
        .eq('id', id)
        .then((_) => debugPrint('Mensagem secreta $id destruída'))
        .catchError((e) => debugPrint('Erro ao destruir: $e'));
  }

  // ── Abrir mensagem secreta ────────────────────────────────────────────
  Future<void> _openSecret(_SecretMessage sm) async {
    if (sm.isOpened) {
      _showSecretContent(sm);
      return;
    }
    if (sm.isMine) {
      _showSecretContent(sm);
      return;
    }
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await Supabase.instance.client
          .from('secret_messages')
          .update({'opened_at': now}).eq('id', sm.id);
      sm.openedAt = DateTime.now();
      _startCountdown(sm);
      if (mounted) setState(() {});
      _showSecretContent(sm);
    } catch (e) {
      debugPrint('Erro ao abrir mensagem secreta: $e');
    }
  }

  void _showSecretContent(_SecretMessage sm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SecretContentDialog(
        message: sm,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  // ── Enviar mensagem secreta ───────────────────────────────────────────
  Future<void> _sendSecretMessage(String content, int ttlSeconds) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Usa contactId se disponível, senão tenta derivar do chatModel
    final receiverId = widget.chatModel.contactId ?? widget.chatModel.id;

    try {
      final inserted = await Supabase.instance.client
          .from('secret_messages')
          .insert({
            'sender_id': userId,
            'receiver_id': receiverId,
            'encrypted_content': content,
            'ttl_seconds': ttlSeconds,
          })
          .select()
          .single();

      final sm = _secretMessageFromRow(inserted);
      if (sm != null && mounted) {
        setState(() => _secretMessages.add(sm));
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Erro ao enviar mensagem secreta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao enviar mensagem secreta'),
            backgroundColor: _TalkColors.gradientEnd,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ── Modal compositor ──────────────────────────────────────────────────
  void _showSecretMessageModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SecretMessageComposer(
        onSend: (content, ttl) {
          Navigator.pop(context);
          _sendSecretMessage(content, ttl);
        },
      ),
    );
  }

  // ── Envio mensagem normal ─────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _hasText = false);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final tempMsg = MessageModel(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.chatModel.id,
      senderId: userId,
      content: text,
      type: MessageType.text,
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
    );
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    try {
      final inserted = await Supabase.instance.client
          .from('messages')
          .insert({
            'conversation_id': widget.chatModel.id,
            'sender_id': userId,
            'content': text,
            'type': 'text',
            'status': 'sent',
          })
          .select()
          .single();

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == tempMsg.id);
          if (idx != -1) _messages[idx] = MessageModel.fromMap(inserted);
        });
      }

      await Supabase.instance.client.from('conversations').update({
        'last_message': text,
        'last_message_time': DateTime.now().toIso8601String(),
      }).eq('id', widget.chatModel.id);
    } catch (e) {
      debugPrint('Erro ao enviar: $e');
      if (mounted) {
        setState(
            () => _messages.removeWhere((m) => m.id == tempMsg.id));
      }
    }
  }

  Future<void> _sendSticker(String url) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _showEmojiPanel = false);

    final tempMsg = MessageModel(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.chatModel.id,
      senderId: userId,
      content: '',
      type: MessageType.sticker,
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
      mediaUrl: url,
    );
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    try {
      final inserted = await Supabase.instance.client
          .from('messages')
          .insert({
            'conversation_id': widget.chatModel.id,
            'sender_id': userId,
            'content': '',
            'type': 'sticker',
            'status': 'sent',
            'media_url': url,
          })
          .select()
          .single();

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == tempMsg.id);
          if (idx != -1) _messages[idx] = MessageModel.fromMap(inserted);
        });
      }

      await Supabase.instance.client.from('conversations').update({
        'last_message': '🖼️ Sticker',
        'last_message_time': DateTime.now().toIso8601String(),
      }).eq('id', widget.chatModel.id);
    } catch (e) {
      debugPrint('Erro ao enviar sticker: $e');
      if (mounted) {
        setState(
            () => _messages.removeWhere((m) => m.id == tempMsg.id));
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _toggleEmojiPanel() {
    setState(() => _showEmojiPanel = !_showEmojiPanel);
    if (_showEmojiPanel) FocusScope.of(context).unfocus();
  }

  // ── Timeline mesclada ─────────────────────────────────────────────────
  List<dynamic> get _mergedTimeline {
    final all = <dynamic>[..._messages, ..._secretMessages];
    all.sort((a, b) {
      final DateTime ta = a is MessageModel
          ? a.createdAt
          : (a as _SecretMessage).createdAt;
      final DateTime tb = b is MessageModel
          ? b.createdAt
          : (b as _SecretMessage).createdAt;
      return ta.compareTo(tb);
    });
    return all;
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final bool hasCustomWallpaper =
        _wallpaperPath != null && File(_wallpaperPath!).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFFECEEF3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: _TalkColors.gradientEnd),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF90CAF9),
              backgroundImage: widget.chatModel.avatar != null
                  ? CachedNetworkImageProvider(widget.chatModel.avatar!)
                  : null,
              child: widget.chatModel.avatar == null
                  ? Text(
                      widget.chatModel.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatModel.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111)),
                  ),
                  Text(
                    widget.chatModel.isOnline ? 'online' : 'offline',
                    style: TextStyle(
                        fontSize: 12,
                        color: widget.chatModel.isOnline
                            ? const Color(0xFF34C759)
                            : Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.call, color: _TalkColors.gradientEnd),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam,
                color: _TalkColors.gradientEnd),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoCallScreen(
                    channelName: widget.chatModel.id,
                    calleeName: widget.chatModel.name,
                    calleeAvatar: widget.chatModel.avatar,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            onPressed: _showChatMenu,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: hasCustomWallpaper
                ? Image.file(File(_wallpaperPath!), fit: BoxFit.cover)
                : Image.asset(_defaultWallpaperAsset,
                    fit: BoxFit.cover),
          ),
          Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_showEmojiPanel) {
                      setState(() => _showEmojiPanel = false);
                    }
                  },
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: _TalkColors.gradientEnd))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: _mergedTimeline.length,
                          itemBuilder: (context, index) {
                            final item = _mergedTimeline[index];
                            if (item is _SecretMessage) {
                              return _buildSecretBubble(item);
                            }
                            final msg = item as MessageModel;
                            final isMine = msg.senderId == userId;
                            return _buildBubble(msg, isMine);
                          },
                        ),
                ),
              ),
              _buildInputBar(),
              if (_showEmojiPanel) _buildEmojiStickerPanel(),
            ],
          ),
        ],
      ),
    );
  }

  // ── Menu chat ─────────────────────────────────────────────────────────
  void _showChatMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: _TalkColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    color: Colors.white, size: 20),
              ),
              title: const Text('Mensagem secreta',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Autodestrói após ser lida'),
              onTap: () {
                Navigator.pop(context);
                _showSecretMessageModal();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Bubble secreta ────────────────────────────────────────────────────
  Widget _buildSecretBubble(_SecretMessage sm) {
    final isMine = sm.isMine;

    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _openSecret(sm),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMine
                ? _TalkColors.secretBubbleMine
                : _TalkColors.secretDark,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            border: Border.all(
              color: _TalkColors.gradientStart.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _TalkColors.gradientEnd.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock,
                      color: _TalkColors.gradientStart, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    isMine ? 'Você enviou' : 'Mensagem secreta',
                    style: const TextStyle(
                      color: _TalkColors.gradientStart,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!sm.isOpened && !isMine)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app,
                        color: Colors.white70, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Toque para revelar',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                )
              else if (!sm.isOpened && isMine)
                const Text(
                  'Aguardando leitura...',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                )
              else ...[
                Text(
                  sm.content,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 6),
                _buildCountdownBadge(sm),
              ],
              const SizedBox(height: 4),
              Text(
                _formatTime(sm.createdAt),
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownBadge(_SecretMessage sm) {
    final left = sm.secondsLeft ?? 0;
    final pct = (left / sm.ttlSeconds).clamp(0.0, 1.0);
    final color = left <= 5
        ? Colors.redAccent
        : left <= 15
            ? Colors.orangeAccent
            : _TalkColors.gradientStart;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            value: pct,
            strokeWidth: 2.5,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${left}s',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'para destruir',
          style:
              TextStyle(color: color.withOpacity(0.7), fontSize: 11),
        ),
      ],
    );
  }

  // ── Bubbles normais ───────────────────────────────────────────────────
  Widget _buildBubble(MessageModel msg, bool isMine) {
    if (msg.type == MessageType.sticker) {
      return _buildStickerBubble(msg, isMine);
    }

    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMine ? _TalkColors.brandGradient : null,
          color: isMine ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                fontSize: 15,
                color: isMine ? Colors.white : const Color(0xFF111111),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMine
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: msg.status == MessageStatus.read
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerBubble(MessageModel msg, bool isMine) {
    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            CachedNetworkImage(
              imageUrl: msg.mediaUrl ?? '',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const SizedBox(
                width: 140,
                height: 140,
                child: Icon(Icons.broken_image,
                    color: Colors.grey, size: 40),
              ),
              placeholder: (_, __) => const SizedBox(
                width: 140,
                height: 140,
                child: Center(
                  child: CircularProgressIndicator(
                      color: _TalkColors.gradientEnd, strokeWidth: 2),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: isMine ? 0 : 4, right: isMine ? 4 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all,
                      size: 14,
                      color: msg.status == MessageStatus.read
                          ? _TalkColors.gradientEnd
                          : Colors.grey,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return SafeArea(
      bottom: !_showEmojiPanel,
      child: Container(
        color: const Color(0xFFF0F0F0),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 46),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      padding: const EdgeInsets.only(left: 6, right: 2),
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                      icon: Icon(
                        _showEmojiPanel
                            ? Icons.keyboard_alt_outlined
                            : Icons.emoji_emotions_outlined,
                        color: _showEmojiPanel
                            ? _TalkColors.gradientEnd
                            : const Color(0xFF8E8E93),
                        size: 22,
                      ),
                      onPressed: _toggleEmojiPanel,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black),
                        cursorColor: _TalkColors.gradientEnd,
                        onTap: () {
                          if (_showEmojiPanel) {
                            setState(() => _showEmojiPanel = false);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Mensagem',
                          hintStyle: const TextStyle(
                              color: Color(0xFF8E8E93)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: Color(0xFFD8D8DC),
                              width: 1.2,
                            ),
                          ),
                          disabledBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 2),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 28, minHeight: 28),
                      icon: const Icon(Icons.attach_file,
                          color: Color(0xFF8E8E93), size: 20),
                      onPressed: () {},
                    ),
                    if (!_hasText)
                      IconButton(
                        padding: const EdgeInsets.only(right: 6),
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.camera_alt_outlined,
                            color: Color(0xFF8E8E93), size: 20),
                        onPressed: () {},
                      )
                    else
                      const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _hasText ? _sendMessage : null,
              child: Container(
                height: 46,
                width: 46,
                decoration: const BoxDecoration(
                  gradient: _TalkColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _hasText ? Icons.send_rounded : Icons.mic,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Painel Emoji + Stickers ───────────────────────────────────────────
  Widget _buildEmojiStickerPanel() {
    return Container(
      height: 280,
      color: Colors.white,
      child: Column(
        children: [
          TabBar(
            controller: _emojiTabController,
            isScrollable: true,
            labelColor: _TalkColors.gradientEnd,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _TalkColors.gradientEnd,
            tabs: [
              const Tab(icon: Icon(Icons.emoji_emotions_outlined)),
              ..._stickerPacks.map((p) => Tab(text: p.name)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _emojiTabController,
              children: [
                GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: 40,
                  itemBuilder: (context, index) {
                    final emojis = [
                      '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇',
                      '🙂','🙃','😉','😌','😍','🥰','😘','😗','😙','😚',
                      '😋','😛','😝','😜','🤪','🤨','🧐','🤓','😎','🤩',
                      '🥳','😏','😒','😞','😔','😟','😕','🙁','☹️','😣',
                    ];
                    return InkWell(
                      onTap: () {
                        _messageController.text += emojis[index];
                        _messageController.selection =
                            TextSelection.fromPosition(TextPosition(
                                offset: _messageController.text.length));
                      },
                      child: Center(
                        child: Text(emojis[index],
                            style: const TextStyle(fontSize: 28)),
                      ),
                    );
                  },
                ),
                ..._stickerPacks.map(
                  (pack) => GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: pack.count,
                    itemBuilder: (context, i) {
                      final url = _stickerUrl(pack.slug, i + 1);
                      return GestureDetector(
                        onTap: () => _sendSticker(url),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              color: Colors.grey),
                          placeholder: (_, __) => const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _TalkColors.gradientEnd),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog: conteúdo secreto
// ══════════════════════════════════════════════════════════════════════════════

class _SecretContentDialog extends StatefulWidget {
  final _SecretMessage message;
  final VoidCallback onClose;

  const _SecretContentDialog({
    required this.message,
    required this.onClose,
  });

  @override
  State<_SecretContentDialog> createState() =>
      _SecretContentDialogState();
}

class _SecretContentDialogState extends State<_SecretContentDialog> {
  late int _left;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _left = widget.message.secondsLeft ?? widget.message.ttlSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        _timer?.cancel();
        widget.onClose();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct =
        (_left / widget.message.ttlSeconds).clamp(0.0, 1.0);
    final color = _left <= 5
        ? Colors.redAccent
        : _left <= 15
            ? Colors.orangeAccent
            : _TalkColors.gradientStart;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _TalkColors.secretDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _TalkColors.gradientStart.withOpacity(0.4),
              width: 1),
          boxShadow: [
            BoxShadow(
              color: _TalkColors.gradientEnd.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_open,
                color: _TalkColors.gradientStart, size: 32),
            const SizedBox(height: 12),
            const Text(
              'Mensagem Secreta',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              widget.message.content,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Destruindo em ${_left}s',
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: widget.onClose,
              child: const Text('Fechar',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BottomSheet: compositor de mensagem secreta
// ══════════════════════════════════════════════════════════════════════════════

class _SecretMessageComposer extends StatefulWidget {
  final void Function(String content, int ttl) onSend;
  const _SecretMessageComposer({required this.onSend});

  @override
  State<_SecretMessageComposer> createState() =>
      _SecretMessageComposerState();
}

class _SecretMessageComposerState
    extends State<_SecretMessageComposer> {
  final _controller = TextEditingController();
  int _selectedTtl = 30;
  final _ttlOptions = const [5, 10, 30, 60];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: _TalkColors.secretDark,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.lock,
                  color: _TalkColors.gradientStart, size: 20),
              SizedBox(width: 8),
              Text(
                'Mensagem Secreta',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Será destruída automaticamente após leitura',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            maxLines: 4,
            minLines: 2,
            autofocus: true,
            style:
                const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: _TalkColors.gradientStart,
            decoration: InputDecoration(
              hintText: 'Digite sua mensagem secreta...',
              hintStyle:
                  const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: _TalkColors.gradientStart, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Destruir após',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: _ttlOptions.map((ttl) {
              final selected = ttl == _selectedTtl;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTtl = ttl),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? _TalkColors.brandGradient
                          : null,
                      color: selected
                          ? null
                          : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${ttl}s',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : Colors.white60,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _TalkColors.brandGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.isEmpty) return;
                  widget.onSend(text, _selectedTtl);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.lock,
                    color: Colors.white, size: 18),
                label: const Text(
                  'Enviar mensagem secreta',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
