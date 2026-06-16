import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talk_messenger/Model/ChatModel.dart';
import 'package:talk_messenger/Model/UserModel.dart';
import 'package:talk_messenger/Screens/IndividualPage.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<UserModel> _contacts = [];
  List<UserModel> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .neq('id', myId)
          .order('name');

      setState(() {
        _contacts = (data as List).map((u) => UserModel.fromMap(u)).toList();
        _filtered = _contacts;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _contacts
          : _contacts
              .where((u) =>
                  u.name.toLowerCase().contains(q) ||
                  (u.phone ?? '').contains(q))
              .toList();
    });
  }

  Future<void> _openChat(UserModel user) async {
    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // Verifica se já existe conversa
      final existing = await supabase
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', myId);

      final myConvIds = (existing as List)
          .map((e) => e['conversation_id'] as String)
          .toList();

      if (myConvIds.isNotEmpty) {
        final shared = await supabase
            .from('conversation_members')
            .select('conversation_id')
            .eq('user_id', user.id)
            .inFilter('conversation_id', myConvIds);

        if ((shared as List).isNotEmpty) {
          final convId = shared.first['conversation_id'];
          final conv = await supabase
              .from('conversations')
              .select()
              .eq('id', convId)
              .single();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IndividualPage(
                chatModel: ChatModel(
                  id: conv['id'],
                  name: user.name,
                  avatar: user.avatar,
                  isOnline: user.isOnline,
                ),
              ),
            ),
          );
          return;
        }
      }

      // Cria nova conversa
      final conv = await supabase.from('conversations').insert({
        'is_group': false,
        'name': user.name,
        'last_message': '',
        'last_message_time': DateTime.now().toIso8601String(),
      }).select().single();

      await supabase.from('conversation_members').insert([
        {'conversation_id': conv['id'], 'user_id': myId},
        {'conversation_id': conv['id'], 'user_id': user.id},
      ]);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IndividualPage(
            chatModel: ChatModel(
              id: conv['id'],
              name: user.name,
              avatar: user.avatar,
              isOnline: user.isOnline,
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao abrir chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar contatos...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF0A84FF)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // Lista
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0A84FF)))
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Nenhum contato encontrado.'
                              : 'Nenhum resultado para "${_searchController.text}"',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final user = _filtered[index];
                          return InkWell(
                            onTap: () => _openChat(user),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 27,
                                        backgroundColor:
                                            const Color(0xFFB0BEC5),
                                        backgroundImage: user.avatar != null
                                            ? NetworkImage(user.avatar!)
                                            : null,
                                        child: user.avatar == null
                                            ? Text(
                                                user.name[0].toUpperCase(),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 20),
                                              )
                                            : null,
                                      ),
                                      if (user.isOnline)
                                        Positioned(
                                          bottom: 1,
                                          right: 1,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF34C759),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF111111)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user.status ??
                                              user.phone ??
                                              'Olá, estou usando o Talk!',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF8E8E93)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (user.lastSeen != null)
                                    Text(
                                      _formatLastSeen(user.lastSeen!),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8E8E93)),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 2) return 'online';
    if (diff.inHours < 24) return 'visto ${diff.inHours}h atrás';
    return 'visto ontem';
  }
}
