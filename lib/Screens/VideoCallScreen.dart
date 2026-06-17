import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:talk_messenger/main.dart' show agoraAppId;

class VideoCallScreen extends StatefulWidget {
  final String channelName; // usa o id da conversa
  final String calleeName;
  final String? calleeAvatar;

  const VideoCallScreen({
    Key? key,
    required this.channelName,
    required this.calleeName,
    this.calleeAvatar,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RtcEngine? _engine;
  bool _localJoined = false;
  bool _remoteJoined = false;
  int? _remoteUid;
  bool _micMuted = false;
  bool _camOff = false;
  bool _speakerOn = true;
  bool _frontCamera = true;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  Future<void> _initAgora() async {
    // Pedir permissões
    await [Permission.camera, Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: agoraAppId));

    await _engine!.enableVideo();
    await _engine!.startPreview();
    await _engine!.setChannelProfile(
        ChannelProfileType.channelProfileCommunication);

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        if (mounted) setState(() => _localJoined = true);
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        if (mounted) {
          setState(() {
            _remoteUid = remoteUid;
            _remoteJoined = true;
          });
        }
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (mounted) {
          setState(() {
            _remoteUid = null;
            _remoteJoined = false;
          });
        }
      },
      onLeaveChannel: (connection, stats) {
        if (mounted) setState(() => _localJoined = false);
      },
    ));

    await _engine!.joinChannel(
      token: '',
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  Future<void> _toggleMic() async {
    _micMuted = !_micMuted;
    await _engine?.muteLocalAudioStream(_micMuted);
    setState(() {});
  }

  Future<void> _toggleCam() async {
    _camOff = !_camOff;
    await _engine?.muteLocalVideoStream(_camOff);
    setState(() {});
  }

  Future<void> _toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await _engine?.setEnableSpeakerphone(_speakerOn);
    setState(() {});
  }

  Future<void> _switchCamera() async {
    _frontCamera = !_frontCamera;
    await _engine?.switchCamera();
    setState(() {});
  }

  void _hangUp() {
    _engine?.leaveChannel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Vídeo remoto (tela cheia) ──────────────────────────────────
          _remoteJoined && _remoteUid != null
              ? AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine!,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection:
                        RtcConnection(channelId: widget.channelName),
                  ),
                )
              : _buildWaitingScreen(),

          // ── Preview local (canto superior direito) ─────────────────────
          if (_localJoined && !_camOff)
            Positioned(
              top: 48,
              right: 16,
              child: GestureDetector(
                onTap: _switchCamera,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 110,
                    height: 160,
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Header: nome + status ──────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 20),
                    onPressed: _hangUp,
                  ),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF90CAF9),
                    backgroundImage: widget.calleeAvatar != null
                        ? NetworkImage(widget.calleeAvatar!)
                        : null,
                    child: widget.calleeAvatar == null
                        ? Text(
                            widget.calleeName[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.calleeName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _remoteJoined
                            ? 'Em chamada'
                            : 'Chamando...',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Controles inferiores ───────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(
                    icon: _micMuted ? Icons.mic_off : Icons.mic,
                    label: _micMuted ? 'Ativar mic' : 'Mudo',
                    onTap: _toggleMic,
                  ),
                  _controlButton(
                    icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                    label: _speakerOn ? 'Alto-falante' : 'Fone',
                    onTap: _toggleSpeaker,
                  ),
                  // Botão desligar
                  GestureDetector(
                    onTap: _hangUp,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end,
                          color: Colors.white, size: 32),
                    ),
                  ),
                  _controlButton(
                    icon: _camOff ? Icons.videocam_off : Icons.videocam,
                    label: _camOff ? 'Câmera off' : 'Câmera',
                    onTap: _toggleCam,
                  ),
                  _controlButton(
                    icon: Icons.flip_camera_ios,
                    label: 'Virar',
                    onTap: _switchCamera,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: const Color(0xFF90CAF9),
              backgroundImage: widget.calleeAvatar != null
                  ? NetworkImage(widget.calleeAvatar!)
                  : null,
              child: widget.calleeAvatar == null
                  ? Text(
                      widget.calleeName[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              widget.calleeName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aguardando conexão...',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
                color: Color(0xFF0A84FF), strokeWidth: 2),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
