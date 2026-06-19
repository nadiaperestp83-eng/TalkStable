import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talk_messenger/Model/ChatModel.dart';
import 'package:talk_messenger/Screens/IndividualPage.dart';
import 'package:talk_messenger/Screens/SelectContact.dart';
import 'package:talk_messenger/Screens/StatusScreen.dart';
import 'package:talk_messenger/Screens/ProfileSetupScreen.dart';
import 'package:talk_messenger/Screens/ChatSettingsScreen.dart';
import 'package:talk_messenger/Screens/ContactsScreen.dart';
import 'package:talk_messenger/Screens/LoginScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class Homescreen extends StatefulWidget {
  const Homescreen({Key? key}) : super(key: key);

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  int _currentIndex = 0;
  List<ChatModel> _conversations = [];
  bool _loading = true;

  // perfil
  String _profileName = '';
  String? _profileAvatarUrl;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _subscribeRealtime();
    _loadUserProfile();
  }

  // ── Carregar conversas ────────────────────────────────────────────────────

  Future<void> _loadConversations() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await supabase
          .from('conversation_members')
          .select('''
            conversation_id,
            unread_count,
            conversations (
              id, name, avatar_url, is_group,
              last_message, last_message_time
            )
          ''')
          .eq('user_id', userId);

      setState(() {
        _conversations = (data as List).map((item) {
          final conv = item['conversations'];
          return ChatModel(
            id: conv['id'],
            name: conv['name'] ?? 'Conversa',
            avatar: conv['avatar_url'],
            isGroup: conv['is_group'] ?? false,
            lastMessage: conv['last_message'] ?? '',
            time: _formatTime(conv['last_message_time']),
            unreadCount: item['unread_count'] ?? 0,
          );
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    Supabase.instance.client
        .channel('conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _loadConversations(),
        )
        .subscribe();
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    final dt = DateTime.tryParse(isoTime)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }

  // ── Perfil ────────────────────────────────────────────────────────────────

  Future<void> _loadUserProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _profileName = data['name'] ?? '';
          _profileAvatarUrl = data['avatar_url'];
        });
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      final file = File(picked.path);
      final ext = picked.path.split('.').last;
      final path = 'avatars/$userId.$ext';

      await supabase.storage.from('avatars').upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = supabase.storage.from('avatars').getPublicUrl(path);

      await supabase.from('users').upsert({
        'id': userId,
        'avatar_url': url,
      }, onConflict: 'id');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_avatar', url);

      if (mounted) {
        setState(() => _profileAvatarUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto atualizada com sucesso!'),
            backgroundColor: Color(0xFF34C759),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar foto: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Sair', style: TextStyle(color: Color(0xFF111111))),
        content: const Text('Deseja encerrar a sessão?',
            style: TextStyle(color: Color(0xFF444444))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await Supabase.instance.client.auth.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ── Deletar conversa ──────────────────────────────────────────────────────

  Future<void> _deleteConversation(ChatModel chat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Excluir conversa',
          style: TextStyle(
              fontWeight: FontWeight.w700, color: Color(0xFF111111)),
        ),
        content: Text(
          'Deseja excluir a conversa com "${chat.name}"?\n\nTodas as mensagens serão apagadas para todos.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF444444)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF0A84FF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('messages')
          .delete()
          .eq('conversation_id', chat.id);
      await supabase
          .from('conversation_members')
          .delete()
          .eq('conversation_id', chat.id);
      await supabase
          .from('conversations')
          .delete()
          .eq('id', chat.id);

      if (mounted) {
        setState(() => _conversations.removeWhere((c) => c.id == chat.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversa excluída.'),
            backgroundColor: Color(0xFF0A84FF),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Menu item helper ──────────────────────────────────────────────────────

  Widget _buildMenuItem({
    required Color iconBg,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? const Color(0xFF111111),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF8E8E93)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ── Chats page ────────────────────────────────────────────────────────────

  Widget _buildChatsPage() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0A84FF)))
          : _conversations.isEmpty
              ? const Center(
                  child: Text('Nenhuma conversa ainda.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final chat = _conversations[index];
                    return _buildChatItem(chat);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SelectContact()),
        ),
        backgroundColor: const Color(0xFF0A84FF),
        shape: const CircleBorder(),
        child: const Icon(Icons.add_comment_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildChatItem(ChatModel chat) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IndividualPage(chatModel: chat),
        ),
      ),
      onLongPress: () => _deleteConversation(chat),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: const Color(0xFFB0BEC5),
              backgroundImage:
                  chat.avatar != null ? NetworkImage(chat.avatar!) : null,
              child: chat.avatar == null
                  ? Text(
                      chat.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111111)),
                      ),
                      Text(
                        chat.time,
                        style: TextStyle(
                            fontSize: 12,
                            color: chat.unreadCount > 0
                                ? const Color(0xFF0A84FF)
                                : Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF8E8E93)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A84FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chat.unreadCount.toString(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 16, thickness: 0.5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile page ──────────────────────────────────────────────────────────

  Widget _buildProfilePage() {
    return ListView(
      children: [
        const SizedBox(height: 24),

        // ── Avatar clicável ──
        Center(
          child: GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: const Color(0xFFB0BEC5),
                  backgroundImage: _profileAvatarUrl != null
                      ? NetworkImage(_profileAvatarUrl!)
                      : null,
                  child: _profileAvatarUrl == null
                      ? Text(
                          _profileName.isNotEmpty
                              ? _profileName[0].toUpperCase()
                              : 'T',
                          style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                // Overlay de loading
                if (_uploadingAvatar)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                // Ícone câmera
                if (!_uploadingAvatar)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0A84FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
        Center(
          child: Text(
            'Toque para alterar foto',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _profileName,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 28),

        // ── Menu items ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildMenuItem(
                iconBg: const Color(0xFF0A84FF),
                icon: Icons.person_outline,
                title: 'Conta',
                subtitle: 'Número, Nome de Usuário, Bio',
                onTap: () {},
              ),
              const Divider(height: 1, indent: 74),
              _buildMenuItem(
                iconBg: const Color(0xFFFF9500),
                icon: Icons.chat_bubble_outline,
                title: 'Configurações de Chat',
                subtitle: 'Papel de Parede, Modo Noturno, Animações',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatSettingsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 74),
              _buildMenuItem(
                iconBg: const Color(0xFF34C759),
                icon: Icons.key_outlined,
                title: 'Privacidade e Segurança',
                subtitle: 'Visto por Último, Dispositivos, Chaves de Acesso',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 74),
              _buildMenuItem(
                iconBg: const Color(0xFFFF3B30),
                icon: Icons.notifications_outlined,
                title: 'Notificações',
                subtitle: 'Sons, Chamadas, Contadores',
                onTap: () {},
              ),
              const Divider(height: 1, indent: 74),
              _buildMenuItem(
                iconBg: const Color(0xFF5856D6),
                icon: Icons.language,
                title: 'Idioma',
                subtitle: 'Português (Brasil)',
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildMenuItem(
            iconBg: const Color(0xFFFF3B30),
            icon: Icons.logout_rounded,
            title: 'Sair',
            subtitle: 'Encerrar sessão',
            titleColor: Colors.red,
            onTap: _signOut,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildChatsPage(),
      // CORRIGIDO: fundo branco fixo, não herda mais o tema AMOLED (preto)
      const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Calls em breve',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
          ),
        ),
      ),
      const ContactsScreen(),
      const StatusScreen(),
      _buildProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF4DA6FF), Color(0xFF0A84FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Text(
                  'T',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Talk',
              style: TextStyle(
                  color: Color(0xFF0A84FF),
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F8F8),
          border: Border(
              top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            // recarrega perfil ao entrar na aba
            if (i == 4) _loadUserProfile();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF0A84FF),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'Chats'),
            BottomNavigationBarItem(
                icon: Icon(Icons.call_outlined),
                activeIcon: Icon(Icons.call),
                label: 'Calls'),
            BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: 'Contatos'),
            BottomNavigationBarItem(
                icon: Icon(Icons.circle_outlined),
                activeIcon: Icon(Icons.circle),
                label: 'Status'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}
