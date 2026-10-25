import 'dart:async';
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
  final double _textBorderRadius = 18;
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

  // ignore: unused_element
  Widget _dashboardMetric(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1222),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF34456D)),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF67E8F9), size: 21),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ])),
      ]),
    );
  }

  // ignore: unused_element
  Widget _quickAction(String label, IconData icon, String tab) {
    return OutlinedButton.icon(
      onPressed: () => setState(() {
        _studioTab = tab;
      }),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  // ignore: unused_element
  Widget _buildNavigationPanel() {
    const items = <(String, String, IconData)>[
      ('Home', 'Home', Icons.dashboard_rounded),
      ('Editor', 'Text Editor', Icons.text_fields_rounded),
      ('Live Control', 'Go Live', Icons.live_tv_rounded),
      ('Settings', 'Settings', Icons.tune_rounded),
    ];
    return _studioCard(
      icon: Icons.apps_rounded,
      title: 'STUDIO NAVIGATION',
      subtitle: 'একটি স্ক্রিন বেছে নিন',
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth < 340 ? 2 : 4;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() {
                    _studioTab = item.$1;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: _studioTab == item.$1
                          ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)])
                          : const LinearGradient(colors: [Color(0xFF101A30), Color(0xFF151D38)]),
                      border: Border.all(color: _studioTab == item.$1 ? const Color(0xFF8B7CFF) : const Color(0xFF34456D)),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(item.$3, color: _studioTab == item.$1 ? Colors.white : const Color(0xFF9FB0D8), size: 22),
                      const SizedBox(height: 6),
                      Text(item.$2, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, fontWeight: _studioTab == item.$1 ? FontWeight.w800 : FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: const Color(0xFF10172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshSheet) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.88,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(9))),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.tune_rounded, color: Color(0xFF67E8F9)),
                  SizedBox(width: 10),
                  Text('AIZORA SETTINGS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ]),
              ),
              // Sticky canvas controls stay visible while the settings list scrolls.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17243D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF67E8F9).withValues(alpha: 0.65)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.crop_landscape_rounded, color: Color(0xFF67E8F9)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('CANVAS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: true, label: Text('Horizontal')),
                          ButtonSegment(value: false, label: Text('Vertical')),
                        ],
                        selected: {_landscapePreview},
                        onSelectionChanged: (s) {
                          setState(() => _landscapePreview = s.first);
                          refreshSheet(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _studioCard(
                      icon: Icons.text_fields_rounded,
                      title: 'TEXT & CANVAS',
                      subtitle: 'লেখা, ফন্ট, রং, বর্ডার ও দিক',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TextFormField(
                          key: ValueKey('settings-text-$_customText'),
                          initialValue: _customText,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 500,
                          decoration: const InputDecoration(labelText: 'লাইভে দেখানোর লেখা', hintText: 'বাংলা বা English লিখুন', border: OutlineInputBorder()),
                          onChanged: (v) { setState(() => _customText = v); refreshSheet(() {}); },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: ValueKey('settings-title-$_liveTitle'),
                          initialValue: _liveTitle,
                          maxLength: 40,
                          decoration: const InputDecoration(labelText: 'উপরের শিরোনাম', border: OutlineInputBorder(), counterText: ''),
                          onChanged: (v) { setState(() => _liveTitle = v); refreshSheet(() {}); },
                        ),
                        Row(children: [const Text('Text size'), const Spacer(), Text('${_textFontSize.round()} px')]),
                        Slider(value: _textFontSize, min: 16, max: 64, divisions: 24, onChanged: (v) { setState(() => _textFontSize = v); refreshSheet(() {}); }),
                        const Text('Font'),
                        DropdownButtonFormField<String>(
                          initialValue: _fontFamily,
                          items: const [
                            DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                            DropdownMenuItem(value: 'System', child: Text('System default')),
                            DropdownMenuItem(value: 'sans-serif', child: Text('Sans Serif')),
                            DropdownMenuItem(value: 'serif', child: Text('Serif')),
                            DropdownMenuItem(value: 'monospace', child: Text('Monospace')),
                          ],
                          onChanged: (v) { if (v != null) { setState(() => _fontFamily = v); refreshSheet(() {}); } },
                        ),
                        const SizedBox(height: 10),
                        const Text('Text color'),
                        Wrap(spacing: 10, children: [
                          for (final color in [Colors.white, const Color(0xFF67E8F9), const Color(0xFFFBBF24), const Color(0xFFF472B6), const Color(0xFF4ADE80), Colors.red])
                            IconButton(onPressed: () { setState(() => _textColor = color); refreshSheet(() {}); }, icon: Icon(Icons.circle, color: color), tooltip: 'Select text color'),
                        ]),
                        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Show text border'), value: _showTextBorder, onChanged: (v) { setState(() => _showTextBorder = v); refreshSheet(() {}); }),
                        const Text('Border color'),
                        Wrap(spacing: 10, children: [
                          for (final color in [const Color(0xFF67E8F9), Colors.white, const Color(0xFFFBBF24), const Color(0xFFF472B6), const Color(0xFF4ADE80), Colors.red])
                            IconButton(onPressed: () { setState(() => _textBorderColor = color); refreshSheet(() {}); }, icon: Icon(Icons.circle, color: color), tooltip: 'Select border color'),
                        ]),
                        Row(children: [const Text('Border width'), const Spacer(), Text(_textBorderWidth.toStringAsFixed(1))]),
                        Slider(value: _textBorderWidth, min: 1, max: 6, divisions: 10, onChanged: (v) { setState(() => _textBorderWidth = v); refreshSheet(() {}); }),
                        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Canvas drag ON/OFF'), value: _canvasPanEnabled, onChanged: (v) { setState(() => _canvasPanEnabled = v); refreshSheet(() {}); }),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCanvasLayer,
                          decoration: const InputDecoration(labelText: 'Selected canvas layer'),
                          items: const [DropdownMenuItem(value: 'Text', child: Text('Text')), DropdownMenuItem(value: 'Background', child: Text('Background'))],
                          onChanged: (v) { if (v != null) { setState(() => _selectedCanvasLayer = v); refreshSheet(() {}); } },
                        ),
                        TextButton.icon(onPressed: () { setState(() { if (_selectedCanvasLayer == 'Text') { _textOffset = Offset.zero; } else { _backgroundOffset = Offset.zero; } }); refreshSheet(() {}); }, icon: const Icon(Icons.restart_alt), label: const Text('Reset selected layer position')),
                        DropdownButtonFormField<BoxFit>(
                          initialValue: _backgroundFit,
                          decoration: const InputDecoration(labelText: 'Background image fit'),
                          items: const [
                            DropdownMenuItem(value: BoxFit.cover, child: Text('Cover')),
                            DropdownMenuItem(value: BoxFit.contain, child: Text('Contain')),
                            DropdownMenuItem(value: BoxFit.fill, child: Text('Fill')),
                          ],
                          onChanged: (v) { if (v != null) { setState(() => _backgroundFit = v); refreshSheet(() {}); } },
                        ),
                        const SizedBox(height: 8),
                        const Text('দিক পরিবর্তনের জন্য উপরের স্থায়ী CANVAS বার ব্যবহার করুন.',
                          style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ]),
                    ),
                    _studioCard(
                      icon: Icons.wallpaper_rounded,
                      title: 'BACKGROUND',
                      subtitle: 'নিজের ছবি বেছে নিন',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        OutlinedButton.icon(onPressed: () async { await _pickBackground(); refreshSheet(() {}); }, icon: const Icon(Icons.photo_library_outlined), label: const Text('Choose background image')),
                        if (_backgroundImage != null) TextButton.icon(onPressed: () { setState(() { _backgroundImage = null; _backgroundOffset = Offset.zero; }); refreshSheet(() {}); }, icon: const Icon(Icons.delete_outline), label: const Text('Remove background image')),
                      ]),
                    ),
                    _studioCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'ANIMATION EFFECTS',
                      subtitle: 'ইফেক্ট বেছে নিন বা অটো চালু রাখুন',
                      child: Column(children: [
                        DropdownButtonFormField<String>(
                          initialValue: _effect,
                          decoration: const InputDecoration(labelText: 'Animation effect'),
                          items: _effects.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) { if (v != null) { setState(() { _effect = v; _autoEffects = false; }); refreshSheet(() {}); } },
                        ),
                        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Auto change effects'), value: _autoEffects, onChanged: (v) { setState(() => _autoEffects = v); refreshSheet(() {}); }),
                        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Auto change text/background'), value: _isRunning, onChanged: (v) { setState(() { _isRunning = v; _statusMessage = v ? 'Animation resumed.' : 'Animation paused.'; }); refreshSheet(() {}); }),
                      ]),
                    ),
                    _studioCard(
                      icon: Icons.music_note_rounded,
                      title: 'MUSIC',
                      subtitle: _musicFileName ?? 'ফোন থেকে গান নির্বাচন করুন',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        OutlinedButton.icon(onPressed: () async { await _pickMusic(); refreshSheet(() {}); }, icon: const Icon(Icons.folder_open_rounded), label: Text(_musicFileName == null ? 'Choose music' : 'Change music')),
                        FilledButton.icon(onPressed: () async { await _toggleMusic(); refreshSheet(() {}); }, icon: Icon(_musicPlaying ? Icons.pause : Icons.play_arrow), label: Text(_musicPlaying ? 'Pause music' : 'Play music')),
                        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Loop music'), value: _musicLoop, onChanged: (v) async { setState(() => _musicLoop = v); if (_musicPlaying) await _musicPlayer.setReleaseMode(v ? ReleaseMode.loop : ReleaseMode.stop); refreshSheet(() {}); }),
                        const Text('গান বর্তমানে এই ডিভাইসে বাজে; Facebook Live-এ অডিও যাচ্ছে কি না আলাদাভাবে পরীক্ষা দরকার।', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ]),
                    ),
                    _studioCard(
                      icon: Icons.settings_input_antenna_rounded,
                      title: 'FACEBOOK LIVE SETUP',
                      subtitle: _rtmpsServer == null ? 'RTMPS not configured' : 'RTMPS server configured',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        OutlinedButton.icon(onPressed: _configureStreamSettings, icon: const Icon(Icons.link), label: const Text('Configure RTMPS server & key')),
                        const Text('Stream key এই সেশনে মেমরিতে থাকে; অ্যাপ বন্ধ হলে মুছে যায়।', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ]),
                    ),
                    _studioCard(
                      icon: Icons.live_tv_rounded,
                      title: 'LIVE CONTROL',
                      subtitle: 'লাইভ স্ট্যাটাস ও কন্ট্রোল',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(_statusMessage, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _isBusy ? null : () async { if (_isStreaming) { await _stopLive(); } else { await _startLive(); } refreshSheet(() {}); },
                          icon: Icon(_isStreaming ? Icons.stop_circle : Icons.live_tv),
                          label: Text(_isBusy ? 'Please wait…' : _isStreaming ? 'Stop Live' : 'Start Live'),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1B),
      appBar: AppBar(
        title: const Text('AIZORA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: const Color(0xFF101A30),
        foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Settings', onPressed: _openSettings, icon: const Icon(Icons.tune_rounded)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('INFINITE TEXT LIVE', style: TextStyle(color: Color(0xFF67E8F9), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _isStreaming ? const Color(0xFF7F1D1D) : const Color(0xFF12352D), borderRadius: BorderRadius.circular(20)),
                    child: Text(_isStreaming ? '● LIVE' : '● READY', style: TextStyle(color: _isStreaming ? const Color(0xFFFDA4AF) : const Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: AspectRatio(
                      aspectRatio: _landscapePreview ? 16 / 9 : 9 / 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: _buildText(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _isRunning = !_isRunning), icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded), label: Text(_isRunning ? 'Pause animation' : 'Resume animation'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton.icon(onPressed: _openSettings, icon: const Icon(Icons.tune_rounded), label: const Text('Settings'))),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isBusy ? null : _isStreaming ? _stopLive : _startLive,
                  style: FilledButton.styleFrom(backgroundColor: _isStreaming ? const Color(0xFFB91C1C) : const Color(0xFF7C3AED)),
                  icon: Icon(_isStreaming ? Icons.stop_circle_outlined : Icons.wifi_tethering_rounded),
                  label: Text(_isBusy ? 'Please wait…' : _isStreaming ? 'Stop Facebook Live' : 'Go Live'),
                ),
              ),
              const SizedBox(height: 8),
              Text(_statusMessage, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
