import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoryItem {
  final String id;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String mediaUrl;
  final String mediaType;
  final DateTime createdAt;
  final DateTime expiresAt;

  StoryItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.expiresAt,
  });

  factory StoryItem.fromMap(Map<String, dynamic> m) {
    final user = m['users'] as Map<String, dynamic>? ?? {};
    // avatarUrl: prioridade para o join com users, fallback nulo
    final String? avatarUrl = user['avatar_url']?.toString();
    // userName: prioridade para user_name salvo na story, fallback para join
    final String userName = (m['user_name'] as String?)?.isNotEmpty == true
        ? m['user_name'] as String
        : (user['name'] as String?) ?? 'Usuário';

    return StoryItem(
      id: m['id']?.toString() ?? '',
      userId: m['user_id']?.toString() ?? '',
      userName: userName,
      avatarUrl: avatarUrl,
      mediaUrl: m['media_url']?.toString() ?? '',
      mediaType: m['media_type']?.toString() ?? 'image',
      createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(m['expires_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toRawMap() => {
        'id': id,
        'user_id': userId,
        'user_name': userName,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'users': {'name': userName, 'avatar_url': avatarUrl},
      };

  // Primeira letra do nome para fallback de avatar
  String get initials =>
      userName.isNotEmpty ? userName[0].toUpperCase() : '?';
}

class StoriesController {
  StoriesController._internal();
  static final StoriesController instance = StoriesController._internal();

  final ValueNotifier<List<StoryItem>> storiesNotifier =
      ValueNotifier<List<StoryItem>>([]);
  final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(true);

  RealtimeChannel? _channel;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await loadStories();
    _subscribeRealtime();
  }

  Future<void> loadStories() async {
    try {
      final data = await Supabase.instance.client
          .from('stories')
          .select('*, users(name, avatar_url)')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false);

      final items = (data as List)
          .map((m) => StoryItem.fromMap(m as Map<String, dynamic>))
          .toList();

      storiesNotifier.value = items;
      loadingNotifier.value = false;
    } catch (e) {
      debugPrint('StoriesController.loadStories erro: $e');
      loadingNotifier.value = false;
    }
  }

  void _subscribeRealtime() {
    if (_channel != null) return;
    _channel = Supabase.instance.client
        .channel('stories-realtime-shared')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stories',
          callback: (_) => loadStories(),
        )
        .subscribe();
  }

  void disposeChannel() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    _initialized = false;
  }
}
