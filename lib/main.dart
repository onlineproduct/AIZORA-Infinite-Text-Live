import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
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
        colorSchemeSeed: const Color(0xFF8B5CF6),
        cardTheme: CardThemeData(color: const Color(0xFF111B2E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
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
  final AudioPlayer _musicPlayer = AudioPlayer();
  Uint8List? _musicBytes;
  String? _musicFileName;
  bool _musicPlaying = false;
  bool _musicLoop = true;
  String? _rtmpsServer;
  String? _streamKey;
  String _statusMessage = 'Animation ready';
  bool _isRunning = true;
  bool _isStreaming = false;
  bool _isBusy = false;
  bool _showSettings = false;
  String _studioTab = 'Home';
  Uint8List? _backgroundImage;
  String _effect = 'Fade';
  bool _autoEffects = true;
  bool _landscapePreview = true;
  double _textFontSize = 34;
  String _fontFamily = 'Roboto';
  String _liveTitle = 'AIZORA TEXT LIVE';
  String _customText = '';
  BoxFit _backgroundFit = BoxFit.cover;
  bool _showTextBorder = true;
  Color _textBorderColor = const Color(0xFF67E8F9);
  double _textBorderWidth = 2;
  double _textBorderRadius = 18;
  Color _textColor = Colors.white;
  Offset _textOffset = Offset.zero;
  bool _canvasPanEnabled = true;
  String _selectedCanvasLayer = 'Text';
  Offset _backgroundOffset = Offset.zero;
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
    _musicPlayer.dispose();
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
                'Server URL ও Stream Key শুধু এই সেশনে মেমরিতে থাকবে; অ্যাপ বন্ধ হলে মুছে যাবে।',
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

  Future<void> _pickMusic() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
      if (!mounted || result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _statusMessage = 'Audio file could not be read.');
        return;
      }
      await _musicPlayer.stop();
      setState(() {
        _musicBytes = bytes;
        _musicFileName = result.files.single.name;
        _musicPlaying = false;
        _statusMessage = 'Music selected: $_musicFileName';
      });
    } catch (error) {
      if (mounted) setState(() => _statusMessage = 'Music selection failed: $error');
    }
  }

  Future<void> _toggleMusic() async {
    final bytes = _musicBytes;
    if (bytes == null || bytes.isEmpty) {
      await _pickMusic();
      return;
    }
    try {
      if (_musicPlaying) {
        await _musicPlayer.pause();
        if (mounted) setState(() => _musicPlaying = false);
      } else {
        await _musicPlayer.setReleaseMode(_musicLoop ? ReleaseMode.loop : ReleaseMode.stop);
        await _musicPlayer.play(BytesSource(bytes));
        if (mounted) setState(() { _musicPlaying = true; _statusMessage = 'Music playback started on this device.'; });
      }
    } catch (error) {
      if (mounted) setState(() { _musicPlaying = false; _statusMessage = 'Music playback failed: $error'; });
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

  Widget _studioCard({required IconData icon, required String title, required String subtitle, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF151D38), Color(0xFF10172A)]),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12))]))]),
          const SizedBox(height: 16),
          child,
        ]),
      ),
    );
  }

  Widget _buildText() {
    final text = _customText.trim().isNotEmpty ? _customText.trim() : _texts[_textIndex % _texts.length];
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
          if (_backgroundImage != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedCanvasLayer = 'Background'),
                onPanUpdate: _canvasPanEnabled && _selectedCanvasLayer == 'Background'
                    ? (details) => setState(() {
                        final box = _broadcastSceneKey.currentContext?.findRenderObject() as RenderBox?;
                        if (box == null || box.size.width == 0 || box.size.height == 0) return;
                        _backgroundOffset = Offset(
                          (_backgroundOffset.dx + details.delta.dx / box.size.width).clamp(-0.4, 0.4).toDouble(),
                          (_backgroundOffset.dy + details.delta.dy / box.size.height).clamp(-0.4, 0.4).toDouble(),
                        );
                      })
                    : null,
                child: Transform.translate(
                  offset: Offset(_backgroundOffset.dx * 280, _backgroundOffset.dy * 180),
                  child: Image.memory(_backgroundImage!, fit: _backgroundFit),
                ),
              ),
            ),
          if (_liveTitle.trim().isNotEmpty)
            Positioned(
              top: 12, left: 12, right: 12,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.58), borderRadius: BorderRadius.circular(20)),
                child: Text(_liveTitle.trim(), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              )),
            ),
          Center(
          child: GestureDetector(
            onTap: () => setState(() => _selectedCanvasLayer = 'Text'),
            onPanStart: (_) => setState(() => _selectedCanvasLayer = 'Text'),
            onPanUpdate: _canvasPanEnabled ? (details) => setState(() {
              final box = _broadcastSceneKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null) {
                final size = box.size;
                final dx = (_textOffset.dx + details.delta.dx / size.width).clamp(-0.42, 0.42).toDouble();
                final dy = (_textOffset.dy + details.delta.dy / size.height).clamp(-0.42, 0.42).toDouble();
                _textOffset = Offset(dx, dy);
              }
            }) : null,
            child: Transform.translate(
              offset: Offset(_textOffset.dx * 280, _textOffset.dy * 180),
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(_textBorderRadius),
                border: _showTextBorder ? Border.all(color: _textBorderColor, width: _textBorderWidth) : null,
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
                      fontSize: _textFontSize,
                      fontFamily: _fontFamily == 'System' ? null : _fontFamily,
                      fontWeight: FontWeight.w800,
                      color: _textColor.withValues(alpha: _effect == 'Fade' ? 0.25 + 0.75 * t : 1),
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
        title: const Text('✦ AIZORA  INFINITE TEXT LIVE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        centerTitle: true,
        backgroundColor: const Color(0xFF101A30),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
            child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF172554)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('YOUR LIVE STUDIO', style: TextStyle(color: Color(0xFF67E8F9), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  const Text('Create • Animate • Go Live', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(_isStreaming ? '● LIVE' : '● READY TO CREATE', style: TextStyle(color: _isStreaming ? const Color(0xFFFB7185) : const Color(0xFF4ADE80), fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final tab in const ['Home', 'Editor', 'Background', 'Animation', 'Music', 'Live Setup', 'Live Control', 'Settings'])
                    ChoiceChip(
                      label: Text(tab),
                      selected: _studioTab == tab,
                      onSelected: (_) => setState(() {
                        _studioTab = tab;
                        if (tab == 'Editor' || tab == 'Animation' || tab == 'Settings') _showSettings = true;
                        if (tab == 'Home' || tab == 'Background' || tab == 'Music' || tab == 'Live Setup' || tab == 'Live Control') _showSettings = false;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_studioTab == 'Background')
                _studioCard(
                  icon: Icons.wallpaper_rounded,
                  title: 'BACKGROUND STUDIO',
                  subtitle: 'ছবি নির্বাচন করুন, প্রিভিউ দেখুন এবং ক্যানভাসে অবস্থান ঠিক করুন',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _backgrounds[_backgroundIndex % _backgrounds.length],
                                  ),
                                ),
                              ),
                              if (_backgroundImage != null)
                                Image.memory(_backgroundImage!, fit: _backgroundFit),
                              if (_backgroundImage == null)
                                const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined, size: 38, color: Colors.white70),
                                      SizedBox(height: 8),
                                      Text('No photo selected', style: TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                ),
                              Positioned(
                                left: 10,
                                right: 10,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _backgroundImage == null ? 'Gradient background' : (_musicFileName == null ? 'Custom background photo' : 'Custom background photo'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _pickBackground,
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        label: Text(_backgroundImage == null ? 'Choose photo from phone' : 'Change background photo'),
                      ),
                      if (_backgroundImage != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _backgroundImage = null;
                            _backgroundOffset = Offset.zero;
                            _selectedCanvasLayer = 'Background';
                            _statusMessage = 'Background photo removed';
                          }),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Remove photo'),
                        ),
                      ],
                      const SizedBox(height: 14),
                      DropdownButtonFormField<BoxFit>(
                        value: _backgroundFit,
                        decoration: const InputDecoration(
                          labelText: 'Photo fit',
                          helperText: 'Cover crops edges • Contain shows full image • Fill stretches',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: BoxFit.cover, child: Text('Cover — fill canvas')),
                          DropdownMenuItem(value: BoxFit.contain, child: Text('Contain — show whole photo')),
                          DropdownMenuItem(value: BoxFit.fill, child: Text('Fill — stretch to canvas')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _backgroundFit = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Select background layer'),
                        subtitle: const Text('এটি চালু থাকলে প্রিভিউতে ব্যাকগ্রাউন্ড টেনে সরানো যাবে'),
                        value: _selectedCanvasLayer == 'Background',
                        onChanged: (value) => setState(() {
                          _selectedCanvasLayer = value ? 'Background' : 'Text';
                        }),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _backgroundOffset = Offset.zero;
                          _selectedCanvasLayer = 'Background';
                          _statusMessage = 'Background position reset';
                        }),
                        icon: const Icon(Icons.center_focus_strong_rounded),
                        label: const Text('Reset background position'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _backgroundImage == null
                            ? 'এখন গ্রেডিয়েন্ট ব্যাকগ্রাউন্ড ব্যবহার হচ্ছে।'
                            : 'Selected: background photo is stored in app memory for this session.',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              if (_studioTab == 'Music')
                _studioCard(
                  icon: Icons.music_note_rounded,
                  title: 'MUSIC STUDIO',
                  subtitle: 'ফোন থেকে অডিও নির্বাচন করুন, চালান ও লুপ করুন',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    OutlinedButton.icon(onPressed: _pickMusic, icon: const Icon(Icons.library_music), label: const Text('Choose audio file')),
                    if (_musicFileName != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_musicFileName!, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Loop music'), value: _musicLoop, onChanged: (v) async { setState(() => _musicLoop = v); if (_musicPlaying) await _musicPlayer.setReleaseMode(v ? ReleaseMode.loop : ReleaseMode.stop); }),
                    Row(children: [Expanded(child: FilledButton.icon(onPressed: _toggleMusic, icon: Icon(_musicPlaying ? Icons.pause : Icons.play_arrow), label: Text(_musicPlaying ? 'Pause music' : 'Play music'))), const SizedBox(width: 8), IconButton(tooltip: 'Stop music', onPressed: () async { await _musicPlayer.stop(); if (mounted) setState(() => _musicPlaying = false); }, icon: const Icon(Icons.stop_circle_outlined))]),
                  ]),
                ),
              if (_studioTab == 'Live Setup')
                _studioCard(icon: Icons.settings_input_antenna, title: 'FACEBOOK LIVE SETUP', subtitle: 'RTMPS credentials are held in memory for this session.', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [OutlinedButton.icon(onPressed: _configureStreamSettings, icon: const Icon(Icons.link), label: const Text('Configure RTMPS Server & Key')), Text(_rtmpsServer == null ? 'RTMPS: Not configured' : 'RTMPS server configured', style: const TextStyle(color: Colors.white70)), const SizedBox(height: 8), const Text('Security: Stream Key is not shown or saved to disk.', style: TextStyle(color: Colors.white54))])),
              if (_studioTab == 'Live Control')
                _studioCard(icon: Icons.live_tv, title: 'LIVE CONTROL', subtitle: 'Live publishing status is reported by the native publisher.', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0B1222), borderRadius: BorderRadius.circular(14)), child: Text(_statusMessage)), const SizedBox(height: 10), FilledButton.icon(onPressed: _isBusy ? null : _isStreaming ? _stopLive : _startLive, icon: Icon(_isStreaming ? Icons.stop_circle : Icons.live_tv), label: Text(_isBusy ? 'Please wait…' : _isStreaming ? 'Stop Live' : 'Start Live'))])),
              if (_studioTab == 'Live Setup' || _studioTab == 'Live Control')
                const SizedBox(height: 8),
              if (_studioTab == 'Animation')
                Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                  const Text('ANIMATION EFFECTS', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    for (final fx in _effects)
                      ChoiceChip(label: Text(fx), selected: _effect == fx,
                        onSelected: (_) => setState(() { _effect = fx; _autoEffects = false; })),
                  ]),
                ]))),
              const SizedBox(height: 14),
              const Align(alignment: Alignment.centerLeft, child: Text('✦  LIVE SCENE PREVIEW', style: TextStyle(color: Color(0xFF67E8F9), fontWeight: FontWeight.bold, letterSpacing: 1.2))),
              const SizedBox(height: 10),
              SizedBox(
                height: (constraints.maxHeight * 0.48).clamp(180.0, 430.0),
                width: double.infinity,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _landscapePreview ? 16 / 9 : 9 / 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _buildText(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Horizontal'), icon: Icon(Icons.stay_current_landscape)),
                  ButtonSegment(value: false, label: Text('Vertical'), icon: Icon(Icons.stay_current_portrait)),
                ],
                selected: {_landscapePreview},
                onSelectionChanged: (selection) => setState(() => _landscapePreview = selection.first),
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
              if (_showSettings)
                SingleChildScrollView(child: Column(children: [
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
              ...[
                const SizedBox(height: 8),
                const Align(alignment: Alignment.centerLeft, child: Text('ANIMATION & TEXT', style: TextStyle(color: Color(0xFF67E8F9), fontWeight: FontWeight.bold, letterSpacing: 1.0))),
                const SizedBox(height: 6),
                Card(
                  color: const Color(0xFF111B2E),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('লাইভে দেখানোর লেখা', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: ValueKey('customText-$_customText'),
                        initialValue: _customText,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: const InputDecoration(hintText: 'এখানে নিজের বাংলা বা English লেখা লিখুন', prefixIcon: Icon(Icons.edit_note), border: OutlineInputBorder(), helperText: 'খালি রাখলে স্বয়ংক্রিয় লেখা চলবে'),
                        onChanged: (v) => setState(() => _customText = v),
                      ),
                      const SizedBox(height: 10),
                      const Text('লাইভ স্ক্রিনের উপরের নাম', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: ValueKey(_liveTitle),
                        initialValue: _liveTitle,
                        maxLength: 40,
                        decoration: const InputDecoration(hintText: 'যেমন: AIZORA TEXT LIVE', prefixIcon: Icon(Icons.title), border: OutlineInputBorder(), counterText: ''),
                        onChanged: (v) => setState(() => _liveTitle = v),
                      ),
                      const SizedBox(height: 8),
                      const Text('লেখার বর্ডার', style: TextStyle(fontWeight: FontWeight.w600)),
                      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('বর্ডার দেখাও'), value: _showTextBorder, onChanged: (v) => setState(() => _showTextBorder = v)),
                      Wrap(spacing: 8, children: [
                        for (final color in [const Color(0xFF67E8F9), Colors.white, const Color(0xFFFBBF24), const Color(0xFFF472B6), const Color(0xFF4ADE80), Colors.red])
                          InkWell(onTap: () => setState(() => _textBorderColor = color), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: _textBorderColor == color ? Colors.white : Colors.white24, width: _textBorderColor == color ? 3 : 1)))),
                      ]),
                      Row(children: [const Text('বর্ডারের পুরুত্ব'), const Spacer(), Text(_textBorderWidth.toStringAsFixed(1))]),
                      Slider(value: _textBorderWidth, min: 1, max: 6, divisions: 10, onChanged: (v) => setState(() => _textBorderWidth = v)),
                      Row(children: [const Text('কোণ গোল করার মাত্রা'), const Spacer(), Text('${_textBorderRadius.round()}')]),
                      Slider(value: _textBorderRadius, min: 0, max: 40, divisions: 8, onChanged: (v) => setState(() => _textBorderRadius = v)),
                      const SizedBox(height: 8),
                      const Text('Canvas Touch & Pan', style: TextStyle(fontWeight: FontWeight.w600)),
                      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Pan ON/OFF'), value: _canvasPanEnabled, onChanged: (v) => setState(() => _canvasPanEnabled = v)),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCanvasLayer,
                        decoration: const InputDecoration(labelText: 'Selected layer', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Text', child: Text('Text')),
                          DropdownMenuItem(value: 'Background', child: Text('Background')),
                        ],
                        onChanged: (v) { if (v != null) setState(() => _selectedCanvasLayer = v); },
                      ),
                      TextButton.icon(onPressed: () => setState(() {
                        if (_selectedCanvasLayer == 'Text') { _textOffset = Offset.zero; }
                        else { _backgroundOffset = Offset.zero; }
                      }), icon: const Icon(Icons.restart_alt), label: const Text('Reset selected layer')),
                      const Text('লেখার অবস্থান', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Text('প্রিভিউতে লেখার উপর আঙুল চেপে ধরে টেনে পছন্দমতো জায়গায় বসান।'),
                      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => setState(() => _textOffset = Offset.zero), icon: const Icon(Icons.center_focus_strong), label: const Text('মাঝখানে ফেরত আনুন'))),
                      const SizedBox(height: 8),
                      const Text('লেখার রং', style: TextStyle(fontWeight: FontWeight.w600)),
                      Wrap(spacing: 8, children: [for (final color in [Colors.white, const Color(0xFF67E8F9), const Color(0xFFFBBF24), const Color(0xFFF472B6), const Color(0xFF4ADE80), Colors.red]) InkWell(onTap: () => setState(() => _textColor = color), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: _textColor == color ? Colors.white : Colors.white24, width: _textColor == color ? 3 : 1))))]),
                      const SizedBox(height: 8),
                      const Text('ব্যাকগ্রাউন্ড ছবি ক্রপ', style: TextStyle(fontWeight: FontWeight.w600)),
                      DropdownButtonFormField<BoxFit>(
                        initialValue: _backgroundFit,
                        decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.crop)),
                        items: const [
                          DropdownMenuItem(value: BoxFit.cover, child: Text('Cover — স্ক্রিন ভরে ক্রপ')),
                          DropdownMenuItem(value: BoxFit.contain, child: Text('Contain — পুরো ছবি দেখাবে')),
                          DropdownMenuItem(value: BoxFit.fill, child: Text('Fill — স্ক্রিন অনুযায়ী টানবে')),
                        ],
                        onChanged: (v) { if (v != null) setState(() => _backgroundFit = v); },
                      ),
                      const SizedBox(height: 8),
                      const Text('Font family', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _fontFamily,
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.font_download_outlined)),
                        items: const [
                          DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                          DropdownMenuItem(value: 'System', child: Text('System default')),
                          DropdownMenuItem(value: 'sans-serif', child: Text('Sans Serif')),
                          DropdownMenuItem(value: 'serif', child: Text('Serif')),
                          DropdownMenuItem(value: 'monospace', child: Text('Monospace')),
                        ],
                        onChanged: (v) { if (v != null) setState(() => _fontFamily = v); },
                      ),
                      const SizedBox(height: 10),
                      Row(children: [const Icon(Icons.format_size, color: Color(0xFF67E8F9)), const SizedBox(width: 8), const Text('Text size'), const Spacer(), Text('${_textFontSize.round()} px')]),
                      Slider(value: _textFontSize, min: 20, max: 52, divisions: 16, label: _textFontSize.round().toString(), onChanged: (v) => setState(() => _textFontSize = v)),
                      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Auto change effects'), subtitle: const Text('প্রতি ৩ সেকেন্ডে ইফেক্ট বদলাবে'), value: _autoEffects, onChanged: (v) => setState(() => _autoEffects = v)),
                      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Auto change text/background'), subtitle: const Text('অ্যানিমেশন চালু বা বন্ধ করুন নিচের বাটন থেকে'), value: _isRunning, onChanged: (v) => setState(() { _isRunning = v; _statusMessage = v ? 'Animation resumed.' : 'Animation paused.'; })),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(alignment: Alignment.centerLeft, child: Text('FACEBOOK LIVE', style: TextStyle(color: Color(0xFF67E8F9), fontWeight: FontWeight.bold, letterSpacing: 1.0))),
                const SizedBox(height: 6),
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
                  ],
                ),
              ],
                ])),
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
          )),
        ),
      ),
    );
  }
}
