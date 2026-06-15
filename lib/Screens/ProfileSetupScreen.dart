import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk_messenger/Screens/Homescreen.dart';
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
