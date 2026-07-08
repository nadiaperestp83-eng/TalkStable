import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modelo de story, compartilhado entre Homescreen e StatusScreen.
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

  // Trata tanto null quanto string vazia "" como "sem valor" — o operador
  // ?? do Dart só cobre null, então um user_name/avatar_url salvo como ""
  // no banco passava direto e resultava em texto/imagem em branco na UI.
  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory StoryItem.fromMap(Map<String, dynamic> m) {
    final user = m['users'] as Map<String, dynamic>? ?? {};
    return StoryItem(
      id: m['id']?.toString() ?? '',
      userId: m['user_id']?.toString() ?? '',
      userName: _nonEmpty(m['user_name']) ?? _nonEmpty(user['name']) ?? 'Usuário',
      avatarUrl: _nonEmpty(user['avatar_url']),
      mediaUrl: _nonEmpty(m['media_url']) ?? '',
      mediaType: _nonEmpty(m['media_type']) ?? 'image',
      createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(m['expires_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Converte de volta para o formato Map cru que o StoryViewScreen espera
  /// (mesmo formato que já era montado manualmente na Homescreen antiga).
  Map<String, dynamic> toRawMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'users': {'name': userName, 'avatar_url': avatarUrl},
    };
  }
}

/// Fonte única de verdade para stories.
///
/// Singleton: tanto a Homescreen quanto a StatusScreen leem o mesmo
/// `storiesNotifier`, então uma story publicada em qualquer uma das duas
/// telas aparece automaticamente na outra — sem precisar recarregar a página
/// e sem duas subscriptions realtime concorrentes.
///
/// Uso:
///   - Chame `StoriesController.instance.init()` no initState de QUALQUER
///     tela que precise das stories (Home e Status). É seguro chamar dos
///     dois lugares: a segunda chamada não faz nada (idempotente).
///   - Escute `StoriesController.instance.storiesNotifier` com um
///     ValueListenableBuilder.
///   - Depois de publicar uma story nova, chame
///     `StoriesController.instance.loadStories()` (o realtime já faz isso
///     sozinho quando a inserção vem do Supabase, mas chamar na hora deixa
///     a UI mais responsiva, sem esperar o evento realtime chegar).
class StoriesController {
  StoriesController._internal();
  static final StoriesController instance = StoriesController._internal();

  final ValueNotifier<List<StoryItem>> storiesNotifier =
      ValueNotifier<List<StoryItem>>([]);
  final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(true);

  RealtimeChannel? _channel;
  bool _initialized = false;

  /// Inicializa o controller (primeiro load + realtime). Idempotente —
  /// pode ser chamado tanto pela Home quanto pela Status sem duplicar nada.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await loadStories();
    _subscribeRealtime();
  }

  Future<void> loadStories() async {
    try {
      // Usamos .toUtc() aqui para bater exatamente com o expires_at
      // gravado no insert (que também é salvo em UTC). Misturar hora local
      // com UTC nos dois lados é o que fazia stories recém-publicados
      // sumirem do carrossel.
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
      debugPrint('Erro ao carregar stories: $e');
      loadingNotifier.value = false;
    }
  }

  void _subscribeRealtime() {
    // Guarda contra subscription duplicada caso init() seja chamado
    // mais de uma vez de lugares diferentes antes do _initialized virar true
    // (proteção extra, além do guard em init()).
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

  /// Normalmente NÃO precisa ser chamado — é um singleton que vive
  /// durante toda a sessão do app. Só use se realmente precisar encerrar
  /// a subscription manualmente (ex: logout completo do app).
  void disposeChannel() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    _initialized = false;
  }
}
