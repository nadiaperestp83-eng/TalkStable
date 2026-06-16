import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:talk_messenger/Screens/StoryViewScreen.dart';
import 'dart:io';

class StatusScreen extends StatefulWidget {
  const StatusScreen({Key? key}) : super(key: key);

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<Map<String, dynamic>> _stories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    try {
      final data = await Supabase.instance.client
          .from('stories')
          .select('*, users(name, avatar_url)')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      setState(() {
        _stories = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
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

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    final dt = DateTime.tryParse(isoTime)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0A84FF)))
          : ListView(
              children: [
                // Meu status
                ListTile(
                  onTap: _showAddStorySheet,
                  leading: Stack(
                    children: [
                      const CircleAvatar(
                        radius: 27,
                        backgroundColor: Color(0xFFB0BEC5),
                        child: Icon(Icons.person,
                            color: Colors.white, size: 28),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0A84FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  title: const Text(
                    'Meu status',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: const Text(
                    'Toque para adicionar status',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),

                if (_stories.isNotEmpty) ...[
                  const Padding(
                    padding:
                        EdgeInsets.only(left: 16, top: 8, bottom: 4),
                    child: Text(
                      'Atualizações recentes',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  ..._stories.map((story) {
                    final user = story['users'] ?? {};
                    return ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoryViewScreen(
                            stories: _stories,
                            initialIndex: _stories.indexOf(story),
                          ),
                        ),
                      ),
                      leading: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF0A84FF), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFB0BEC5),
                          backgroundImage: user['avatar_url'] != null
                              ? NetworkImage(user['avatar_url'])
                              : null,
                          child: user['avatar_url'] == null
                              ? Text(
                                  (user['name'] ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white),
                                )
                              : null,
                        ),
                      ),
                      title: Text(
                        user['name'] ?? 'Usuário',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      subtitle: Text(
                        _formatTime(story['created_at']),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStorySheet,
        backgroundColor: const Color(0xFF0A84FF),
        shape: const CircleBorder(),
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }
}

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
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _mediaFile = File(picked.path));
  }

  Future<void> _uploadStory() async {
    if (_mediaFile == null) return;
    setState(() => _uploading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final ext = _mediaFile!.path.split('.').last;
      final path =
          'stories/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('stories').upload(
            path,
            _mediaFile!,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = supabase.storage.from('stories').getPublicUrl(path);

      await supabase.from('stories').insert({
        'user_id': userId,
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
      setState(() => _uploading = false);
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
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
          const SizedBox(height: 20),
          const Text(
            'Adicionar Status',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),

          // Preview da mídia
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
                        image: FileImage(_mediaFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _mediaFile == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 48, color: Color(0xFF0A84FF)),
                        SizedBox(height: 8),
                        Text('Toque para selecionar foto',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),

          // Duração
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Duração do status',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [6, 12, 24].map((h) {
              final selected = _selectedHours == h;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedHours = h),
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF0A84FF)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF0A84FF)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${h}h',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        Text(
                          h == 6
                              ? '6 horas'
                              : h == 12
                                  ? '12 horas'
                                  : '24 horas',
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? Colors.white70
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Botão postar
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  (_mediaFile == null || _uploading) ? null : _uploadStory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A84FF),
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
              label: Text(
                _uploading ? 'Enviando...' : 'Publicar status',
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
