import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_messenger/Screens/Homescreen.dart';
import 'package:talk_messenger/Screens/LoginScreen.dart';
import 'dart:io';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _statusController = TextEditingController();
  File? _avatarFile;
  bool _loading = false;
  String _error = '';

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Digite seu nome');
      return;
    }

    setState(() { _loading = true; _error = ''; });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      String? avatarUrl;

      if (_avatarFile != null) {
        final ext = _avatarFile!.path.split('.').last;
        final path = 'avatars/$userId.$ext';
        await supabase.storage
            .from('avatars')
            .upload(path, _avatarFile!,
                fileOptions: const FileOptions(upsert: true));
        avatarUrl = supabase.storage.from('avatars').getPublicUrl(path);
      }

      await supabase.from('users').upsert({
        'id': userId,
        'name': name,
        'status': _statusController.text.trim().isEmpty
            ? 'Olá, estou usando o Talk!'
            : _statusController.text.trim(),
        'avatar_url': avatarUrl,
        'is_online': true,
      }, onConflict: 'id');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarded', true);
      await prefs.setString('user_name', name);
      if (avatarUrl != null) await prefs.setString('user_avatar', avatarUrl);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Homescreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = 'Erro ao salvar perfil. Tente novamente.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Configurar perfil',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _avatarFile != null
                          ? FileImage(_avatarFile!)
                          : null,
                      child: _avatarFile == null
                          ? const Icon(Icons.person,
                              size: 55, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0A84FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Toque para adicionar foto',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Seu nome',
                  prefixIcon: const Icon(Icons.person_outline,
                      color: Color(0xFF0A84FF)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF0A84FF), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _statusController,
                decoration: InputDecoration(
                  labelText: 'Status (opcional)',
                  hintText: 'Olá, estou usando o Talk!',
                  prefixIcon: const Icon(Icons.info_outline,
                      color: Color(0xFF0A84FF)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF0A84FF), width: 2),
                  ),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A84FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Continuar',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      setState(() {
        _name = data['name'] ?? prefs.getString('user_name') ?? '';
        _avatarUrl = data['avatar_url'];
      });
    } catch (e) {
      setState(() {
        _name = prefs.getString('user_name') ?? '';
      });
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja encerrar a sessão?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
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
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: const Color(0xFFB0BEC5),
              backgroundImage:
                  _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
              child: _avatarUrl == null
                  ? Text(
                      _name.isNotEmpty ? _name[0].toUpperCase() : 'T',
                      style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _name,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 28),
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
                  onTap: () {},
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
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A84FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacidade e Segurança',
          style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildPrivacyItem(
                  icon: Icons.access_time,
                  iconBg: const Color(0xFF34C759),
                  title: 'Visto por Último',
                  subtitle: 'Todos',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 74),
                _buildPrivacyItem(
                  icon: Icons.photo_outlined,
                  iconBg: const Color(0xFF0A84FF),
                  title: 'Foto do Perfil',
                  subtitle: 'Todos',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 74),
                _buildPrivacyItem(
                  icon: Icons.info_outline,
                  iconBg: const Color(0xFFFF9500),
                  title: 'Recado',
                  subtitle: 'Todos',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 74),
                _buildPrivacyItem(
                  icon: Icons.devices_outlined,
                  iconBg: const Color(0xFF5856D6),
                  title: 'Dispositivos Conectados',
                  subtitle: 'Gerenciar sessões ativas',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 74),
                _buildPrivacyItem(
                  icon: Icons.block,
                  iconBg: const Color(0xFFFF3B30),
                  title: 'Contatos Bloqueados',
                  subtitle: 'Nenhum',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPrivacyItem({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF8E8E93))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
