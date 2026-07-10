import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:talk_messenger/Screens/VideoCallScreen.dart';

// Verde LINE
const Color _kGreen = Color(0xFF06C755);

// ─── Modelo local de chamada ──────────────────────────────────────────
class _CallRecord {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String callType; // 'voice' | 'video'
  final String status; // 'completed' | 'missed' | 'declined'
  final int durationSeconds;
  final DateTime startedAt;
  final bool isCaller;

  const _CallRecord({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.callType,
    required this.status,
    required this.durationSeconds,
    required this.startedAt,
    required this.isCaller,
  });

  factory _CallRecord.fromMap(Map<String, dynamic> m, String currentUserId) {
    final isCaller = m['caller_id'] == currentUserId;
    final otherUser =
        isCaller ? (m['callee'] ?? {}) : (m['caller'] ?? {});

    return _CallRecord(
      id: m['id'] ?? '',
      otherUserId: isCaller
          ? (m['callee_id'] ?? '')
          : (m['caller_id'] ?? ''),
      otherUserName: otherUser['name'] ?? 'Usuário',
      otherUserAvatar: otherUser['avatar_url'],
      callType: m['call_type'] ?? 'voice',
      status: m['status'] ?? 'completed',
      durationSeconds: m['duration_seconds'] ?? 0,
      startedAt:
          DateTime.tryParse(m['started_at'] ?? '') ?? DateTime.now(),
      isCaller: isCaller,
    );
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return m > 0
        ? '${m}min ${s.toString().padLeft(2, '0')}s'
        : '${s}s';
  }
}

// ─── Tela de Chamadas ─────────────────────────────────────────────────
class CallsScreen extends StatefulWidget {
  const CallsScreen({Key? key}) : super(key: key);

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<_CallRecord> _calls = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Busca chamadas onde o usuário é caller ou callee,
      // com join nos dados do outro participante.
      final data = await Supabase.instance.client
          .from('calls')
          .select('''
            id, caller_id, callee_id, call_type, status,
            duration_seconds, started_at, ended_at,
            caller:users!calls_caller_id_fkey(name, avatar_url),
            callee:users!calls_callee_id_fkey(name, avatar_url)
          ''')
          .or('caller_id.eq.$userId,callee_id.eq.$userId')
          .order('started_at', ascending: false)
          .limit(100);

      if (!mounted) return;
      setState(() {
        _calls = (data as List)
            .map((m) =>
                _CallRecord.fromMap(m as Map<String, dynamic>, userId))
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Erro ao carregar chamadas: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Erro ao carregar chamadas';
        });
      }
    }
  }

  // Registra nova chamada sainte no Supabase e abre VideoCallScreen
  Future<void> _startCall(
      String calleeId, String calleeName, String? calleeAvatar,
      {required bool isVideo}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('calls').insert({
        'caller_id': userId,
        'callee_id': calleeId,
        'call_type': isVideo ? 'video' : 'voice',
        'status': 'completed',
        'started_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Erro ao registrar chamada: $e');
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          channelName: calleeId,
          calleeName: calleeName,
          calleeAvatar: calleeAvatar,
        ),
      ),
    ).then((_) => _loadCalls());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: _kGreen,
        onRefresh: _loadCalls,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _kGreen))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.grey.shade400, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loadCalls,
                          child: const Text('Tentar novamente',
                              style: TextStyle(color: _kGreen)),
                        ),
                      ],
                    ),
                  )
                : _calls.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.call_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhuma chamada ainda',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Suas chamadas de voz e vídeo\naparecerão aqui.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 8, bottom: 120),
                        itemCount: _calls.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, indent: 72, thickness: 0.5),
                        itemBuilder: (_, i) => _buildCallItem(_calls[i]),
                      ),
      ),
    );
  }

  Widget _buildCallItem(_CallRecord call) {
    // Cor do status
    final isIncoming = !call.isCaller;
    final isMissed = call.status == 'missed';
    final isDeclined = call.status == 'declined';
    final statusColor = (isMissed || isDeclined) ? Colors.red : _kGreen;

    // Ícone da direção/tipo
    IconData directionIcon;
    if (isMissed) {
      directionIcon = Icons.call_missed;
    } else if (isDeclined) {
      directionIcon = Icons.call_missed_outgoing;
    } else if (isIncoming) {
      directionIcon = call.callType == 'video'
          ? Icons.videocam
          : Icons.call_received;
    } else {
      directionIcon = call.callType == 'video'
          ? Icons.videocam_outlined
          : Icons.call_made;
    }

    // Data/hora
    final now = DateTime.now();
    final dt = call.startedAt.toLocal();
    String timeLabel;
    if (dt.day == now.day && dt.month == now.month) {
      timeLabel =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(dt).inDays < 7) {
      const days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
      timeLabel = days[dt.weekday % 7];
    } else {
      timeLabel = '${dt.day}/${dt.month}';
    }

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFFB0BEC5),
        backgroundImage: call.otherUserAvatar != null &&
                call.otherUserAvatar!.isNotEmpty
            ? CachedNetworkImageProvider(call.otherUserAvatar!)
            : null,
        child: call.otherUserAvatar == null || call.otherUserAvatar!.isEmpty
            ? Text(
                call.otherUserName.isNotEmpty
                    ? call.otherUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18))
            : null,
      ),
      title: Text(
        call.otherUserName,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isMissed || isDeclined
                ? Colors.red
                : const Color(0xFF111111)),
      ),
      subtitle: Row(
        children: [
          Icon(directionIcon, size: 14, color: statusColor),
          const SizedBox(width: 4),
          Text(
            call.callType == 'video' ? 'Vídeo' : 'Voz',
            style: TextStyle(fontSize: 13, color: statusColor),
          ),
          if (call.formattedDuration.isNotEmpty) ...[
            const Text(' · ',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text(call.formattedDuration,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(timeLabel,
              style:
                  const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          // Botão de retorno de chamada
          GestureDetector(
            onTap: () => _startCall(
              call.otherUserId,
              call.otherUserName,
              call.otherUserAvatar,
              isVideo: call.callType == 'video',
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F0F2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                call.callType == 'video'
                    ? Icons.videocam_outlined
                    : Icons.call_outlined,
                color: _kGreen,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
