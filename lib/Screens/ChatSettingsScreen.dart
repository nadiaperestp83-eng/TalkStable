import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_messenger/main.dart' show themeNotifier;
import 'dart:io';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  String _currentTheme = 'light';
  String? _wallpaperPath;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('app_theme') ?? 'light';
      _wallpaperPath = prefs.getString('chat_wallpaper');
    });
  }

  Future<void> _saveTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', value);
    setState(() => _currentTheme = value);
    themeNotifier.value = value;
  }

  Future<void> _pickWallpaper() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_wallpaper', picked.path);
      setState(() => _wallpaperPath = picked.path);
    }
  }

  Future<void> _removeWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_wallpaper');
    setState(() => _wallpaperPath = null);
  }

  void _showThemeSheet() {
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
            _themeOption(
              label: 'Claro',
              value: 'light',
              icon: Icons.wb_sunny_outlined,
              iconColor: const Color(0xFFFF9500),
            ),
            _themeOption(
              label: 'AMOLED',
              value: 'amoled',
              icon: Icons.nights_stay_outlined,
              iconColor: const Color(0xFF0A84FF),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _themeOption({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    final selected = _currentTheme == value;
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: selected ? const Color(0xFF0A84FF) : Colors.black87,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Color(0xFF0A84FF))
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      onTap: () {
        _saveTheme(value);
        Navigator.pop(context);
      },
    );
  }

  String get _themeLabel => _currentTheme == 'amoled' ? 'AMOLED' : 'Claro';

  Widget _buildItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
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
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasWallpaper =
        _wallpaperPath != null && File(_wallpaperPath!).existsSync();

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
            subtitle: _themeLabel,
            onTap: _showThemeSheet,
          ),
          const Divider(height: 1, indent: 20),
          _buildItem(
            icon: Icons.palette_outlined,
            title: 'Papel de Parede',
            subtitle: hasWallpaper ? 'Imagem personalizada' : 'Nenhum',
            onTap: _pickWallpaper,
            trailing: hasWallpaper
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(_wallpaperPath!),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _removeWallpaper,
                        child: const Icon(Icons.close,
                            color: Colors.grey, size: 20),
                      ),
                    ],
                  )
                : const Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
