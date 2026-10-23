import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class LetterFadeLoopText extends StatefulWidget {
  const LetterFadeLoopText({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<LetterFadeLoopText> createState() => _LetterFadeLoopTextState();
}

class _LetterFadeLoopTextState extends State<LetterFadeLoopText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.text.characters.length * 110).clamp(1600, 7000)),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant LetterFadeLoopText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.duration = Duration(
        milliseconds: (widget.text.characters.length * 110).clamp(1600, 7000),
      );
      _controller
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characters = widget.text.characters.toList();
    if (characters.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value * (characters.length + 1);
        return Text.rich(
          TextSpan(
            children: List.generate(characters.length, (index) {
              final opacity = (progress - index).clamp(0.0, 1.0);
              return TextSpan(
                text: characters[index],
                style: widget.style.copyWith(
                  color: widget.style.color?.withValues(alpha: opacity),
                ),
              );
            }),
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }
}

void main() {
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
        scaffoldBackgroundColor: const Color(0xFF0A1020),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B8DEF),
          brightness: Brightness.dark,
        ),
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

class _AizoraHomePageState extends State<AizoraHomePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  final Map<String, List<List<Color>>> _themePalettes = {
    'নীল': [
      [const Color(0xFF0B1120), const Color(0xFF1D4ED8)],
      [const Color(0xFF111827), const Color(0xFF2563EB)],
    ],
    'বেগুনি': [
      [const Color(0xFF111827), const Color(0xFF7C3AED)],
      [const Color(0xFF312E81), const Color(0xFF9333EA)],
    ],
    'সবুজ': [
      [const Color(0xFF052E2B), const Color(0xFF059669)],
      [const Color(0xFF1F2937), const Color(0xFF14B8A6)],
    ],
    'সূর্যাস্ত': [
      [const Color(0xFF431407), const Color(0xFFEA580C)],
      [const Color(0xFF1F1B4D), const Color(0xFFE11D48)],
    ],
    'কালো': [
      [const Color(0xFF000000), const Color(0xFF27272A)],
      [const Color(0xFF09090B), const Color(0xFF18181B)],
    ],
  };
  final Map<String, Color?> _textBackgroundChoices = {
    'বক্স নেই': null,
    'কালো': const Color(0xFF000000),
    'সাদা': const Color(0xFFFFFFFF),
    'নীল': const Color(0xFF1D4ED8),
    'লাল': const Color(0xFFDC2626),
    'সবুজ': const Color(0xFF059669),
    'বেগুনি': const Color(0xFF7C3AED),
  };

  final Map<String, List<String>> _categories = {
    'ভালোবাসা': ['ভালোবাসা মানে একে অপরের পাশে থাকা।', 'তোমার হাসিতে আমার পৃথিবী সুন্দর।', 'সত্যিকারের ভালোবাসা যত্নে বেঁচে থাকে।', 'কিছু অনুভূতি শব্দের চেয়েও গভীর।'],
    'কষ্ট': ['সব নীরবতার পেছনে একটি গল্প থাকে।', 'সময় অনেক কিছু শেখায়।', 'মন খারাপের দিনও একদিন কেটে যায়।', 'কিছু স্মৃতি চুপচাপ থেকে যায়।'],
    'মোটিভেশন': ['আজকের চেষ্টা আগামী দিনের শক্তি।', 'হাল ছেড়ো না, সামনে এগিয়ে যাও।', 'ছোট পদক্ষেপও বড় পরিবর্তন আনে।', 'নিজের ওপর বিশ্বাস রাখো।'],
    'ইসলামিক': ['আল্লাহর রহমত থেকে নিরাশ হয়ো না।', 'সৎ পথে চলার চেষ্টা করো।', 'কৃতজ্ঞতা হৃদয়ে শান্তি আনে।', 'ধৈর্য ও দোয়া জীবনের সঙ্গী।'],
    'জীবন': ['জীবন প্রতিদিন নতুন কিছু শেখায়।', 'সুন্দর মুহূর্তগুলো মনে রাখো।', 'নিজের গতিতে এগিয়ে যাও।', 'প্রতিটি সকাল একটি নতুন সুযোগ।'],
    'বন্ধুত্ব': ['সত্যিকারের বন্ধু পাশে থাকে।', 'বন্ধুত্ব মানে বিশ্বাস।', 'ভালো বন্ধু জীবনের উপহার।', 'একটি হাসি বন্ধুত্বকে উজ্জ্বল করে।'],
    'নিজের লেখা': ['এখানে আপনার নিজের লেখা যোগ করুন।'],
  };
  final List<String> _animationNames = ['Fade', 'Slide', 'Scale', 'Letter Fade In/Out', 'Typewriter', 'Bounce', 'Rotate', 'Zoom Pulse'];
  String _selectedCategory = 'ভালোবাসা';
  String _selectedAnimation = 'Fade';
  String _selectedFontWeight = 'বোল্ড';
  String _selectedFontFamily = 'সাধারণ';
  bool _italicText = false;
  double _textFontSize = 34;
  String _selectedTheme = 'নীল';
  String _selectedTextBackground = 'কালো';
  double _textBackgroundOpacity = 0.72;
  Color _customGradientStart = const Color(0xFF0B1120);
  Color _customGradientEnd = const Color(0xFF1D4ED8);
  Color _customTextColor = Colors.white;
  Color _customBoxColor = const Color(0xFF000000);
  bool _useCustomTextColor = false;

  List<List<Color>> get _activeBackgrounds => _selectedTheme == 'কাস্টম'
      ? [
          [_customGradientStart, _customGradientEnd],
          [_customGradientEnd, _customGradientStart],
        ]
      : _themePalettes[_selectedTheme]!;

  Color? get _activeTextBoxColor => _selectedTextBackground == 'কাস্টম'
      ? _customBoxColor
      : _textBackgroundChoices[_selectedTextBackground];

  Color get _activeTextColor => _useCustomTextColor
      ? _customTextColor
      : (_selectedTextBackground == 'সাদা' ? Colors.black : Colors.white);
  List<String> get _texts => _categories[_selectedCategory]!;


  String? _selectedMusicPath;
  String _statusMessage = 'Ready';
  bool _isRunning = false;
  bool _isMusicPlaying = false;
  int _backgroundIndex = 0;
  int _textIndex = 0;

  Timer? _backgroundTimer;
  Timer? _textTimer;

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _startTimers();
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    _textTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimers() {
    _backgroundTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isRunning) {
        return;
      }
      setState(() {
        _backgroundIndex = (_backgroundIndex + 1) % _activeBackgrounds.length;
      });
    });

    _textTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isRunning) {
        return;
      }
      setState(() {
        _textIndex = (_textIndex + 1) % _texts.length;
        // Keep the animation selected by the user.
      });
    });
  }

  Future<Color?> _chooseColor(String title, Color initialColor) async {
    var red = initialColor.red.toDouble();
    var green = initialColor.green.toDouble();
    var blue = initialColor.blue.toDouble();

    return showDialog<Color>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selected = Color.fromARGB(255, red.round(), green.round(), blue.round());
          Widget channelSlider(String label, double value, ValueChanged<double> onChanged) {
            return Row(
              children: [
                SizedBox(width: 54, child: Text(label)),
                Expanded(
                  child: Slider(
                    value: value,
                    min: 0,
                    max: 255,
                    divisions: 255,
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(width: 34, child: Text(value.round().toString())),
              ],
            );
          }

          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  channelSlider('লাল', red, (value) => setDialogState(() => red = value)),
                  channelSlider('সবুজ', green, (value) => setDialogState(() => green = value)),
                  channelSlider('নীল', blue, (value) => setDialogState(() => blue = value)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('বাতিল'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('নির্বাচন'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showThemeCustomizer() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget colorOption(String label, Color color, Future<Color?> Function() choose) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white54),
                ),
              ),
              trailing: const Icon(Icons.color_lens_outlined),
              onTap: () async {
                final picked = await choose();
                if (picked == null || !mounted) return;
                setState(() {
                  if (label == 'ব্যাকগ্রাউন্ডের প্রথম রং') _customGradientStart = picked;
                  if (label == 'ব্যাকগ্রাউন্ডের দ্বিতীয় রং') _customGradientEnd = picked;
                  if (label == 'টেক্সটের রং') {
                    _customTextColor = picked;
                    _useCustomTextColor = true;
                  }
                  if (label == 'টেক্সট বক্সের রং') {
                    _customBoxColor = picked;
                    _selectedTextBackground = 'কাস্টম';
                  }
                  _selectedTheme = 'কাস্টম';
                });
                setDialogState(() {});
              },
            );
          }

          return AlertDialog(
            title: const Text('থিম কাস্টমাইজ করুন'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  colorOption('ব্যাকগ্রাউন্ডের প্রথম রং', _customGradientStart,
                      () => _chooseColor('প্রথম ব্যাকগ্রাউন্ড রং', _customGradientStart)),
                  colorOption('ব্যাকগ্রাউন্ডের দ্বিতীয় রং', _customGradientEnd,
                      () => _chooseColor('দ্বিতীয় ব্যাকগ্রাউন্ড রং', _customGradientEnd)),
                  colorOption('টেক্সটের রং', _customTextColor,
                      () => _chooseColor('টেক্সটের রং', _customTextColor)),
                  colorOption('টেক্সট বক্সের রং', _customBoxColor,
                      () => _chooseColor('টেক্সট বক্সের রং', _customBoxColor)),
                  const SizedBox(height: 8),
                  const Text('প্রতিটি রঙের লাল, সবুজ ও নীল মান বদলে নিজের রং তৈরি করুন।'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('বন্ধ করুন'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _setStatus(String value) {
    setState(() {
      _statusMessage = value;
    });
  }

  void _toggleRun() {
    setState(() {
      _isRunning = !_isRunning;
    });

    if (_isRunning) {
      _setStatus('Animation started.');
      if (_selectedMusicPath != null && !_isMusicPlaying) {
        _playSelectedMusic();
      }
    } else {
      _setStatus('Animation stopped.');
      if (_isMusicPlaying) {
        _audioPlayer.pause();
        setState(() {
          _isMusicPlaying = false;
        });
      }
    }
  }

  Future<void> _pickMusic() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        _setStatus('No music file was selected.');
        return;
      }

      final filePath = result.files.single.path!;
      final lowerPath = filePath.toLowerCase();
      final supportedExtensions = ['.mp3', '.wav', '.m4a', '.aac', '.ogg'];
      final isSupported = supportedExtensions.any((ext) => lowerPath.endsWith(ext));

      if (!isSupported) {
        _setStatus('Unsupported file type. Please choose MP3, WAV, M4A, AAC, or OGG.');
        return;
      }

      final file = File(filePath);
      if (!file.existsSync()) {
        _setStatus('Selected audio file could not be found.');
        return;
      }

      setState(() {
        _selectedMusicPath = filePath;
      });

      _setStatus('Music selected: ${file.path.split(Platform.pathSeparator).last}');

      if (_isRunning) {
        await _playSelectedMusic();
      }
    } catch (_) {
      _setStatus('Unable to open the selected music file.');
    }
  }

  Future<void> _toggleMusic() async {
    if (_selectedMusicPath == null) {
      _setStatus('Select a music file before playing.');
      return;
    }

    if (_isMusicPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isMusicPlaying = false;
      });
      _setStatus('Music paused.');
      return;
    }

    await _playSelectedMusic();
  }

  Future<void> _playSelectedMusic() async {
    if (_selectedMusicPath == null) {
      return;
    }

    try {
      final file = File(_selectedMusicPath!);
      if (!file.existsSync()) {
        _setStatus('Selected music file is missing or inaccessible.');
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.setSourceDeviceFile(_selectedMusicPath!);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.resume();

      setState(() {
        _isMusicPlaying = true;
      });

      _setStatus('Music playing in a loop.');
    } catch (_) {
      setState(() {
        _isMusicPlaying = false;
      });
      _setStatus('Could not play the selected music file.');
    }
  }

  Future<void> _addCustomText() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('নিজের লেখা যোগ করুন'),
        content: TextField(controller: controller, maxLines: 4, maxLength: 300),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('যোগ করুন')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || value == null || value.isEmpty) return;
    setState(() {
      _categories['নিজের লেখা']!.add(value);
      _selectedCategory = 'নিজের লেখা';
      _textIndex = _categories['নিজের লেখা']!.length - 1;
    });
  }

  Widget _buildAnimatedText() {
    final activeText = _texts[_textIndex];
    final style = TextStyle(
      fontSize: _textFontSize,
      fontWeight: switch (_selectedFontWeight) {
        'পাতলা' => FontWeight.w400,
        'মাঝারি' => FontWeight.w600,
        'অতিরিক্ত বোল্ড' => FontWeight.w900,
        _ => FontWeight.w800,
      },
      fontStyle: _italicText ? FontStyle.italic : FontStyle.normal,
      fontFamily: switch (_selectedFontFamily) {
        'সেরিফ' => 'serif',
        'মনোস্পেস' => 'monospace',
        _ => null,
      },
      color: _activeTextColor,
      letterSpacing: 1.2,
      height: 1.2,
    );

    switch (_selectedAnimation) {
      case 'Fade':
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 900),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: Text(activeText, key: ValueKey<String>(activeText), textAlign: TextAlign.center, style: style),
        );
      case 'Slide':
        return TweenAnimationBuilder<double>(
          key: ValueKey('slide-$activeText'),
          tween: Tween(begin: 36, end: 0),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, value),
            child: Opacity(opacity: (1 - value / 36).clamp(0.0, 1.0), child: child),
          ),
          child: Text(activeText, textAlign: TextAlign.center, style: style),
        );
      case 'Scale':
        return TweenAnimationBuilder<double>(
          key: ValueKey('scale-$activeText'),
          tween: Tween(begin: 0.65, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: Text(activeText, textAlign: TextAlign.center, style: style),
        );
      case 'Letter Fade In/Out':
        return LetterFadeLoopText(
          key: ValueKey('letters-$activeText'),
          text: activeText,
          style: style,
        );
      case 'Typewriter':
        return TweenAnimationBuilder<double>(
          key: ValueKey('typewriter-$activeText'),
          tween: Tween(begin: 0, end: activeText.characters.length.toDouble()),
          duration: Duration(milliseconds: (activeText.characters.length * 90).clamp(900, 6000)),
          curve: Curves.linear,
          builder: (context, value, child) {
            final chars = activeText.characters.toList();
            final visibleCount = value.floor().clamp(0, chars.length);
            return Text(chars.take(visibleCount).join(), textAlign: TextAlign.center, style: style);
          },
        );
      case 'Bounce':
        return TweenAnimationBuilder<double>(
          key: ValueKey('bounce-$activeText'),
          tween: Tween(begin: -45, end: 0),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.bounceOut,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, value),
            child: child,
          ),
          child: Text(activeText, textAlign: TextAlign.center, style: style),
        );
      case 'Rotate':
        return TweenAnimationBuilder<double>(
          key: ValueKey('rotate-$activeText'),
          tween: Tween(begin: -0.18, end: 0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Transform.rotate(angle: value, child: child),
          child: Text(activeText, textAlign: TextAlign.center, style: style),
        );
      case 'Zoom Pulse':
        return TweenAnimationBuilder<double>(
          key: ValueKey('pulse-$activeText'),
          tween: Tween(begin: 0.5, end: 1.0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.elasticOut,
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: Text(activeText, textAlign: TextAlign.center, style: style),
        );
      default:
        return Text(activeText, textAlign: TextAlign.center, style: style);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _activeBackgrounds[_backgroundIndex % _activeBackgrounds.length];
    final activeAnimation = _selectedAnimation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        return Scaffold(
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(isWide ? 24 : 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'AIZORA',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _isRunning ? 'Running' : 'Stopped',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<String>(
                          value: _selectedCategory,
                          items: _categories.keys.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() { _selectedCategory = value; _textIndex = 0; });
                          },
                        ),
                        DropdownButton<String>(
                          value: _selectedAnimation,
                          items: _animationNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() { _selectedAnimation = value; });
                          },
                        ),
                        DropdownButton<String>(
                          value: _selectedFontWeight,
                          items: ['পাতলা', 'মাঝারি', 'বোল্ড', 'অতিরিক্ত বোল্ড']
                              .map((name) => DropdownMenuItem(value: name, child: Text('ফন্ট: $name')))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedFontWeight = value);
                          },
                        ),
                        DropdownButton<String>(
                          value: _selectedFontFamily,
                          items: ['সাধারণ', 'সেরিফ', 'মনোস্পেস']
                              .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedFontFamily = value);
                          },
                        ),
                        IconButton(
                          tooltip: _italicText ? 'ইটালিক বন্ধ করুন' : 'ইটালিক করুন',
                          onPressed: () => setState(() => _italicText = !_italicText),
                          icon: Icon(_italicText ? Icons.format_italic : Icons.format_italic_outlined),
                        ),
                        DropdownButton<String>(
                          value: _selectedTheme,
                          items: [..._themePalettes.keys, 'কাস্টম'].map((name) => DropdownMenuItem(value: name, child: Text('থিম: $name'))).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedTheme = value;
                              _backgroundIndex = 0;
                            });
                          },
                        ),
                        DropdownButton<String>(
                          value: _selectedTextBackground,
                          items: [..._textBackgroundChoices.keys, 'কাস্টম'].map((name) => DropdownMenuItem(value: name, child: Text('টেক্সট: $name'))).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedTextBackground = value;
                              if (value != 'কাস্টম') _useCustomTextColor = false;
                            });
                          },
                        ),
                        IconButton(
                          tooltip: 'থিম কাস্টমাইজ করুন',
                          onPressed: _showThemeCustomizer,
                          icon: const Icon(Icons.palette_outlined),
                        ),
                        IconButton(
                          tooltip: 'নিজের লেখা যোগ করুন',
                          onPressed: _addCustomText,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.text_fields),
                        const SizedBox(width: 8),
                        const Text('লেখার সাইজ'),
                        Expanded(
                          child: Slider(
                            value: _textFontSize,
                            min: 18,
                            max: 64,
                            divisions: 23,
                            label: _textFontSize.round().toString(),
                            onChanged: (value) => setState(() => _textFontSize = value),
                          ),
                        ),
                        Text(_textFontSize.round().toString()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            decoration: BoxDecoration(
                              color: _activeTextBoxColor?.withValues(alpha: _textBackgroundOpacity),
                              borderRadius: BorderRadius.circular(18),
                              border: _selectedTextBackground == 'বক্স নেই'
                                  ? null
                                  : Border.all(color: Colors.white.withValues(alpha: 0.28)),
                              boxShadow: _selectedTextBackground == 'বক্স নেই'
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.18),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                            ),
                            child: _buildAnimatedText(),
                          ),
                        ),
                      ),
                    ),
                    if (_selectedTextBackground != 'বক্স নেই')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Text('বক্সের স্বচ্ছতা'),
                            Expanded(
                              child: Slider(
                                value: _textBackgroundOpacity,
                                min: 0.15,
                                max: 1.0,
                                divisions: 17,
                                label: '${(_textBackgroundOpacity * 100).round()}%',
                                onChanged: (value) {
                                  setState(() { _textBackgroundOpacity = value; });
                                },
                              ),
                            ),
                            Text('${(_textBackgroundOpacity * 100).round()}%'),
                          ],
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _toggleRun,
                                  icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                                  label: Text(_isRunning ? 'Stop Animation' : 'Start Animation'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _pickMusic,
                                  icon: const Icon(Icons.audiotrack),
                                  label: const Text('Select Music'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _toggleMusic,
                                  icon: Icon(_isMusicPlaying ? Icons.pause : Icons.play_arrow),
                                  label: Text(_isMusicPlaying ? 'Pause Music' : 'Play Music'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Effect: $activeAnimation',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedMusicPath == null
                                ? 'No music selected'
                                : 'Selected: ${_selectedMusicPath!.split(Platform.pathSeparator).last}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
