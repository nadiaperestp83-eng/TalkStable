import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:talk_messenger/Model/ChatModel.dart';
import 'package:talk_messenger/Screens/IndividualPage.dart';
import 'package:talk_messenger/Screens/SelectContact.dart';
import 'package:talk_messenger/Screens/StatusScreen.dart';
import 'package:talk_messenger/Screens/ProfileSetupScreen.dart';
import 'package:talk_messenger/Screens/ChatSettingsScreen.dart';
import 'package:talk_messenger/Screens/ContactsScreen.dart';
import 'package:talk_messenger/Screens/LoginScreen.dart';
import 'package:talk_messenger/Screens/StoryViewScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// ─── Cores ────────────────────────────────────────────────────────────
class _TalkColors {
  static const Color gradientStart = Color(0xFF8A5CF5);
  static const Color gradientEnd = Color(0xFF6539E8);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Modelo de story para o bar ───────────────────────────────────────
class _StoryItem {
  final String id;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String mediaUrl;
  final String mediaType;
  final DateTime createdAt;
  final DateTime expiresAt;

  _StoryItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.expiresAt,
  });

  factory _StoryItem.fromMap(Map<String, dynamic> m) {
    final user = m['users'] as Map<String, dynamic>? ?? {};
    return _StoryItem(
      id: m['id'] ?? '',
      userId: m['user_id'] ?? '',
      userName: m['user_name'] ?? user['name'] ?? 'Usuário',
      avatarUrl: user['avatar_url'],
      mediaUrl: m['media_url'] ?? '',
      mediaType: m['media_type'] ?? 'image',
      createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(m['expires_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// ─── Keep-alive wrapper ───────────────────────────────────────────────
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({Key? key, required this.child}) : super(key: key);

  @override
  _KeepAliveWrapperState createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ─── Story Bar ────────────────────────────────────────────────────────
class _StoryBar extends StatelessWidget {
  final List<_StoryItem> stories;
  final String currentUserId;
  final VoidCallback onAddStory;
  final void Function(List<Map<String, dynamic>>, int) onViewStory;

  const _StoryBar({
    required this.stories,
    required this.currentUserId,
    required this.onAddStory,
    required this.onViewStory,
  });

  @override
  Widget build(BuildContext context) {
    // Agrupa stories por usuário
    final Map<String, List<_StoryItem>> byUser = {};
    for (final s in stories) {
      byUser.putIfAbsent(s.userId, () => []).add(s);
    }

    // Meu story primeiro, depois outros
    final myStories = byUser[currentUserId] ?? [];
    final othersEntries = byUser.entries
        .where((e) => e.key != currentUserId)
        .toList();

    return Container(
      height: 100,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          // Meu story
          _buildMyStory(context, myStories),
          // Stories dos outros
          ...othersEntries.map((entry) {
            final userStories = entry.value;
            final first = userStories.first;
            final rawList = userStories
                .map((s) => {
                      'id': s.id,
                      'user_id': s.userId,
                      'user_name': s.userName,
                      'media_url': s.mediaUrl,
                      'media_type': s.mediaType,
                      'created_at': s.createdAt.toIso8601String(),
                      'expires_at': s.expiresAt.toIso8601String(),
                      'users': {'name': s.userName, 'avatar_url': s.avatarUrl},
                    })
                .toList();
            return _buildStoryAvatar(
              context,
              name: first.userName,
              avatarUrl: first.avatarUrl,
              hasStory: true,
              isMine: false,
              onTap: () => onViewStory(rawList, 0),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMyStory(BuildContext context, List<_StoryItem> myStories) {
    final hasStory = myStories.isNotEmpty;
    return _buildStoryAvatar(
      context,
      name: 'Seu story',
      avatarUrl: null,
      hasStory: hasStory,
      isMine: true,
      onTap: hasStory
          ? () {
              final rawList = myStories
                  .map((s) => {
                        'id': s.id,
                        'user_id': s.userId,
                        'user_name': s.userName,
                        'media_url': s.mediaUrl,
                        'media_type': s.mediaType,
                        'created_at': s.createdAt.toIso8601String(),
                        'expires_at': s.expiresAt.toIso8601String(),
                        'users': {
                          'name': s.userName,
                          'avatar_url': null,
                        },
                      })
                  .toList();
              onViewStory(rawList, 0);
            }
          : onAddStory,
    );
  }

  Widget _buildStoryAvatar(
    BuildContext context, {
    required String name,
    required String? avatarUrl,
    required bool hasStory,
    required bool isMine,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 4),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Anel gradiente se tem story
                if (hasStory)
                  Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _TalkColors.brandGradient,
                    ),
                  )
                else
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                  ),
                // Avatar
                CircleAvatar(
                  radius: 27,
                  backgroundColor: const Color(0xFFB0BEC5),
                  backgroundImage: avatarUrl != null
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Icon(
                          isMine ? Icons.person : Icons.person,
                          color: Colors.white,
                          size: 26,
                        )
                      : null,
                ),
                // Botão + no meu story sem story
                if (isMine && !hasStory)
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        gradient: _TalkColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(fontSize: 11, color: Color(0xFF333333)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Página de Chats ──────────────────────────────────────────────────
class _ChatsPage extends StatefulWidget {
  final ValueNotifier<List<ChatModel>> conversationsNotifier;
  final ValueNotifier<bool> loadingNotifier;
  final ValueNotifier<List<_StoryItem>> storiesNotifier;
  final String currentUserId;
  final void Function(ChatModel) onTap;
  final void Function(ChatModel) onLongPress;
  final VoidCallback onNewChat;
  final VoidCallback onAddStory;
  final void Function(List<Map<String, dynamic>>, int) onViewStory;

  const _ChatsPage({
    Key? key,
    required this.conversationsNotifier,
    required this.loadingNotifier,
    required this.storiesNotifier,
    required this.currentUserId,
    required this.onTap,
    required this.onLongPress,
    required this.onNewChat,
    required this.onAddStory,
    required this.onViewStory,
  }) : super(key: key);

  @override
  _ChatsPageState createState() => _ChatsPageState();
}

class _ChatsPageState extends State<_ChatsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Story bar no topo
          ValueListenableBuilder<List<_StoryItem>>(
            valueListenable: widget.storiesNotifier,
            builder: (context, stories, _) {
              return _StoryBar(
                stories: stories,
                currentUserId: widget.currentUserId,
                onAddStory: widget.onAddStory,
                onViewStory: widget.onViewStory,
              );
            },
          ),
          const Divider(height: 1, thickness: 0.5),
          // Lista de conversas
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: widget.loadingNotifier,
              builder: (context, loading, _) {
                if (loading) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: _TalkColors.gradientEnd),
                  );
                }
                return ValueListenableBuilder<List<ChatModel>>(
                  valueListenable: widget.conversationsNotifier,
                  builder: (context, conversations, _) {
                    if (conversations.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhuma conversa ainda.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        return _buildChatItem(conversations[index]);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: _TalkColors.brandGradient,
        ),
        child: FloatingActionButton(
          onPressed: widget.onNewChat,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_comment_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatModel chat) {
    return InkWell(
      onTap: () => widget.onTap(chat),
      onLongPress: () => widget.onLongPress(chat),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: const Color(0xFFB0BEC5),
              backgroundImage: chat.avatar != null
                  ? CachedNetworkImageProvider(chat.avatar!)
                  : null,
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
                      Text(chat.name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111111))),
                      Text(
                        chat.time,
                        style: TextStyle(
                          fontSize: 12,
                          color: chat.unreadCount > 0
                              ? _TalkColors.gradientEnd
                              : Colors.grey,
                        ),
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
                            gradient: _TalkColors.brandGradient,
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
}

// ─── Página de Perfil ──────────────────────────────────────────────────
class _ProfilePage extends StatefulWidget {
  final ValueNotifier<String> nameNotifier;
  final ValueNotifier<String?> avatarNotifier;
  final ValueNotifier<bool> uploadingNotifier;
  final VoidCallback onAvatarTap;
  final VoidCallback onSignOut;

  const _ProfilePage({
    Key? key,
    required this.nameNotifier,
    required this.avatarNotifier,
    required this.uploadingNotifier,
    required this.onAvatarTap,
    required this.onSignOut,
  }) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(children: [
      const SizedBox(height: 24),
      ValueListenableBuilder<bool>(
        valueListenable: widget.uploadingNotifier,
        builder: (context, uploading, _) {
          return ValueListenableBuilder<String?>(
            valueListenable: widget.avatarNotifier,
            builder: (context, avatarUrl, _) {
              return ValueListenableBuilder<String>(
                valueListenable: widget.nameNotifier,
                builder: (context, name, _) {
                  return Center(
                    child: GestureDetector(
                      onTap: uploading ? null : widget.onAvatarTap,
                      child: Stack(children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: const Color(0xFFB0BEC5),
                          backgroundImage: avatarUrl != null
                              ? CachedNetworkImageProvider(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : 'T',
                                  style: const TextStyle(
                                      fontSize: 40,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        if (uploading)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                  color: Colors.black38,
                                  shape: BoxShape.circle),
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2)),
                            ),
                          ),
                        if (!uploading)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                  gradient: _TalkColors.brandGradient,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                      ]),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      const SizedBox(height: 10),
      const Center(
          child: Text('Toque para alterar foto',
              style: TextStyle(color: Colors.grey, fontSize: 12))),
      const SizedBox(height: 8),
      ValueListenableBuilder<String>(
        valueListenable: widget.nameNotifier,
        builder: (context, name, _) => Center(
          child: Text(name,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 28),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          _buildMenuItem(
              icon: Icons.person_outline,
              title: 'Conta',
              subtitle: 'Número, Nome de Usuário, Bio',
              onTap: () {}),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
              icon: Icons.chat_bubble_outline,
              title: 'Configurações de Chat',
              subtitle: 'Papel de Parede, Modo Noturno, Animações',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ChatSettingsScreen()))),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
              icon: Icons.key_outlined,
              title: 'Privacidade e Segurança',
              subtitle: 'Visto por Último, Dispositivos, Chaves de Acesso',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()))),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
              icon: Icons.notifications_outlined,
              title: 'Notificações',
              subtitle: 'Sons, Chamadas, Contadores',
              onTap: () {}),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
              icon: Icons.language,
              title: 'Idioma',
              subtitle: 'Português (Brasil)',
              onTap: () {}),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(
              icon: Icons.person_remove_outlined,
              title: 'Excluir conta',
              subtitle: 'Apagar permanentemente sua conta',
              onTap: () {}),
        ]),
      ),
      const SizedBox(height: 20),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: _buildMenuItem(
            icon: Icons.logout_rounded,
            title: 'Sair',
            subtitle: 'Encerrar sessão',
            titleColor: Colors.red,
            iconColor: Colors.red,
            onTap: widget.onSignOut),
      ),
      const SizedBox(height: 32),
    ]);
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFFE8E8EA),
        highlightColor: const Color(0xFFF2F2F4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: iconColor ?? const Color(0xFF444444), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? const Color(0xFF111111))),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF8E8E93))),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}

// ─── Homescreen principal ─────────────────────────────────────────────
class Homescreen extends StatefulWidget {
  const Homescreen({Key? key}) : super(key: key);

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  int _currentIndex = 0;

  // ValueNotifiers — única fonte de verdade, nunca recriados
  final ValueNotifier<List<ChatModel>> _conversationsNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(true);
  final ValueNotifier<String> _profileNameNotifier = ValueNotifier('');
  final ValueNotifier<String?> _profileAvatarNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _uploadingAvatarNotifier = ValueNotifier(false);
  final ValueNotifier<List<_StoryItem>> _storiesNotifier = ValueNotifier([]);

  // Páginas criadas uma única vez — IndexedStack as mantém vivas
  late final Widget _chatsPage;
  late final Widget _profilePage;
  late final Widget _callsPage;
  late final Widget _contactsPage;
  late final Widget _statusPage;

  bool _isLoadingConversations = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    // Páginas instanciadas aqui e nunca mais recriadas
    _chatsPage = _ChatsPage(
      conversationsNotifier: _conversationsNotifier,
      loadingNotifier: _loadingNotifier,
      storiesNotifier: _storiesNotifier,
      currentUserId: _currentUserId,
      onTap: _openChat,
      onLongPress: _deleteConversation,
      onNewChat: _openSelectContact,
      onAddStory: _showAddStorySheet,
      onViewStory: _openStoryView,
    );

    _profilePage = _ProfilePage(
      nameNotifier: _profileNameNotifier,
      avatarNotifier: _profileAvatarNotifier,
      uploadingNotifier: _uploadingAvatarNotifier,
      onAvatarTap: _pickAndUploadAvatar,
      onSignOut: _signOut,
    );

    _callsPage = const _KeepAliveWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: Text('Calls em breve',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15))),
      ),
    );

    _contactsPage = const _KeepAliveWrapper(child: ContactsScreen());
    _statusPage = const _KeepAliveWrapper(child: StatusScreen());

    // Carrega tudo uma única vez
    _loadConversations();
    _loadStories();
    _loadUserProfile();

    // Realtime — única fonte de atualização, sem polling
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _conversationsNotifier.dispose();
    _loadingNotifier.dispose();
    _profileNameNotifier.dispose();
    _profileAvatarNotifier.dispose();
    _uploadingAvatarNotifier.dispose();
    _storiesNotifier.dispose();
    super.dispose();
  }

  // ── Stories ───────────────────────────────────────────────────────
  Future<void> _loadStories() async {
    try {
      final data = await Supabase.instance.client
          .from('stories')
          .select('*, users(name, avatar_url)')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      final items = (data as List).map((m) => _StoryItem.fromMap(m)).toList();
      _storiesNotifier.value = items;
    } catch (e) {
      debugPrint('Erro ao carregar stories: $e');
    }
  }

  void _showAddStorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddStorySheet(onStoryAdded: _loadStories),
    );
  }

  void _openStoryView(List<Map<String, dynamic>> stories, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StoryViewScreen(stories: stories, initialIndex: index),
      ),
    );
  }

  // ── Conversas ─────────────────────────────────────────────────────
  Future<void> _loadConversations() async {
    if (_isLoadingConversations) return;
    _isLoadingConversations = true;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      _loadingNotifier.value = false;
      _isLoadingConversations = false;
      return;
    }

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
          .eq('user_id', userId)
          .limit(20)
          .timeout(const Duration(seconds: 10),
              onTimeout: () =>
                  throw Exception('Tempo limite ao carregar conversas'));

      final rawList = data as List;

      if (rawList.isEmpty) {
        _conversationsNotifier.value = [];
        _loadingNotifier.value = false;
        _isLoadingConversations = false;
        return;
      }

      // Batch query para contactId
      final conversationIds =
          rawList.map((i) => i['conversation_id'] as String).toSet().toList();

      final membersData = await supabase
          .from('conversation_members')
          .select('conversation_id, user_id')
          .inFilter('conversation_id', conversationIds);

      final Map<String, List<String>> membersByConv = {};
      for (final row in (membersData as List)) {
        membersByConv
            .putIfAbsent(row['conversation_id'] as String, () => [])
            .add(row['user_id'] as String);
      }

      rawList.sort((a, b) {
        final ta = a['conversations']['last_message_time'] as String? ?? '';
        final tb = b['conversations']['last_message_time'] as String? ?? '';
        return tb.compareTo(ta);
      });

      _conversationsNotifier.value = rawList.map((item) {
        final conv = item['conversations'];
        final convId = conv['id'] as String;
        final participants = membersByConv[convId] ?? [];
        final otherUserId =
            participants.firstWhere((u) => u != userId, orElse: () => '');

        return ChatModel(
          id: convId,
          name: conv['name'] ?? 'Conversa',
          avatar: conv['avatar_url'],
          isGroup: conv['is_group'] ?? false,
          lastMessage: conv['last_message'] ?? '',
          time: _formatTime(conv['last_message_time'] as String?),
          unreadCount: item['unread_count'] ?? 0,
          contactId: otherUserId.isNotEmpty ? otherUserId : null,
        );
      }).toList();

      _loadingNotifier.value = false;
    } catch (e) {
      debugPrint('Erro ao carregar conversas: $e');
      _loadingNotifier.value = false;
    } finally {
      _isLoadingConversations = false;
    }
  }

  void _forceRefresh() {
    _isLoadingConversations = false;
    _loadConversations();
  }

  // Realtime — atualiza dados sem spinner, sem reconstrução de página
  void _subscribeRealtime() {
    Supabase.instance.client
        .channel('home-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _forceRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stories',
          callback: (_) => _loadStories(),
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

  // ── Perfil ────────────────────────────────────────────────────────
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
        _profileNameNotifier.value = data['name'] ?? '';
        _profileAvatarNotifier.value = data['avatar_url'];
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80,
        maxWidth: 1080, maxHeight: 1080);
    if (picked == null) return;

    final file = File(picked.path);
    if (await file.length() > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Imagem muito grande (máx. 5MB).'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
      return;
    }

    _uploadingAvatarNotifier.value = true;
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      final ext = picked.path.split('.').last;
      final path = 'avatars/$userId.$ext';

      await supabase.storage
          .from('avatars')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      final url = supabase.storage.from('avatars').getPublicUrl(path);
      await supabase
          .from('users')
          .upsert({'id': userId, 'avatar_url': url}, onConflict: 'id');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_avatar', url);

      if (mounted) {
        _profileAvatarNotifier.value = url;
        _uploadingAvatarNotifier.value = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Foto atualizada!'),
            backgroundColor: Color(0xFF34C759),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2)));
      }
    } catch (e) {
      if (mounted) {
        _uploadingAvatarNotifier.value = false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Sair'),
        content: const Text('Deseja encerrar a sessão?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Sair', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await Supabase.instance.client.auth.signOut();
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false);
    }
  }

  Future<void> _deleteConversation(ChatModel chat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir conversa',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Deseja excluir a conversa com "${chat.name}"?\n\nTodas as mensagens serão apagadas.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF444444))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: _TalkColors.gradientEnd))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final s = Supabase.instance.client;
      await s.from('messages').delete().eq('conversation_id', chat.id);
      await s.from('conversation_members').delete().eq('conversation_id', chat.id);
      await s.from('conversations').delete().eq('id', chat.id);
      _forceRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _openChat(ChatModel chat) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => IndividualPage(chatModel: chat)));

  void _openSelectContact() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const SelectContact()));

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pages = [
      _chatsPage,
      _callsPage,
      _contactsPage,
      _statusPage,
      _profilePage,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: ShaderMask(
          shaderCallback: (bounds) =>
              _TalkColors.brandGradient.createShader(bounds),
          child: const Text('Talk',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                    color: Color(0xFFF0F0F2), shape: BoxShape.circle),
                child: const Icon(Icons.search,
                    color: Color(0xFF333333), size: 20),
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border:
              Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.chat_bubble_outline,
                  Icons.chat_bubble_rounded, 'Chats'),
              _buildNavItem(
                  1, Icons.call_outlined, Icons.call_rounded, 'Calls'),
              _buildNavItem(2, Icons.people_alt_outlined,
                  Icons.people_alt_rounded, 'Contatos'),
              _buildNavItem(3, Icons.donut_large_outlined,
                  Icons.donut_large_rounded, 'Status'),
              _buildNavItem(
                  4, Icons.person_outline, Icons.person_rounded, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 4) _loadUserProfile();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 32,
              decoration: BoxDecoration(
                gradient: isSelected ? _TalkColors.brandGradient : null,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(isSelected ? filledIcon : outlineIcon,
                  color: isSelected ? Colors.white : Colors.grey, size: 22),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isSelected
                        ? _TalkColors.gradientEnd
                        : Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ─── Add Story Sheet ──────────────────────────────────────────────────
class _AddStorySheet extends StatefulWidget {
  final VoidCallback onStoryAdded;
  const _AddStorySheet({required this.onStoryAdded});

  @override
  State<_AddStorySheet> createState() => _AddStorySheetState();
}

class _AddStorySheetState extends State<_AddStorySheet> {
  int _selectedHours = 24;
  File? _mediaFile;
  bool _uploading = false;

  Future<void> _pickMedia() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _mediaFile = File(picked.path));
  }

  Future<void> _uploadStory() async {
    if (_mediaFile == null) return;
    setState(() => _uploading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final userData = await supabase
          .from('users')
          .select('name')
          .eq('id', userId)
          .single();
      final userName = userData['name'] ?? 'Usuário';

      final ext = _mediaFile!.path.split('.').last;
      final path =
          'stories/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('stories').upload(path, _mediaFile!,
          fileOptions: const FileOptions(upsert: true));

      final url = supabase.storage.from('stories').getPublicUrl(path);

      await supabase.from('stories').insert({
        'user_id': userId,
        'user_name': userName,
        'media_url': url,
        'media_type': 'image',
        'expires_at': DateTime.now()
            .add(Duration(hours: _selectedHours))
            .toIso8601String(),
      });

      Navigator.pop(context);
      widget.onStoryAdded();
    } catch (e) {
      debugPrint('Erro ao postar story: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text('Adicionar Story',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _pickMedia,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E0E0)),
                image: _mediaFile != null
                    ? DecorationImage(
                        image: FileImage(_mediaFile!), fit: BoxFit.cover)
                    : null,
              ),
              child: _mediaFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 48, color: _TalkColors.gradientStart),
                        SizedBox(height: 8),
                        Text('Toque para selecionar foto',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Duração do story',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [6, 12, 24].map((h) {
              final selected = _selectedHours == h;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedHours = h),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: selected ? _TalkColors.brandGradient : null,
                      color:
                          selected ? null : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Column(children: [
                      Text('${h}h',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color:
                                  selected ? Colors.white : Colors.black87)),
                      Text(
                          h == 6
                              ? '6 horas'
                              : h == 12
                                  ? '12 horas'
                                  : '24 horas',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  selected ? Colors.white70 : Colors.grey)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _mediaFile == null || _uploading
                    ? null
                    : _TalkColors.brandGradient,
                color: _mediaFile == null || _uploading
                    ? Colors.grey[300]
                    : null,
                borderRadius: BorderRadius.circular(30),
              ),
              child: ElevatedButton.icon(
                onPressed:
                    (_mediaFile == null || _uploading) ? null : _uploadStory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                icon: _uploading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                    _uploading ? 'Enviando...' : 'Publicar story',
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
