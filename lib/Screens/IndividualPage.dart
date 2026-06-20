import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:talk_messenger/Model/ChatModel.dart';
import 'package:talk_messenger/Model/MessageModel.dart';
import 'package:talk_messenger/Screens/VideoCallScreen.dart';
import 'dart:io';

// ─── Dados dos sticker packs ───────────────────────────────────────────────

class _StickerPack {
  final String name;
  final String slug;
  final int count;
  const _StickerPack({required this.name, required this.slug, required this.count});
}

const _stickerPacks = [
  _StickerPack(name: 'Kakao Muzi', slug: 'kakao-muzi-1', count: 24),
  _StickerPack(
      name: 'Xiong Da',
      slug: 'xiong-da-tu-tusha-li-dong-tai-te-bie-pian',
      count: 24),
];

String _stickerUrl(String slug, int n) =>
    'https://s3.getstickerpack.com/storage/uploads/sticker-pack/$slug/sticker_$n.gif';

// ───────────────────────────────────────────────────────────────────────────

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

  // wallpaper
  String? _wallpaperPath;

  // painel emoji/sticker
  bool _showEmojiPanel = false;
  late final TabController _emojiTabController;

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
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _emojiTabController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── Wallpaper ─────────────────────────────────────────────────────────────

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('chat_wallpaper');
    if (mounted) setState(() => _wallpaperPath = path);
  }

  // ── Supabase ──────────────────────────────────────────────────────────────

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
          (data as List).map((m) => MessageModel.fromMap(m)).toList(),
        );
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
            final alreadyExists = _messages.any((m) => m.id == msg.id);
            if (!alreadyExists) {
              setState(() => _messages.add(msg));
              _scrollToBottom();
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Realtime: $status | $error');
        });
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

  // ── Envio ─────────────────────────────────────────────────────────────────

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
        setState(() => _messages.removeWhere((m) => m.id == tempMsg.id));
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
        setState(() => _messages.removeWhere((m) => m.id == tempMsg.id));
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _toggleEmojiPanel() {
    setState(() => _showEmojiPanel = !_showEmojiPanel);
    if (_showEmojiPanel) FocusScope.of(context).unfocus();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final bool hasWallpaper =
        _wallpaperPath != null && File(_wallpaperPath!).existsSync();

    return Scaffold(
      backgroundColor: hasWallpaper ? null : const Color(0xFFECEEF3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A84FF)),
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
                          color: Colors.white, fontWeight: FontWeight.bold),
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
            icon: const Icon(Icons.call, color: Color(0xFF0A84FF)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Color(0xFF0A84FF)),
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
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Wallpaper background ──────────────────────────────────────
          if (hasWallpaper)
            Positioned.fill(
              child: Image.file(
                File(_wallpaperPath!),
                fit: BoxFit.cover,
              ),
            ),

          // ── Conteúdo ──────────────────────────────────────────────────
          Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_showEmojiPanel)
                      setState(() => _showEmojiPanel = false);
                  },
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF0A84FF)))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
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

  // ── Bubble ────────────────────────────────────────────────────────────────

  Widget _buildBubble(MessageModel msg, bool isMine) {
    if (msg.type == MessageType.sticker) {
      return _buildStickerBubble(msg, isMine);
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF0A84FF) : Colors.white,
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
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            CachedNetworkImage(
              imageUrl: msg.mediaUrl ?? '',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const SizedBox(
                width: 140,
                height: 140,
                child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
              ),
              placeholder: (_, __) => const SizedBox(
                width: 140,
                height: 140,
                child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF0A84FF), strokeWidth: 2),
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
                          ? const Color(0xFF0A84FF)
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

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return SafeArea(
      bottom: !_showEmojiPanel,
      child: Container(
        color: const Color(0xFFF0F0F0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                      icon: Icon(
                        _showEmojiPanel
                            ? Icons.keyboard_alt_outlined
                            : Icons.emoji_emotions_outlined,
                        color: _showEmojiPanel
                            ? const Color(0xFF0A84FF)
                            : const Color(0xFF8E8E93),
                        size: 24,
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
                        // CORRIGIDO: cor de texto e cursor fixas em preto,
                        // independente do tema ativo do app.
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                        cursorColor: const Color(0xFF0A84FF),
                        onTap: () {
                          if (_showEmojiPanel) {
                            setState(() => _showEmojiPanel = false);
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: 'Mensagem',
                          hintStyle: TextStyle(color: Color(0xFF8E8E93)),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file,
                          color: Color(0xFF8E8E93), size: 22),
                      onPressed: () {},
                    ),
                    if (!_hasText)
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined,
                            color: Color(0xFF8E8E93), size: 22),
                        onPressed: () {},
                      ),
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
                  color: Color(0xFF0A84FF),
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

  // ── Painel Emoji + Stickers ───────────────────────────────────────────────

  Widget _buildEmojiStickerPanel() {
    return Container(
      height: 280,
      color: Colors.white,
      child: Column(
        children: [
          TabBar(
            controller: _emojiTabController,
            isScrollable: true,
            labelColor: const Color(0xFF0A84FF),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF0A84FF),
            tabs: [
              const Tab(icon: Icon(Icons.emoji_emotions_outlined)),
              ..._stickerPacks.map((p) => Tab(text: p.name)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _emojiTabController,
              children: [
  // Aba de Emojis Manual (Funciona 100%)
  GridView.builder(
    padding: const EdgeInsets.all(8),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 7,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
    ),
    itemCount: 40, // Quantidade de emojis para teste
    itemBuilder: (context, index) {
      // Lista de códigos Unicode básicos
      final emojis = [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
        '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
        '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩',
        '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣'
      ];
      return InkWell(
        onTap: () {
          final text = emojis[index];
          final currentText = _messageController.text;
          _messageController.text = currentText + text;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        },
        child: Center(
          child: Text(
            emojis[index],
            style: const TextStyle(fontSize: 28),
          ),
        ),
      );
    },
  ),
                // Abas de sticker packs — com cache
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
                                  color: Color(0xFF0A84FF)),
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
