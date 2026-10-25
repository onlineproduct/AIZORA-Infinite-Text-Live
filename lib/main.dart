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
  bool _landscapePreview = true;
  double _textFontSize = 34;
  String _liveTitle = 'AIZORA TEXT LIVE';
  String _customText = '';
  BoxFit _backgroundFit = BoxFit.cover;
  bool _showTextBorder = true;
  Color _textBorderColor = const Color(0xFF67E8F9);
  double _textBorderWidth = 2;
  double _textBorderRadius = 18;
  Color _textColor = Colors.white;
  Offset _textOffset = Offset.zero;
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
          if (_backgroundImage != null) Image.memory(_backgroundImage!, fit: _backgroundFit),
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
            onPanUpdate: (details) => setState(() {
              final box = _broadcastSceneKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null) {
                final size = box.size;
                final dx = (_textOffset.dx + details.delta.dx / size.width).clamp(-0.42, 0.42).toDouble();
                final dy = (_textOffset.dy + details.delta.dy / size.height).clamp(-0.42, 0.42).toDouble();
                _textOffset = Offset(dx, dy);
              }
            }),
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
              const SizedBox(height: 8),
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
              if (_showSettings) Row(children: [
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
                      Row(children: [const Text('বর্ডারের পুরুত্ব'), const Spacer(), Text('${_textBorderWidth.toStringAsFixed(1)}')]),
                      Slider(value: _textBorderWidth, min: 1, max: 6, divisions: 10, onChanged: (v) => setState(() => _textBorderWidth = v)),
                      Row(children: [const Text('কোণ গোল করার মাত্রা'), const Spacer(), Text('${_textBorderRadius.round()}')]),
                      Slider(value: _textBorderRadius, min: 0, max: 40, divisions: 8, onChanged: (v) => setState(() => _textBorderRadius = v)),
                      const SizedBox(height: 8),
                      const Text('লেখার অবস্থান', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Text('প্রিভিউতে লেখার উপর আঙুল চেপে ধরে টেনে পছন্দমতো জায়গায় বসান।'),
                      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => setState(() => _textOffset = Offset.zero), icon: const Icon(Icons.center_focus_strong), label: const Text('মাঝখানে ফেরত আনুন'))),
                      const SizedBox(height: 8),
                      const Text('লেখার রং', style: TextStyle(fontWeight: FontWeight.w600)),
                      Wrap(spacing: 8, children: [for (final color in [Colors.white, const Color(0xFF67E8F9), const Color(0xFFFBBF24), const Color(0xFFF472B6), const Color(0xFF4ADE80), Colors.red]) InkWell(onTap: () => setState(() => _textColor = color), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: _textColor == color ? Colors.white : Colors.white24, width: _textColor == color ? 3 : 1))))]),
                      const SizedBox(height: 8),
                      const Text('ব্যাকগ্রাউন্ড ছবি ক্রপ', style: TextStyle(fontWeight: FontWeight.w600)),
                      DropdownButtonFormField<BoxFit>(
                        value: _backgroundFit,
                        decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.crop)),
                        items: const [
                          DropdownMenuItem(value: BoxFit.cover, child: Text('Cover — স্ক্রিন ভরে ক্রপ')),
                          DropdownMenuItem(value: BoxFit.contain, child: Text('Contain — পুরো ছবি দেখাবে')),
                          DropdownMenuItem(value: BoxFit.fill, child: Text('Fill — স্ক্রিন অনুযায়ী টানবে')),
                        ],
                        onChanged: (v) { if (v != null) setState(() => _backgroundFit = v); },
                      ),
                      const SizedBox(height: 8),
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
