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
  List<UserModel> _users = [];
  List<UserModel> _filtered = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filter);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _users = _filtered = []);
      return;
    }

    setState(() => _loading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .neq('id', userId ?? '')
          .or('name.ilike.%$query%,phone.ilike.%$query%')
          .limit(20);

      setState(() {
        _users = (data as List).map((u) => UserModel.fromMap(u)).toList();
        _filtered = _users;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() => _filtered = _users);
      return;
    }
    _search(q);
  }

  Future<void> _startConversation(UserModel user) async {
    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // Verifica se já existe conversa entre os dois
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou telefone...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0A84FF)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0A84FF)))
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Digite um nome ou telefone'
                              : 'Nenhum usuário encontrado',
                          style: const TextStyle(color: Colors.grey),
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
                                  fontSize: 13, color: Color(0xFF8E8E93)),
                            ),
                            trailing: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: user.isOnline
                                    ? const Color(0xFF34C759)
                                    : Colors.grey,
                              ),
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
