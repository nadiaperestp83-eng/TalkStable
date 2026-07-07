import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:talk_messenger/Screens/StoryViewScreen.dart';
import 'package:talk_messenger/core/stories/StoriesController.dart';

class _TalkColors {
  static const Color gradientStart = Color(0xFF8A5CF5);
  static const Color gradientEnd = Color(0xFF6539E8);
  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
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
    // Singleton idempotente — se já foi inicializado pela Home, não faz nada
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: ValueListenableBuilder<bool>(
        valueListenable: StoriesController.instance.loadingNotifier,
        builder: (context, loading, _) {
          if (loading) {
            return const Center(
                child: CircularProgressIndicator(
                    color: _TalkColors.gradientEnd));
          }
          return ValueListenableBuilder<List<StoryItem>>(
            valueListenable: StoriesController.instance.storiesNotifier,
            builder: (context, stories, _) {
              return ListView(children: [
                // Meu story
                ListTile(
                  onTap: () => _showAddSheet(context),
                  leading: Stack(children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _TalkColors.brandGradient),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
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
                            gradient: _TalkColors.brandGradient,
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
                            gradient: _TalkColors.brandGradient),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
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
              ]);
            },
          );
        },
      ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: _TalkColors.brandGradient),
        child: FloatingActionButton(
          onPressed: () => _showAddSheet(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.camera_alt, color: Colors.white),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddStorySheet(
          onStoryAdded: StoriesController.instance.loadStories),
    );
  }
}

// ─── Add Story Sheet (mesmo componente reutilizado) ───────────────────
class _AddStorySheet extends StatefulWidget {
  final VoidCallback onStoryAdded;
  const _AddStorySheet({required this.onStoryAdded});

  @override
  State<_AddStorySheet> createState() => _AddStorySheetState();
}

class _AddStorySheetState extends State<_AddStorySheet> {
  int _selectedHours = 24;
  dynamic _mediaFile;
  bool _uploading = false;
  bool _showDurationPicker = false;

  static const _durations = [6, 12, 24, 48];

  Future<void> _pickMedia() async {
    // ignore: depend_on_referenced_packages
    final picked = await (await Future(() async {
      final ImagePicker picker = ImagePicker();
      return picker;
    }()))
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

      final userData = await supabase
          .from('users')
          .select('name')
          .eq('id', userId)
          .single();
      final userName = userData['name'] ?? 'Usuário';

      final ext = (_mediaFile as File).path.split('.').last;
      final path =
          'stories/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage
          .from('stories')
          .upload(path, _mediaFile as File,
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
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _mediaFile as File?;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withOpacity(0.97),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
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

          // Preview ou placeholder
          GestureDetector(
            onTap: file == null ? _pickMedia : null,
            child: Container(
              height: file != null ? 200 : 160,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: file == null
                    ? Colors.white.withOpacity(0.07)
                    : null,
                border: file == null
                    ? Border.all(
                        color: Colors.white.withOpacity(0.12), width: 1)
                    : null,
                image: file != null
                    ? DecorationImage(
                        image: FileImage(file), fit: BoxFit.cover)
                    : null,
              ),
              child: file == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 44, color: Color(0xFF8A5CF5)),
                        SizedBox(height: 8),
                        Text('Toque para selecionar foto',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 14)),
                      ],
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 12),

          // Barra legenda + timer
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Row(children: [
              Expanded(
                child: Text('Adicionar legenda...',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 15)),
              ),
              GestureDetector(
                onTap: () =>
                    setState(() => _showDurationPicker = !_showDurationPicker),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
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

          // Duration picker
          if (_showDurationPicker) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(14),
              ),
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
                    final isLocked = h == 6 || h == 12;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      color: isSelected
                          ? Colors.white.withOpacity(0.06)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: isLocked
                            ? null
                            : () => setState(() {
                                  _selectedHours = h;
                                  _showDurationPicker = false;
                                }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(children: [
                            Expanded(
                              child: Text('$h horas',
                                  style: TextStyle(
                                      color: isLocked
                                          ? Colors.white38
                                          : Colors.white,
                                      fontSize: 16)),
                            ),
                            if (isSelected)
                              const Icon(Icons.check,
                                  color: Colors.white, size: 20)
                            else if (isLocked)
                              const Icon(Icons.lock_outline,
                                  color: Colors.white38, size: 18),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              if (file != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickMedia,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.white.withOpacity(0.2)),
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
                    gradient: file != null && !_uploading
                        ? _TalkColors.brandGradient
                        : null,
                    color: file == null || _uploading
                        ? Colors.white12
                        : null,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ElevatedButton.icon(
                    onPressed:
                        (file == null || _uploading) ? null : _uploadStory,
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
                            color: file != null && !_uploading
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
