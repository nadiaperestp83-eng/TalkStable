import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  String _tema = 'Claro';

  @override
  void initState() {
    super.initState();
    _loadTema();
  }

  Future<void> _loadTema() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _tema = prefs.getString('tema') ?? 'Claro');
  }

  Future<void> _saveTema(String tema) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tema', tema);
    setState(() => _tema = tema);
  }

  void _showTemaSheet() {
    final opcoes = ['Claro', 'Escuro', 'AMOLED'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
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
              'Tema',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Divider(),
            ...opcoes.map((opcao) => ListTile(
                  title: Text(
                    opcao,
                    style: TextStyle(
                      fontSize: 16,
                      color: opcao == _tema
                          ? const Color(0xFF0A84FF)
                          : Colors.black87,
                      fontWeight: opcao == _tema
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: opcao == _tema
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFF0A84FF))
                      : const Icon(Icons.radio_button_unchecked,
                          color: Colors.grey),
                  onTap: () {
                    _saveTema(opcao);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF8E8E93)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Conversas',
          style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 20, top: 20, bottom: 8),
            child: Text(
              'Exibição',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
            ),
          ),
          const Divider(height: 1),
          _buildItem(
            icon: Icons.brightness_medium_outlined,
            title: 'Tema',
            subtitle: _tema,
            onTap: _showTemaSheet,
          ),
          const Divider(height: 1, indent: 20),
          _buildItem(
            icon: Icons.palette_outlined,
            title: 'Papel de Parede',
            subtitle: '',
            onTap: () {},
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
