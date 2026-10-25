import 'dart:async';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String _liveChannelName = 'aizora.live';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AizoraApp());
}

class AizoraApp extends StatelessWidget {
  const AizoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIZORA Infinite Text Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080D1B),
        colorSchemeSeed: const Color(0xFF38BDF8),
      ),
      home: const AizoraHomePage(),
    );
  }
}

class AizoraHomePage extends StatefulWidget {
  const AizoraHomePage({super.key});

  @override
  State<AizoraHomePage> createState() => _AizoraHomePageState();
}

class _AizoraHomePageState extends State<AizoraHomePage>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _channel = MethodChannel(_liveChannelName);

  final GlobalKey _broadcastSceneKey = GlobalKey();
  String? _rtmpsServer;
  String? _streamKey;
  String _statusMessage = 'Animation ready';
  bool _isRunning = true;
  bool _isStreaming = false;
  bool _isBusy = false;
  bool _showSettings = false;
  Uint8List? _backgroundImage;
  String _effect = 'Fade';
  bool _autoEffects = true;
  static const _effects = ['Fade', 'Slide Up', 'Slide Left', 'Zoom', 'Pulse', 'Rotate', 'Flip', 'Bounce', 'Shake', 'Wave', 'Typewriter', 'Glow'];

  final List<String> _texts = [
    'ভালোবাসা মানে একে অপরের পাশে থাকা।',
    'তোমার হাসিতে আমার পৃথিবী সুন্দর।',
    'আজকের চেষ্টা আগামী দিনের শক্তি।',
    'সুন্দর মুহূর্তগুলো মনে রাখো।',
    'আমার লেখা, আমার অনুভূতি।',
  ];
  final List<List<Color>> _backgrounds = [
    [const Color(0xFF0B1120), const Color(0xFF1D4ED8)],
    [const Color(0xFF111827), const Color(0xFF7C3AED)],
    [const Color(0xFF052E2B), const Color(0xFF059669)],
    [const Color(0xFF431407), const Color(0xFFEA580C)],
  ];

  late final AnimationController _textController;
  int _textIndex = 0;
  int _backgroundIndex = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_isRunning) return;
      setState(() {
        _textIndex = (_textIndex + 1) % _texts.length;
        _backgroundIndex = (_backgroundIndex + 1) % _backgrounds.length;
        if (_autoEffects) _effect = _effects[(_effects.indexOf(_effect) + 1) % _effects.length];
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _configureStreamSettings() async {
    final serverController = TextEditingController(
      text: _rtmpsServer ?? 'rtmps://live-api-s.facebook.com:443/rtmp/',
    );
    final keyController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Facebook Live 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Server URL ও Stream Key শুধুমাত্র এই sesssion-এ memory-এ রাখা হবে।',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: serverController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'RTMPS Server URL'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Stream Key'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () {
              final server = serverController.text.trim();
              final key = keyController.text.trim();
              final uri = Uri.tryParse(server);
              if (uri == null || uri.scheme != 'rtmps' || uri.host.isEmpty || key.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('সঠিক RTMPS URL ও Stream Key দিন।')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );

    if (shouldSave == true && mounted) {
      setState(() {
        _rtmpsServer = serverController.text.trim();
        _streamKey = keyController.text.trim();
        _statusMessage = 'Live configuration stored in memory for this session.';
      });
    }

    serverController.dispose();
    keyController.dispose();
  }

  Future<void> _startLive() async {
    if (_rtmpsServer == null || _streamKey == null || _streamKey!.isEmpty) {
      await _configureStreamSettings();
    }

    if (!mounted || _rtmpsServer == null || _streamKey == null || _streamKey!.isEmpty) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      final bool started = await _channel.invokeMethod<bool>(
        'startLive',
        {
          'serverUrl': _rtmpsServer,
          'streamKey': _streamKey,
          'width': 1280,
          'height': 720,
        },
      ) ?? false;

      if (!mounted) return;
      if (started) {
        setState(() {
          _isStreaming = true;
          _statusMessage = 'Live stream requested. Waiting for native publisher response.';
        });
      } else {
        setState(() {
          _statusMessage = 'Native publisher rejected the start request.';
        });
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Live start failed: ${error.message ?? 'unknown native error'}';
      });
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _stopLive() async {
    setState(() => _isBusy = true);
    try {
      final bool stopped = await _channel.invokeMethod<bool>('stopLive') ?? false;
      if (!mounted) return;
      setState(() {
        _isStreaming = false;
        _statusMessage = stopped
            ? 'Live stream stopped on the native publisher.'
            : 'Stop request sent; native status is still being confirmed.';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Live stop failed: ${error.message ?? 'unknown native error'}';
      });
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _pickBackground() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (!mounted || result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.isEmpty) return;
      setState(() { _backgroundImage = bytes; _statusMessage = 'Background photo selected'; });
    } catch (error) {
      if (mounted) setState(() => _statusMessage = 'Photo selection failed: $error');
    }
  }

  Widget _buildText() {
    final text = _texts[_textIndex % _texts.length];
    final colors = _backgrounds[_backgroundIndex % _backgrounds.length];

    return RepaintBoundary(
      key: _broadcastSceneKey,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Stack(fit: StackFit.expand, children: [
          if (_backgroundImage != null) Image.memory(_backgroundImage!, fit: BoxFit.cover),
          Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  final t = _textController.value;
                  Widget label = Text(
                    _effect == 'Typewriter' ? text.substring(0, (text.length * t).round()) : text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: _effect == 'Fade' ? 0.25 + 0.75 * t : 1),
                      shadows: [
                        Shadow(color: _effect == 'Glow' ? const Color(0xFF67E8F9) : Colors.black,
                            blurRadius: _effect == 'Glow' ? 8 + 24 * t : 10),
                      ],
                    ),
                  );
                  switch (_effect) {
                    case 'Slide Up': label = Transform.translate(offset: Offset(0, 45 * (1-t)), child: label); break;
                    case 'Slide Left': label = Transform.translate(offset: Offset(55 * (1-t), 0), child: label); break;
                    case 'Zoom': label = Transform.scale(scale: 0.65 + 0.35*t, child: label); break;
                    case 'Pulse': label = Transform.scale(scale: 0.9 + 0.2*t, child: label); break;
                    case 'Rotate': label = Transform.rotate(angle: (t-0.5)*0.5, child: label); break;
                    case 'Flip': label = Transform(alignment: Alignment.center, transform: Matrix4.identity()..setEntry(3,2,0.001)..rotateY((1-t)*1.2), child: label); break;
                    case 'Bounce': label = Transform.translate(offset: Offset(0,-22*(1-(2*t-1)*(2*t-1))), child: label); break;
                    case 'Shake': label = Transform.translate(offset: Offset(t<0.5 ? 5*t : -5*(1-t),0), child: label); break;
                    case 'Wave': label = Transform.rotate(angle: (t-0.5)*0.2, child: label); break;
                    default: break;
                  }
                  return label;
                },
              ),
            ),
          ),
        ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIZORA • TEXT LIVE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF101A30),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Align(alignment: Alignment.centerLeft, child: Text('✦  LIVE SCENE PREVIEW', style: TextStyle(color: Color(0xFF67E8F9), fontWeight: FontWeight.bold, letterSpacing: 1.2))),
              const SizedBox(height: 10),
              Expanded(
                child: ClipRRect(borderRadius: BorderRadius.circular(22), child: _buildText()),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(onPressed: _pickBackground, icon: const Icon(Icons.image), label: const Text('Photo')),
                  if (_backgroundImage != null) TextButton(onPressed: () => setState(() => _backgroundImage = null), child: const Text('Clear')),
                  FilledButton.icon(
                    onPressed: _isBusy ? null : _isStreaming ? _stopLive : _startLive,
                    icon: Icon(_isStreaming ? Icons.stop : Icons.live_tv),
                    style: FilledButton.styleFrom(backgroundColor: _isStreaming ? const Color(0xFFB91C1C) : const Color(0xFF0891B2)),
                    label: Text(_isStreaming ? 'Stop Live' : 'Start Live'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showSettings = !_showSettings),
                    icon: const Icon(Icons.tune),
                    label: Text(_showSettings ? 'Hide settings' : 'Settings'),
                  ),
                ],
              ),
              Row(children: [
                const Icon(Icons.animation, color: Color(0xFF67E8F9)),
                const SizedBox(width: 8),
                Expanded(child: DropdownButton<String>(
                  isExpanded: true, value: _effect,
                  items: _effects.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) { if (v != null) setState(() { _effect = v; _autoEffects = false; }); },
                )),
                FilterChip(label: const Text('Auto FX'), selected: _autoEffects,
                    onSelected: (v) => setState(() => _autoEffects = v)),
              ]),
              if (_showSettings) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _configureStreamSettings,
                        icon: const Icon(Icons.link),
                        label: const Text('Set RTMPS'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _isRunning = !_isRunning;
                          _statusMessage = _isRunning ? 'Animation resumed.' : 'Animation paused.';
                        }),
                        icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                        label: Text(_isRunning ? 'Pause animation' : 'Resume animation'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
