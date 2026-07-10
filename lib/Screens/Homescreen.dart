import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:talk_messenger/Model/ChatModel.dart';
import 'package:talk_messenger/Screens/IndividualPage.dart';
import 'package:talk_messenger/Screens/SelectContact.dart';
import 'package:talk_messenger/Screens/StatusScreen.dart';
import 'package:talk_messenger/Screens/ChatSettingsScreen.dart';
import 'package:talk_messenger/Screens/ContactsScreen.dart';
import 'package:talk_messenger/Screens/LoginScreen.dart';
import 'package:talk_messenger/Screens/StoryViewScreen.dart';
import 'package:talk_messenger/Screens/ProfileSetupScreen.dart';
import 'package:talk_messenger/Screens/StoriesController.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_messenger/core/navigation/navigation_repository.dart';
import 'package:talk_messenger/core/constants/app_constants.dart';
import 'package:talk_messenger/widgets/floating_nav_bar.dart';
import 'dart:io';

class _TalkColors {
  // Branding LINE Messenger: verde oficial em todas as instâncias que antes
  // eram roxas (FAB, ícone de story, badges, destaques de texto etc.).
  // Mantido como "gradient" (start == end) para não precisar tocar em cada
  // ponto do código que consome `_TalkColors.brandGradient` — o resultado
  // visual é uma cor sólida #06C755.
  static const Color gradientStart = Color(0xFF06C755);
  static const Color gradientEnd = Color(0xFF06C755);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Gradiente exclusivo do anel de story (estilo Instagram).
  // Usado SÓ no anel — botões, FAB e badges continuam com o brandGradient verde.
  static const LinearGradient storyRingGradient = LinearGradient(
    colors: [
      Color(0xFFF58529),
      Color(0xFFC62D92),
      Color(0xFF833AB4),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

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
  final List<StoryItem> stories;
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
    final Map<String, List<StoryItem>> byUser = {};
    for (final s in stories) {
      byUser.putIfAbsent(s.userId, () => []).add(s);
    }

    final myStories = byUser[currentUserId] ?? [];
    final othersEntries =
        byUser.entries.where((e) => e.key != currentUserId).toList();

    return Container(
      height: 104,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          _buildMyStoryAvatar(context, myStories),
          ...othersEntries.map((entry) {
            final first = entry.value.first;
            final rawList = entry.value.map((s) => s.toRawMap()).toList();
            return _buildUserAvatar(
              context,
              name: first.userName,
              avatarUrl: first.avatarUrl,
              onTap: () => onViewStory(rawList, 0),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMyStoryAvatar(BuildContext context, List<StoryItem> myStories) {
    final hasStory = myStories.isNotEmpty;
    return GestureDetector(
      onTap: hasStory
          ? () => onViewStory(myStories.map((s) => s.toRawMap()).toList(), 0)
          : onAddStory,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStory ? _TalkColors.storyRingGradient : null,
                    border: hasStory
                        ? null
                        : Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                ),
                const CircleAvatar(
                  radius: 29,
                  backgroundColor: Color(0xFFB0BEC5),
                  child: Icon(Icons.person, color: Colors.white, size: 28),
                ),
                Positioned(
                  bottom: 0,
                  right: 2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      gradient: _TalkColors.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Seu story',
              style: TextStyle(fontSize: 11, color: Color(0xFF333333)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialsAvatar(String name) {
    return Container(
      color: const Color(0xFFB0BEC5),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }

  Widget _buildUserAvatar(
    BuildContext context, {
    required String name,
    required String? avatarUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(left: 6),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _TalkColors.storyRingGradient,
                  ),
                ),
                ClipOval(
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                color: const Color(0xFFB0BEC5)),
                            // Se a URL estiver quebrada (bucket não público,
                            // link expirado etc.) cai pras iniciais em vez
                            // de deixar o círculo em branco.
                            errorWidget: (_, __, ___) => _initialsAvatar(name),
                          )
                        : _initialsAvatar(name),
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

// ─── Chats Page ───────────────────────────────────────────────────────
class _ChatsPage extends StatefulWidget {
  final ValueNotifier<List<ChatModel>> conversationsNotifier;
  final ValueNotifier<bool> loadingNotifier;
  final String currentUserId;
  final void Function(ChatModel) onTap;
  final void Function(ChatModel) onLongPress;
  final VoidCallback onAddStory;
  final void Function(List<Map<String, dynamic>>, int) onViewStory;

  const _ChatsPage({
    Key? key,
    required this.conversationsNotifier,
    required this.loadingNotifier,
    required this.currentUserId,
    required this.onTap,
    required this.onLongPress,
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
      // Único ListView.builder: índice 0 = Story bar, índices seguintes = chats.
      // Story e chats leem do mesmo estado global (StoriesController é um
      // singleton com ValueNotifier — qualquer publicação atualiza os dois
      // lugares instantaneamente, sem precisar de Provider/Riverpod).
      body: ValueListenableBuilder<bool>(
        valueListenable: widget.loadingNotifier,
        builder: (context, loading, _) {
          return ValueListenableBuilder<List<ChatModel>>(
            valueListenable: widget.conversationsNotifier,
            builder: (context, conversations, _) {
              final contentCount =
                  loading ? 1 : (conversations.isEmpty ? 1 : conversations.length);

              return ListView.builder(
                itemCount: 1 + contentCount,
                itemBuilder: (context, index) {
                  // Índice 0 — Story bar, escuta o próprio notifier global
                  if (index == 0) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<List<StoryItem>>(
                          valueListenable: StoriesController.instance.storiesNotifier,
                          builder: (context, stories, _) => _StoryBar(
                            stories: stories,
                            currentUserId: widget.currentUserId,
                            onAddStory: widget.onAddStory,
                            onViewStory: widget.onViewStory,
                          ),
                        ),
                        const Divider(height: 1, thickness: 0.5),
                      ],
                    );
                  }

                  if (loading) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: _TalkColors.gradientEnd),
                      ),
                    );
                  }

                  if (conversations.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text('Nenhuma conversa ainda.',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  }

                  return _buildChatItem(conversations[index - 1]);
                },
              );
            },
          );
        },
      ),
      // O FAB não vive mais aqui: ele foi movido para o Stack principal da
      // Homescreen (posicionado de forma relativa à navbar, sempre acima
      // dela) para eliminar qualquer sobreposição entre os dois elementos.
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
              backgroundImage:
                  chat.avatar != null ? CachedNetworkImageProvider(chat.avatar!) : null,
              child: chat.avatar == null
                  ? Text(chat.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))
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
                      Text(chat.time,
                          style: TextStyle(
                              fontSize: 12,
                              color: chat.unreadCount > 0
                                  ? _TalkColors.gradientEnd
                                  : Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(chat.lastMessage,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: _TalkColors.brandGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(chat.unreadCount.toString(),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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

// ─── Profile Page ─────────────────────────────────────────────────────
class _ProfilePage extends StatefulWidget {
  final ValueNotifier<String> nameNotifier;
  final ValueNotifier<String> usernameNotifier;
  final ValueNotifier<String?> avatarNotifier;
  final ValueNotifier<bool> uploadingNotifier;
  final VoidCallback onAvatarTap;
  final VoidCallback onSignOut;
  final VoidCallback onEditUsername;

  const _ProfilePage({
    Key? key,
    required this.nameNotifier,
    required this.usernameNotifier,
    required this.avatarNotifier,
    required this.uploadingNotifier,
    required this.onAvatarTap,
    required this.onSignOut,
    required this.onEditUsername,
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
        builder: (_, uploading, __) => ValueListenableBuilder<String?>(
          valueListenable: widget.avatarNotifier,
          builder: (_, avatarUrl, __) => ValueListenableBuilder<String>(
            valueListenable: widget.nameNotifier,
            builder: (_, name, __) => Center(
              child: GestureDetector(
                onTap: uploading ? null : widget.onAvatarTap,
                child: Stack(children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: const Color(0xFFB0BEC5),
                    backgroundImage:
                        avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'T',
                            style: const TextStyle(
                                fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  if (uploading)
                    Positioned.fill(
                      child: Container(
                        decoration:
                            const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
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
                            gradient: _TalkColors.brandGradient, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Center(
          child: Text('Toque para alterar foto',
              style: TextStyle(color: Colors.grey, fontSize: 12))),
      const SizedBox(height: 8),
      ValueListenableBuilder<String>(
        valueListenable: widget.nameNotifier,
        builder: (_, name, __) => Center(
            child: Text(name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
      ),
      const SizedBox(height: 2),
      ValueListenableBuilder<String>(
        valueListenable: widget.usernameNotifier,
        builder: (_, username, __) => username.isEmpty
            ? const SizedBox.shrink()
            : Center(
                child: GestureDetector(
                  onTap: widget.onEditUsername,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('@$username',
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit,
                          size: 13, color: Color(0xFF8E8E93)),
                    ],
                  ),
                ),
              ),
      ),
      const SizedBox(height: 28),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          _menuItem(Icons.person_outline, 'Conta', 'Número, Nome de Usuário, Bio', () {}),
          const Divider(height: 1, indent: 56),
          _menuItem(
              Icons.chat_bubble_outline,
              'Configurações de Chat',
              'Papel de Parede, Modo Noturno, Animações',
              () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ChatSettingsScreen()))),
          const Divider(height: 1, indent: 56),
          _menuItem(
              Icons.key_outlined,
              'Privacidade e Segurança',
              'Visto por Último, Dispositivos, Chaves de Acesso',
              () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const PrivacyScreen()))),
          const Divider(height: 1, indent: 56),
          _menuItem(Icons.notifications_outlined, 'Notificações', 'Sons, Chamadas, Contadores',
              () {}),
          const Divider(height: 1, indent: 56),
          _menuItem(Icons.language, 'Idioma', 'Português (Brasil)', () {}),
          const Divider(height: 1, indent: 56),
          _menuItem(Icons.person_remove_outlined, 'Excluir conta',
              'Apagar permanentemente sua conta', () {}),
        ]),
      ),
      const SizedBox(height: 20),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: _menuItem(Icons.logout_rounded, 'Sair', 'Encerrar sessão', widget.onSignOut,
            titleColor: Colors.red, iconColor: Colors.red),
      ),
      const SizedBox(height: 32),
    ]);
  }

  Widget _menuItem(IconData icon, String title, String subtitle, VoidCallback onTap,
      {Color? titleColor, Color? iconColor}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
            ])),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}

// ─── Homescreen ───────────────────────────────────────────────────────
class Homescreen extends StatefulWidget {
  const Homescreen({Key? key}) : super(key: key);

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  // Fonte única de verdade da aba ativa. Isolada em repositório próprio
  // (Repository Pattern) para não misturar estado de navegação com o
  // restante da lógica da Homescreen.
  final NavigationRepository _navigationRepository = NavigationRepository();

  static const List<TalkNavItem> _navItems = [
    TalkNavItem(
      tab: TalkNavTab.chats,
      outlineIcon: Icons.chat_bubble_outline,
      filledIcon: Icons.chat_bubble_rounded,
      label: 'Chats',
    ),
    TalkNavItem(
      tab: TalkNavTab.calls,
      outlineIcon: Icons.call_outlined,
      filledIcon: Icons.call_rounded,
      label: 'Calls',
    ),
    TalkNavItem(
      tab: TalkNavTab.contacts,
      outlineIcon: Icons.people_alt_outlined,
      filledIcon: Icons.people_alt_rounded,
      label: 'Contatos',
    ),
    TalkNavItem(
      tab: TalkNavTab.status,
      outlineIcon: Icons.donut_large_outlined,
      filledIcon: Icons.donut_large_rounded,
      label: 'Status',
    ),
    TalkNavItem(
      tab: TalkNavTab.profile,
      outlineIcon: Icons.person_outline,
      filledIcon: Icons.person_rounded,
      label: 'Perfil',
    ),
  ];

  final ValueNotifier<List<ChatModel>> _conversationsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(true);
  final ValueNotifier<String> _profileNameNotifier = ValueNotifier('');
  final ValueNotifier<String> _profileUsernameNotifier = ValueNotifier('');
  DateTime? _usernameChangedAt;
  final ValueNotifier<String?> _profileAvatarNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _uploadingAvatarNotifier = ValueNotifier(false);

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

    StoriesController.instance.init();

    _chatsPage = _ChatsPage(
      conversationsNotifier: _conversationsNotifier,
      loadingNotifier: _loadingNotifier,
      currentUserId: _currentUserId,
      onTap: _openChat,
      onLongPress: _deleteConversation,
      onAddStory: _showAddStorySheet,
      onViewStory: _openStoryView,
    );

    _profilePage = _ProfilePage(
      nameNotifier: _profileNameNotifier,
      usernameNotifier: _profileUsernameNotifier,
      avatarNotifier: _profileAvatarNotifier,
      uploadingNotifier: _uploadingAvatarNotifier,
      onAvatarTap: _pickAndUploadAvatar,
      onSignOut: _signOut,
      onEditUsername: _editUsername,
    );

    _callsPage = const _KeepAliveWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: Text('Calls em breve', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15))),
      ),
    );

    _contactsPage = const _KeepAliveWrapper(child: ContactsScreen());
    _statusPage = const _KeepAliveWrapper(child: StatusScreen());

    _loadConversations();
    _loadUserProfile();
    _subscribeConversationsRealtime();
  }

  @override
  void dispose() {
    _navigationRepository.dispose();
    _conversationsNotifier.dispose();
    _loadingNotifier.dispose();
    _profileNameNotifier.dispose();
    _profileUsernameNotifier.dispose();
    _profileAvatarNotifier.dispose();
    _uploadingAvatarNotifier.dispose();
    super.dispose();
  }

  void _showAddStorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddStorySheet(onStoryAdded: StoriesController.instance.loadStories),
    );
  }

  void _openStoryView(List<Map<String, dynamic>> stories, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoryViewScreen(stories: stories, initialIndex: index)),
    );
  }

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
          .timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('Tempo limite'));

      final rawList = data as List;

      if (rawList.isEmpty) {
        _conversationsNotifier.value = [];
        _loadingNotifier.value = false;
        _isLoadingConversations = false;
        return;
      }

      final conversationIds = rawList.map((i) => i['conversation_id'] as String).toSet().toList();

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
        final otherUserId = participants.firstWhere((u) => u != userId, orElse: () => '');

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

  void _subscribeConversationsRealtime() {
    Supabase.instance.client
        .channel('home-conversations-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _forceRefresh(),
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

  Future<void> _loadUserProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data =
          await Supabase.instance.client.from('users').select().eq('id', userId).single();
      if (mounted) {
        _profileNameNotifier.value = data['name'] ?? '';
        _profileUsernameNotifier.value = data['username'] ?? '';
        _profileAvatarNotifier.value = data['avatar_url'];
        _usernameChangedAt = DateTime.tryParse(data['username_changed_at'] ?? '');
      }
    } catch (_) {}
  }

  Future<void> _editUsername() async {
    if (_usernameChangedAt != null) {
      final daysSinceChange = DateTime.now().difference(_usernameChangedAt!).inDays;
      if (daysSinceChange < 30) {
        final daysLeft = 30 - daysSinceChange;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Você só pode alterar o username novamente em $daysLeft dia(s).'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating));
        }
        return;
      }
    }

    final controller = TextEditingController(text: _profileUsernameNotifier.value);
    bool isSaving = false;
    String? errorText;

    final newUsername = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Alterar username',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: '@',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (errorText != null) setDialogState(() => errorText = null);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Você só poderá alterar de novo depois de 30 dias.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final candidate = controller.text.trim().toLowerCase();

                      if (candidate.isEmpty) {
                        setDialogState(() => errorText = 'Digite um username');
                        return;
                      }
                      if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(candidate)) {
                        setDialogState(() => errorText =
                            '3-20 caracteres: letras, números ou _');
                        return;
                      }
                      if (candidate == _profileUsernameNotifier.value.toLowerCase()) {
                        Navigator.pop(dialogContext);
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        final userId = Supabase.instance.client.auth.currentUser?.id;
                        final existing = await Supabase.instance.client
                            .from('users')
                            .select('id')
                            .eq('username', candidate)
                            .maybeSingle();

                        if (existing != null && existing['id'] != userId) {
                          setDialogState(() {
                            isSaving = false;
                            errorText = 'Username indisponível';
                          });
                          return;
                        }

                        if (dialogContext.mounted) Navigator.pop(dialogContext, candidate);
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          errorText = 'Erro ao verificar. Tente de novo.';
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Salvar',
                      style: TextStyle(
                          color: _TalkColors.gradientEnd, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (newUsername == null) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final now = DateTime.now().toUtc();

      await Supabase.instance.client.from('users').update({
        'username': newUsername,
        'username_changed_at': now.toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        _profileUsernameNotifier.value = newUsername;
        _usernameChangedAt = now;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Username atualizado!'),
            backgroundColor: Color(0xFF34C759),
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1080, maxHeight: 1080);
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

      await supabase.storage.from('avatars').upload(path, file,
          fileOptions: const FileOptions(upsert: true));

      final url = supabase.storage.from('avatars').getPublicUrl(path);
      await supabase.from('users').upsert({'id': userId, 'avatar_url': url}, onConflict: 'id');

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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      StoriesController.instance.disposeChannel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await Supabase.instance.client.auth.signOut();
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    }
  }

  Future<void> _deleteConversation(ChatModel chat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir conversa', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Deseja excluir a conversa com "${chat.name}"?\n\nTodas as mensagens serão apagadas.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF444444))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: _TalkColors.gradientEnd))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
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

  void _openChat(ChatModel chat) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => IndividualPage(chatModel: chat)));

  void _openSelectContact() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectContact()));

  @override
  Widget build(BuildContext context) {
    final pages = [_chatsPage, _callsPage, _contactsPage, _statusPage, _profilePage];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        title: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Talk',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                width: 38,
                height: 38,
                decoration:
                    const BoxDecoration(color: Color(0xFFF0F0F2), shape: BoxShape.circle),
                child: const Icon(Icons.search, color: Color(0xFF333333), size: 20),
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
      // O body deixa de ser só o IndexedStack: agora é um Stack com 3
      // camadas, na ordem exata pedida:
      //   1) conteúdo das abas (mais embaixo)
      //   2) navbar flutuante (no meio)
      //   3) FAB (no topo — nunca fica escondido atrás da navbar)
      // Isso substitui o antigo Scaffold.bottomNavigationBar/floatingActionButton,
      // conforme solicitado (navbar e FAB isolados, não presos ao Scaffold).
      body: Stack(
        children: [
          // 1) Conteúdo das abas. O índice vem do NavigationRepository via
          // ValueListenableBuilder, então só esse trecho reconstrói ao
          // trocar de aba — o IndexedStack interno preserva cada página
          // viva (sem reload de imagens/feed).
          ValueListenableBuilder<TalkNavTab>(
            valueListenable: _navigationRepository.currentTab,
            builder: (context, activeTab, _) {
              return IndexedStack(
                index: activeTab.index,
                children: pages,
              );
            },
          ),

          // 2) Pílula flutuante: fixada na parte inferior central da tela,
          // com respiro lateral (horizontal: 20) e distância do fundo,
          // flutuando sobre o conteúdo (estilo referência enviada).
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: SafeArea(
              top: false,
              child: FloatingNavBar(
                repository: _navigationRepository,
                items: _navItems,
                onTabSelected: (tab) {
                  if (tab == TalkNavTab.profile) _loadUserProfile();
                },
              ),
            ),
          ),

          // 3) FAB — posicionamento RELATIVO à navbar, e não a um valor
          // fixo "chutado". bottom = kNavBarHeight + 20.0 garante que o
          // FAB sempre flutue exatamente 20px acima do topo da pílula,
          // mesmo que kNavBarHeight mude no futuro (ex.: navbar maior em
          // telas de tablet). Só aparece na aba "Chats", já que é a ação
          // de "nova conversa".
          ValueListenableBuilder<TalkNavTab>(
            valueListenable: _navigationRepository.currentTab,
            builder: (context, activeTab, _) {
              if (activeTab != TalkNavTab.chats) return const SizedBox.shrink();
              return Positioned(
                bottom: kNavBarHeight + 20.0,
                right: 20.0,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _TalkColors.brandGradient,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x3306C755),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      onPressed: _openSelectContact,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.add_comment_rounded, color: Colors.white),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
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
  bool _showDurationPicker = false;

  // Somente 6h / 12h / 24h — todas liberadas, sem cadeado.
  static const _durations = [6, 12, 24];

  Future<void> _pickMedia() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _mediaFile = File(picked.path));
    }
  }

  Future<void> _uploadStory() async {
    if (_mediaFile == null) return;
    setState(() => _uploading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final userData =
          await supabase.from('users').select('name').eq('id', userId).single();
      final userName = userData['name'] ?? 'Usuário';

      final ext = _mediaFile!.path.split('.').last;
      final path = 'stories/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage
          .from('stories')
          .upload(path, _mediaFile!, fileOptions: const FileOptions(upsert: true));

      final url = supabase.storage.from('stories').getPublicUrl(path);

      await supabase.from('stories').insert({
        'user_id': userId,
        'user_name': userName,
        'media_url': url,
        'media_type': 'image',
        'expires_at':
            DateTime.now().add(Duration(hours: _selectedHours)).toUtc().toIso8601String(),
      });

      Navigator.pop(context);
      widget.onStoryAdded();
    } catch (e) {
      debugPrint('Erro ao postar story: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(top: 12, bottom: bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration:
                  BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Preview ou placeholder
          GestureDetector(
            onTap: _mediaFile == null ? _pickMedia : null,
            child: Container(
              height: _mediaFile != null ? 200 : 160,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _mediaFile == null ? Colors.white.withOpacity(0.07) : null,
                border: _mediaFile == null
                    ? Border.all(color: Colors.white.withOpacity(0.12), width: 1)
                    : null,
                image: _mediaFile != null
                    ? DecorationImage(image: FileImage(_mediaFile!), fit: BoxFit.cover)
                    : null,
              ),
              child: _mediaFile == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 44, color: Color(0xFF8A5CF5)),
                        SizedBox(height: 8),
                        Text('Toque para selecionar foto',
                            style: TextStyle(color: Colors.white54, fontSize: 14)),
                      ],
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 12),

          // Barra legenda + timer
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Row(children: [
              Expanded(
                child: Text('Adicionar legenda...',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15)),
              ),
              GestureDetector(
                onTap: () => setState(() => _showDurationPicker = !_showDurationPicker),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.access_time, color: Colors.white70, size: 15),
                    const SizedBox(width: 4),
                    Text('${_selectedHours}h',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 22),
            ]),
          ),

          // Duration picker estilo Telegram — todas as opções liberadas
          if (_showDurationPicker) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration:
                  BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      'Escolha por quanto tempo o\nstory ficará visível.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.55), fontSize: 13, height: 1.4),
                    ),
                  ),
                  ..._durations.map((h) {
                    final isSelected = h == _selectedHours;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      color: isSelected ? Colors.white.withOpacity(0.06) : Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedHours = h;
                          _showDurationPicker = false;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(children: [
                            Expanded(
                              child: Text('$h horas',
                                  style: const TextStyle(color: Colors.white, fontSize: 16)),
                            ),
                            if (isSelected)
                              const Icon(Icons.check, color: Colors.white, size: 20),
                          ]),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              if (_mediaFile != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickMedia,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Trocar foto', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _mediaFile != null && !_uploading ? _TalkColors.brandGradient : null,
                    color: _mediaFile == null || _uploading ? Colors.white12 : null,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: (_mediaFile == null || _uploading) ? null : _uploadStory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    label: Text(_uploading ? 'Enviando...' : 'Publicar story',
                        style: TextStyle(
                            fontSize: 15,
                            color: _mediaFile != null && !_uploading ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
