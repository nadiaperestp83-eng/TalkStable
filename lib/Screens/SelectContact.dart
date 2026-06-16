import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talk_messenger/Model/ChatModel.dart';
import 'package:talk_messenger/Model/UserModel.dart';
import 'package:talk_messenger/Screens/IndividualPage.dart';

class SelectContact extends StatefulWidget {
  const SelectContact({Key? key}) : super(key: key);

  @override
  State<SelectContact> createState() => _SelectContactState();
}

class _SelectContactState extends State<SelectContact> {
  final _searchController = TextEditingController();
  List<UserModel> _contacts = [];
  List<UserModel> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMyContacts();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ Carrega só os contatos que o usuário adicionou
  Future<void> _loadMyContacts() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('contacts')
          .select('contact_id, users!contacts_contact_id_fkey(id, name, avatar_url, phone, status, is_online)')
          .eq('owner_id', myId);

      final users = (data as List).map((row) {
        final u = row['users'];
        return UserModel.fromMap(u);
      }).toList();

      setState(() {
        _contacts = users;
        _filtered = users;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
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

  // ✅ Busca usuário por nome/telefone para adicionar como contato
  Future<void> _showAddContactSheet() async {
    final searchCtrl = TextEditingController();
    List<UserModel> results = [];
    bool searching = false;
    final myId = Supabase.instance.client.auth.currentUser?.id;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> search(String q) async {
              if (q.trim().isEmpty) {
                setModal(() => results = []);
                return;
              }
              setModal(() => searching = true);
              try {
                final data = await Supabase.instance.client
                    .from('users')
                    .select()
                    .neq('id', myId ?? '')
                    .or('name.ilike.%$q%,phone.ilike.%$q%')
                    .limit(20);
                setModal(() {
                  results = (data as List)
                      .map((u) => UserModel.fromMap(u))
                      .toList();
                  searching = false;
                });
              } catch (e) {
                setModal(() => searching = false);
              }
            }

            Future<void> addContact(UserModel user) async {
              try {
                await Supabase.instance.client.from('contacts').insert({
                  'owner_id': myId,
                  'contact_id': user.id,
                });
                Navigator.pop(ctx);
                _loadMyContacts(); // Atualiza lista
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${user.name} adicionado aos contatos'),
                    backgroundColor: const Color(0xFF0A84FF),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Erro ao adicionar contato'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Adicionar contato',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome ou telefone...',
                      prefixIcon: const Icon(Icons.search,
                          color: Color(0xFF0A84FF)),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: search,
                  ),
                  const SizedBox(height: 8),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          color: Color(0xFF0A84FF)),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final user = results[i];
                          final alreadyAdded =
                              _contacts.any((c) => c.id == user.id);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFB0BEC5),
                              backgroundImage: user.avatar != null
                                  ? NetworkImage(user.avatar!)
                                  : null,
                              child: user.avatar == null
                                  ? Text(user.name[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            title: Text(user.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(user.phone ?? user.status ?? ''),
                            trailing: alreadyAdded
                                ? const Icon(Icons.check,
                                    color: Color(0xFF34C759))
                                : IconButton(
                                    icon: const Icon(Icons.person_add,
                                        color: Color(0xFF0A84FF)),
                                    onPressed: () => addContact(user),
                                  ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _startConversation(UserModel user) async {
    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final existing = await supabase
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', myId);

      final myConvIds = (existing as List)
          .map((e) => e['conversation_id'].toString())
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

          if (!mounted) return;
          Navigator.pop(context);
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

      if (!mounted) return;
      Navigator.pop(context);
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
      debugPrint('Erro ao iniciar conversa: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A84FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nova conversa',
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        // ✅ Botão + para adicionar contato
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Color(0xFF0A84FF)),
            onPressed: _showAddContactSheet,
            tooltip: 'Adicionar contato',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar contato...',
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF0A84FF)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0A84FF)))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text(
                              'Nenhum contato ainda',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _showAddContactSheet,
                              icon: const Icon(Icons.person_add,
                                  color: Color(0xFF0A84FF)),
                              label: const Text(
                                'Adicionar contato',
                                style:
                                    TextStyle(color: Color(0xFF0A84FF)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final user = _filtered[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFB0BEC5),
                              backgroundImage: user.avatar != null
                                  ? NetworkImage(user.avatar!)
                                  : null,
                              child: user.avatar == null
                                  ? Text(
                                      user.name[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111111)),
                            ),
                            subtitle: Text(
                              user.status ?? user.phone ?? '',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8E8E93)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: user.isOnline
                                        ? const Color(0xFF34C759)
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _startConversation(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
