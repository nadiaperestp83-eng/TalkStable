import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:talk_messenger/Model/ChatModel.dart';
import 'package:talk_messenger/Model/UserModel.dart';
import 'package:talk_messenger/Screens/IndividualPage.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // Lista de contatos já adicionados (tabela contacts)
  List<UserModel> _myContacts = [];
  bool _loadingContacts = true;

  // Busca por email/telefone
  final _searchController = TextEditingController();
  bool _searching = false;
  bool _searchPerformed = false;
  UserModel? _searchResult;
  bool _resultAlreadyAdded = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadMyContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Carregar contatos já adicionados ──────────────────────────────────
  Future<void> _loadMyContacts() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) {
      setState(() => _loadingContacts = false);
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('contacts')
          .select('''
            contact_id,
            users!contacts_contact_id_fkey (
              id, name, avatar_url, phone, email, status, is_online, last_seen
            )
          ''')
          .eq('owner_id', myId);

      final List<UserModel> contacts = (data as List)
          .where((item) => item['users'] != null)
          .map((item) => UserModel.fromMap(item['users']))
          .toList();

      contacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _myContacts = contacts;
          _loadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingContacts = false);
      }
    }
  }

  // ── Buscar usuário por email ou telefone ──────────────────────────────
  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    setState(() {
      _searching = true;
      _searchPerformed = true;
      _searchResult = null;
      _searchError = null;
    });

    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .or('email.eq.$query,phone.eq.$query')
          .neq('id', myId)
          .limit(1);

      final results = data as List;

      if (results.isEmpty) {
        setState(() {
          _searchResult = null;
          _searching = false;
        });
        return;
      }

      final user = UserModel.fromMap(results.first);
      final alreadyAdded = _myContacts.any((c) => c.id == user.id);

      setState(() {
        _searchResult = user;
        _resultAlreadyAdded = alreadyAdded;
        _searching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Erro ao buscar: $e';
        _searching = false;
      });
    }
  }

  // ── Adicionar contato ──────────────────────────────────────────────────
  Future<void> _addContact(UserModel user) async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await Supabase.instance.client.from('contacts').insert({
        'owner_id': myId,
        'contact_id': user.id,
      });

      if (mounted) {
        setState(() {
          _resultAlreadyAdded = true;
          _myContacts.add(user);
          _myContacts.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} adicionado aos contatos!'),
            backgroundColor: const Color(0xFF34C759),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar contato: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchPerformed = false;
      _searchResult = null;
      _searchError = null;
    });
  }

  // ── Abrir chat com um contato ──────────────────────────────────────────
  Future<void> _openChat(UserModel user) async {
    final supabase = Supabase.instance.client;
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
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

          if (!mounted) return;
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

      if (!mounted) return;
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
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchUser(),
              decoration: InputDecoration(
                hintText: 'Buscar por email ou telefone...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF0A84FF)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: _clearSearch,
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward,
                            color: Color(0xFF0A84FF)),
                        onPressed: _searchUser,
                      ),
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

          // Resultado da busca (se houver)
          if (_searchPerformed) _buildSearchResultArea(),

          if (_searchPerformed) const Divider(height: 1),

          // Cabeçalho da lista de contatos
          if (!_loadingContacts && _myContacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MEUS CONTATOS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          // Lista de contatos já adicionados
          Expanded(
            child: _loadingContacts
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF0A84FF)))
                : _myContacts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _searchPerformed
                                ? ''
                                : 'Você ainda não tem contatos.\nBusque por email ou telefone para adicionar.',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _myContacts.length,
                        itemBuilder: (context, index) {
                          return _buildContactItem(_myContacts[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultArea() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
        ),
      );
    }

    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Text(
          _searchError!,
          style: const TextStyle(color: Colors.red, fontSize: 13),
        ),
      );
    }

    if (_searchResult == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: Text(
            'Nenhum usuário encontrado para "${_searchController.text}"',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final user = _searchResult!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFB0BEC5),
              backgroundImage:
                  user.avatar != null ? CachedNetworkImageProvider(user.avatar!) : null,
              child: user.avatar == null
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111)),
                  ),
                  Text(
                    user.email ?? user.phone ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF8E8E93)),
                  ),
                ],
              ),
            ),
            _resultAlreadyAdded
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.check_circle,
                        color: Color(0xFF34C759), size: 22),
                  )
                : ElevatedButton(
                    onPressed: () => _addContact(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A84FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Adicionar'),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(UserModel user) {
    return InkWell(
      onTap: () => _openChat(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: const Color(0xFFB0BEC5),
                  backgroundImage: user.avatar != null
                      ? CachedNetworkImageProvider(user.avatar!)
                      : null,
                  child: user.avatar == null
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 13, color: Color(0xFF8E8E93)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (user.lastSeen != null)
              Text(
                _formatLastSeen(user.lastSeen!),
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
              ),
          ],
        ),
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
