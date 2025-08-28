// main.dart
// Flutter app for YTMDesktop Companion Server API v1 (v2 app)
// UI: album thumbnail, seek bar with current/total, like/dislike/mute/volume, and transport controls
// Requires: http, socket_io_client, shared_preferences, flutter_svg (for possible icons)
// Android setup notes at bottom of file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YTMDesktop Companion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '9863');
  String? _token;
  late YTMClient _client;

  YTMState? _state;
  StreamSubscription<YTMState>? _socketSub;
  Timer? _pollTimer; // fallback polling
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _client = YTMClient();
    _loadPrefs();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _pollTimer?.cancel();
    _client.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _hostController.text = prefs.getString('host') ?? '';
    _portController.text = prefs.getString('port') ?? '9863';
    final token = prefs.getString('token');
    if (token != null && _hostController.text.isNotEmpty) {
      await _connect(token: token);
    }
  }

  Future<void> _savePrefs({String? host, String? port, String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    if (host != null) await prefs.setString('host', host);
    if (port != null) await prefs.setString('port', port);
    if (token != null) await prefs.setString('token', token);
  }

  Future<void> _connect({String? token}) async {
    setState(() => _connecting = true);
    try {
      final host = _hostController.text.trim();
      final port = _portController.text.trim();
      if (host.isEmpty) throw Exception('Enter host IPv4 (e.g., 192.168.1.100)');
      _client.configure(host: host, port: int.tryParse(port) ?? 9863, token: token);

      if (token == null) {
        // Do auth flow (request code -> user approves in desktop app -> request token)
        final code = await _client.requestCode(appId: 'xenon_ytmd_companion', appName: 'Xenon\'s YTMD Companion', appVersion: '1.0.0');
        if (!mounted) return;
        final approved = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Approve on Desktop'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A code was requested for this app. Approve the request in YTMDesktop within 30 seconds.'),
                const SizedBox(height: 8),
                SelectableText('Code: $code'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('I\'ve Approved')),
            ],
          ),
        );
        if (approved != true) throw Exception('Authorization cancelled.');
        final tok = await _client.requestToken(appId: 'xenon_ytmd_companion', code: code);
        _token = tok;
        await _savePrefs(host: host, port: port, token: tok);
      } else {
        _token = token;
        await _savePrefs(host: host, port: port);
      }
      // Start socket stream
      _socketSub?.cancel();
      _socketSub = _client.connectSocket().listen((s) {
        setState(() => _state = s);
      }, onError: (e) {
        // Fallback polling if socket fails
        _startPolling();
      });
      // Also get initial state
      final s = await _client.getState();
      setState(() => _state = s);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connect error: $e')));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final s = await _client.getState();
        if (mounted) setState(() => _state = s);
      } catch (_) {}
    });
  }

  String _fmt(int seconds) {
    final d = Duration(seconds: seconds.clamp(0, 359999));
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours;
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hh > 0 ? '$hh:$mm:$ss' : '${d.inMinutes}:$ss';
  }

  int _currentPositionSecs() {
    return (_state?.player.videoProgress ?? 0).round();
  }

  int _durationSecs() {
    return _state?.video?.durationSeconds.round() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final video = _state?.video;
    final isPlaying = _state?.player.trackState == 1; // 1 Playing
    final likeStatus = video?.likeStatus; // -1 unknown, 0 dislike, 1 indifferent, 2 like
    final repeatMode = _state?.player.queue?.repeatMode; // 0 none, 1 all, 2 one

    final albumThumb = (video?.thumbnails.isNotEmpty ?? false) ? video!.thumbnails.first.url : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('YTMDesktop Companion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsSheet(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Album thumbnail
            AspectRatio(
              aspectRatio: 1,
              child: albumThumb != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(albumThumb, fit: BoxFit.cover),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: const Center(child: Icon(Icons.album, size: 72)),
                    ),
            ),
            const SizedBox(height: 12),
            // Seek bar with current time and duration
            Row(
              children: [
                Text(_fmt(_currentPositionSecs()), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                Expanded(
                  child: Slider(
                    value: _durationSecs() == 0 ? 0 : _currentPositionSecs().toDouble().clamp(0, _durationSecs().toDouble()),
                    max: (_durationSecs() == 0 ? 1 : _durationSecs()).toDouble(),
                    onChanged: (v) async {
                      // live preview only; don\'t spam command until user stops
                    },
                    onChangeEnd: (v) async {
                      await _client.command('seekTo', data: v.round());
                    },
                  ),
                ),
                Text(_fmt(_durationSecs()), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
            const SizedBox(height: 8),
            // Like/Dislike/Mute/Volume row
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.thumb_down, color: likeStatus == 0 ? Colors.redAccent : null),
                  onPressed: () => _client.command('toggleDislike'),
                  tooltip: 'Dislike',
                ),
                IconButton(
                  icon: Icon(Icons.thumb_up, color: likeStatus == 2 ? Colors.redAccent : null),
                  onPressed: () => _client.command('toggleLike'),
                  tooltip: 'Like',
                ),
                IconButton(
                  icon: Icon((_state?.player.volume ?? 0) == 0 ? Icons.volume_off : Icons.volume_mute),
                  onPressed: () async {
                    if ((_state?.player.volume ?? 0) == 0) {
                      // If already 0, unmute -> setVolume to 50
                      await _client.command('setVolume', data: 50);
                    } else {
                      await _client.command('mute');
                    }
                  },
                  tooltip: 'Mute/Unmute',
                ),
                Expanded(
                  child: Slider(
                    value: (_state?.player.volume ?? 0).toDouble(),
                    max: 100,
                    onChanged: (v) {},
                    onChangeEnd: (v) => _client.command('setVolume', data: v.round()),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Bottom transport row: shuffle, previous, play/pause, next, repeat mode
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.shuffle),
                  onPressed: () => _client.command('shuffle'),
                  tooltip: 'Shuffle',
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => _client.command('previous'),
                  tooltip: 'Previous',
                ),
                FilledButton.icon(
                  onPressed: () => _client.command('playPause'),
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(isPlaying ? 'Pause' : 'Play'),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => _client.command('next'),
                  tooltip: 'Next',
                ),
                IconButton(
                  icon: Icon(switch (repeatMode) { 2 => Icons.repeat_one, 1 => Icons.repeat, _ => Icons.repeat },
                      color: repeatMode == 0 ? null : Colors.redAccent),
                  onPressed: () async {
                    final next = switch (repeatMode) { 0 => 1, 1 => 2, 2 => 0, _ => 0 };
                    await _client.command('repeatMode', data: next);
                  },
                  tooltip: 'Repeat: none/all/one',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSettingsSheet(BuildContext ctx) async {
    showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Connection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host IPv4 (desktop running YTMDesktop)',
                  hintText: 'e.g., 192.168.1.100',
                ),
                keyboardType: TextInputType.url,
                autofillHints: const [AutofillHints.url],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(labelText: 'Port', hintText: '9863'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _connecting ? null : () => _connect(),
                      icon: const Icon(Icons.link),
                      label: Text(_token == null ? 'Connect & Authorize' : 'Reconnect'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('token');
                      setState(() => _token = null);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token cleared')));
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Clear Token'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_token != null) Text('Connected with token: ${_token!.substring(0, 10)}…'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class YTMClient {
  String _host = '';
  int _port = 9863;
  String? _token;
  io.Socket? _socket;

  void configure({required String host, required int port, String? token}) {
    _host = host;
    _port = port;
    _token = token;
  }

  Uri _base(String path, {bool raw = false}) => Uri.parse('http://$_host:$_port${raw ? '' : '/api/v1'}$path');

  Map<String, String> get _headers => {
        if (_token != null) 'Authorization': _token!,
        'Content-Type': 'application/json',
      };

  Future<String> requestCode({required String appId, required String appName, required String appVersion}) async {
    final res = await http.post(_base('/auth/requestcode'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'appId': appId, 'appName': appName, 'appVersion': appVersion}));
    if (res.statusCode ~/ 100 != 2) throw Exception('requestCode failed: ${res.statusCode} ${res.body}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['code'] as String;
  }

  Future<String> requestToken({required String appId, required String code}) async {
    final res = await http.post(_base('/auth/request'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'appId': appId, 'code': code}));
    if (res.statusCode ~/ 100 != 2) throw Exception('requestToken failed: ${res.statusCode} ${res.body}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final token = body['token'] as String;
    _token = token;
    return token;
  }

  Future<YTMState> getState() async {
    final res = await http.get(_base('/state'), headers: _headers);
    if (res.statusCode ~/ 100 != 2) throw Exception('getState failed: ${res.statusCode} ${res.body}');
    return YTMState.fromJson(jsonDecode(res.body));
  }

  Future<void> command(String command, {Object? data}) async {
    final body = {'command': command, if (data != null) 'data': data};
    final res = await http.post(_base('/command'), headers: _headers, body: jsonEncode(body));
    if (res.statusCode ~/ 100 != 2) throw Exception('command "$command" failed: ${res.statusCode} ${res.body}');
  }

  Stream<YTMState> connectSocket() {
    _socket?.dispose();
    final controller = StreamController<YTMState>.broadcast();
    final url = 'http://$_host:$_port/api/v1/realtime';
    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _token})
          .disableAutoConnect() // manual connect to attach listeners first
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) async {
      // On connect, emit current state via REST, then rely on realtime updates
      try {
        final s = await getState();
        controller.add(s);
      } catch (_) {}
    });

    socket.on('state-update', (data) {
      try {
        controller.add(YTMState.fromJson(data));
      } catch (_) {}
    });

    socket.onError((e) {
      controller.addError(e);
    });

    socket.onDisconnect((_) {
      // consumer may choose to fallback to polling
    });

    socket.connect();
    return controller.stream;
  }

  void dispose() {
    _socket?.dispose();
  }
}

class YTMState {
  final PlayerState player;
  final VideoState? video;
  final String? playlistId;

  YTMState({required this.player, required this.video, required this.playlistId});

  factory YTMState.fromJson(Map<String, dynamic> json) {
    return YTMState(
      player: PlayerState.fromJson(json['player'] as Map<String, dynamic>),
      video: json['video'] == null ? null : VideoState.fromJson(json['video'] as Map<String, dynamic>),
      playlistId: json['playlistId'] as String?,
    );
  }
}

class PlayerState {
  final int trackState; // -1 unknown, 0 paused, 1 playing, 2 buffering
  final double videoProgress; // seconds
  final int volume; // 0..100
  final QueueState? queue;
  final bool adPlaying;

  PlayerState({required this.trackState, required this.videoProgress, required this.volume, required this.queue, required this.adPlaying});

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    return PlayerState(
      trackState: (json['trackState'] as num?)?.toInt() ?? -1,
      videoProgress: (json['videoProgress'] as num?)?.toDouble() ?? 0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      queue: json['queue'] == null ? null : QueueState.fromJson(json['queue'] as Map<String, dynamic>),
      adPlaying: json['adPlaying'] as bool? ?? false,
    );
  }
}

class QueueState {
  final bool autoplay;
  final int? repeatMode; // -1 unk, 0 none, 1 all, 2 one
  final int? selectedItemIndex;

  QueueState({required this.autoplay, required this.repeatMode, required this.selectedItemIndex});

  factory QueueState.fromJson(Map<String, dynamic> json) {
    return QueueState(
      autoplay: json['autoplay'] as bool? ?? false,
      repeatMode: (json['repeatMode'] as num?)?.toInt(),
      selectedItemIndex: (json['selectedItemIndex'] as num?)?.toInt(),
    );
  }
}

class VideoState {
  final String title;
  final String author;
  final String? album;
  final int? likeStatus; // -1 unknown, 0 dislike, 1 neutral, 2 like
  final int durationSeconds;
  final List<Thumb> thumbnails;

  VideoState({required this.title, required this.author, this.album, required this.likeStatus, required this.durationSeconds, required this.thumbnails});

  factory VideoState.fromJson(Map<String, dynamic> json) {
    final thumbs = (json['thumbnails'] as List<dynamic>? ?? const []).map((e) => Thumb.fromJson(e as Map<String, dynamic>)).toList();
    return VideoState(
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      album: json['album'] as String?,
      likeStatus: (json['likeStatus'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      thumbnails: thumbs,
    );
  }
}

class Thumb {
  final String url;
  final int width;
  final int height;

  Thumb({required this.url, required this.width, required this.height});

  factory Thumb.fromJson(Map<String, dynamic> json) => Thumb(
        url: json['url'] as String? ?? '',
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
      );
}

/*
Android setup (AndroidManifest.xml):

<manifest ...>
  <uses-permission android:name="android.permission.INTERNET" />
  <application
      android:usesCleartextTraffic="true"  <!-- Because the API is http:// -->
      ...>
  </application>
</manifest>

Notes:
- Ensure your desktop IP is reachable from the phone (same LAN). Use IPv4, e.g., 192.168.x.x.
- In the Settings (gear icon), enter the host IPv4 and tap "Connect & Authorize". Approve the auth prompt in YTMDesktop within ~30s.
- The app uses Socket.IO realtime updates when available; it falls back to REST polling every 2s otherwise.
- Commands used: playPause, previous, next, seekTo, setVolume, mute, shuffle, repeatMode, toggleLike, toggleDislike.
*/
