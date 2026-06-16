import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talk_messenger/Model/ChatModel.dart';
import 'package:talk_messenger/Model/MessageModel.dart';

class IndividualPage extends StatefulWidget {
  final ChatModel chatModel;
  const IndividualPage({Key? key, required this.chatModel}) : super(key: key);

  @override
  State<IndividualPage> createState() => _IndividualPageState();
}

class _IndividualPageState extends State<IndividualPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  bool _loading = true;
  bool _hasText = false;
  
  // Variável para manter a referência da inscrição e cancelar no dispose
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      if (mounted) {
        setState(() => _hasText = _messageController.text.trim().isNotEmpty);
      }
    });
    _loadMessages();
    _subscribeMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Cancela a inscrição para evitar memória vazando e erros de callback
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('conversation_id', widget.chatModel.id)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(
            (data as List).map((m) => MessageModel.fromMap(m)).toList(),
          );
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Erro ao carregar mensagens: $e');
    }
  }

  void _subscribeMessages() {
    // Usando string de filtro para garantir compatibilidade total de build
    _messagesChannel = Supabase.instance.client
        .channel('messages:${widget.chatModel.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: 'conversation_id=eq.${widget.chatModel.id}',
          callback: (payload) {
            if (mounted) {
              final msg = MessageModel.fromMap(payload.newRecord);
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _hasText = false);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.chatModel.id,
        'sender_id': userId,
        'content': text,
        'type': 'text',
        'status': 'sent',
      });
    } catch (e) {
      debugPrint('Erro ao enviar: $e');
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFECEEF3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
                  ? NetworkImage(widget.chatModel.avatar!)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatModel.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
                  ),
                  Text(
                    widget.chatModel.isOnline ? 'online' : 'offline',
                    style: TextStyle(fontSize: 12, color: widget.chatModel.isOnline ? const Color(0xFF34C759) : Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0A84FF)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMine = msg.senderId == userId;
                      return _buildBubble(msg, isMine);
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(MessageModel msg, bool isMine) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF0A84FF) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(msg.content, style: TextStyle(fontSize: 15, color: isMine ? Colors.white : const Color(0xFF111111))),
            const SizedBox(height: 4),
            Text(_formatTime(msg.createdAt), style: TextStyle(fontSize: 11, color: isMine ? Colors.white.withOpacity(0.7) : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(hintText: 'Mensagem...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16)),
              ),
            ),
            IconButton(
              icon: Icon(_hasText ? Icons.send : Icons.mic, color: const Color(0xFF0A84FF)),
              onPressed: _hasText ? _sendMessage : null,
            ),
          ],
        ),
      ),
    );
  }
}
