import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:talk_messenger/Screens/StoryViewScreen.dart';
import 'package:talk_messenger/Screens/StoriesController.dart';
import 'package:talk_messenger/core/constants/app_constants.dart';
import 'dart:io';

// Verde LINE — idêntico ao Homescreen
class _TalkColors {
  static const Color green = Color(0xFF06C755);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [green, green],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  // Anel de story estilo Instagram (igual ao Homescreen)
  static const LinearGradient storyRingGradient = LinearGradient(
    colors: [Color(0xFFF58529), Color(0xFFC62D92), Color(0xFF833AB4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class StatusScreen extends StatefulWidget {
  const StatusScreen({Key? key}) : super(key: key);

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    StoriesController.instance.init();
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

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _AddStorySheet(onStoryAdded: StoriesController.instance.loadStories),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      // FAB posicionado via Stack relativo à navbar (kNavBarHeight),
      // sem usar Scaffold.floatingActionButton que fica sob a navbar.
      body: Stack(
        children: [
          // ── Conteúdo principal ──────────────────────────────────────
          ValueListenableBuilder<bool>(
            valueListenable: StoriesController.instance.loadingNotifier,
            builder: (context, loading, _) {
              if (loading) {
                return const Center(
                    child: CircularProgressIndicator(color: _TalkColors.green));
              }
              return ValueListenableBuilder<List<StoryItem>>(
                valueListenable: StoriesController.instance.storiesNotifier,
                builder: (context, stories, _) {
                  return ListView(
                    // Padding inferior para o conteúdo não ficar escondido
                    // atrás do FAB e da navbar flutuante.
                    padding: const EdgeInsets.only(
                        bottom: kNavBarHeight + 80),
                    children: [
                      // Meu story
                      ListTile(
                        onTap: _showAddSheet,
                        leading: Stack(children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _TalkColors.storyRingGradient),
                            child: const Padding(
                              padding: EdgeInsets.all(2.5),
                              child: CircleAvatar(
                                backgroundColor: Color(0xFFB0BEC5),
                                child: Icon(Icons.person,
                                    color: Colors.white, size: 28),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                  color: _TalkColors.green,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.add,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ]),
                        title: const Text('Meu story',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                        subtitle: const Text('Toque para adicionar story',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 13)),
                      ),

                      if (stories.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                          child: Text('Atualizações recentes',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                        ...stories.map((story) {
                          final rawList =
                              stories.map((s) => s.toRawMap()).toList();
                          return ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoryViewScreen(
                                  stories: rawList,
                                  initialIndex: stories.indexOf(story),
                                ),
                              ),
                            ),
                            leading: Container(
                              width: 54,
                              height: 54,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: _TalkColors.storyRingGradient),
                              child: Padding(
                                padding: const EdgeInsets.all(2.5),
                                child: CircleAvatar(
                                  backgroundColor: const Color(0xFFB0BEC5),
                                  backgroundImage: story.avatarUrl != null &&
                                          story.avatarUrl!.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          story.avatarUrl!)
                                      : null,
                                  child: story.avatarUrl == null ||
                                          story.avatarUrl!.isEmpty
                                      ? Text(
                                          story.userName.isNotEmpty
                                              ? story.userName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              color: Colors.white))
                                      : null,
                                ),
                              ),
                            ),
                            title: Text(story.userName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16)),
                            subtitle: Text(
                                _formatTime(story.createdAt.toIso8601String()),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          );
                        }),
                      ],
                    ],
                  );
                },
              );
            },
          ),

          // ── FAB — posicionado acima da navbar ────────────────────────
          // Usa kNavBarHeight + 20 (respiro) + 20 (bottom da navbar) =
          // mesmo cálculo do FAB da Homescreen, garantindo consistência.
          Positioned(
            bottom: kNavBarHeight + 40,
            right: 20,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _TalkColors.green,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3306C755),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  heroTag: 'status_fab',
                  onPressed: _showAddSheet,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
              ),
            ),
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

  // 6/12/24 — todas liberadas, sem cadeado
  static const _durations = [6, 12, 24];

  Future<void> _pickMedia() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
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
      final path =
          'stories/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('stories').upload(path, _mediaFile!,
          fileOptions: const FileOptions(upsert: true));

      final url = supabase.storage.from('stories').getPublicUrl(path);

      await supabase.from('stories').insert({
        'user_id': userId,
        'user_name': userName,
        'media_url': url,
        'media_type': 'image',
        'expires_at': DateTime.now()
            .add(Duration(hours: _selectedHours))
            .toUtc()
            .toIso8601String(),
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
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          GestureDetector(
            onTap: _mediaFile == null ? _pickMedia : null,
            child: Container(
              height: _mediaFile != null ? 200 : 160,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color:
                    _mediaFile == null ? Colors.white.withOpacity(0.07) : null,
                border: _mediaFile == null
                    ? Border.all(
                        color: Colors.white.withOpacity(0.12), width: 1)
                    : null,
                image: _mediaFile != null
                    ? DecorationImage(
                        image: FileImage(_mediaFile!), fit: BoxFit.cover)
                    : null,
              ),
              child: _mediaFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 44, color: _TalkColors.green),
                        SizedBox(height: 8),
                        Text('Toque para selecionar foto',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 14)),
                      ],
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Row(children: [
              Expanded(
                child: Text('Adicionar legenda...',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 15)),
              ),
              GestureDetector(
                onTap: () =>
                    setState(() => _showDurationPicker = !_showDurationPicker),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.access_time,
                        color: Colors.white70, size: 15),
                    const SizedBox(width: 4),
                    Text('${_selectedHours}h',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.camera_alt_outlined,
                  color: Colors.white54, size: 22),
            ]),
          ),

          if (_showDurationPicker) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      'Escolha por quanto tempo o\nstory ficará visível.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                  ..._durations.map((h) {
                    final isSelected = h == _selectedHours;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      color: isSelected
                          ? Colors.white.withOpacity(0.06)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedHours = h;
                          _showDurationPicker = false;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(children: [
                            Expanded(
                              child: Text('$h horas',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16)),
                            ),
                            if (isSelected)
                              const Icon(Icons.check,
                                  color: Colors.white, size: 20),
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
                      side:
                          BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Trocar foto',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _mediaFile != null && !_uploading
                        ? _TalkColors.green
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ElevatedButton.icon(
                    onPressed:
                        (_mediaFile == null || _uploading) ? null : _uploadStory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                    label: Text(
                        _uploading ? 'Enviando...' : 'Publicar story',
                        style: TextStyle(
                            fontSize: 15,
                            color: _mediaFile != null && !_uploading
                                ? Colors.white
                                : Colors.white38,
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
