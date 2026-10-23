import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
  final List<String> _animationNames = ['Fade', 'Slide', 'Scale'];
  String _selectedCategory = 'ভালোবাসা';
  String _selectedAnimation = 'Fade';
  String _selectedTheme = 'নীল';
  String _selectedTextBackground = 'কালো';
  double _textBackgroundOpacity = 0.72;
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
        final backgrounds = _themePalettes[_selectedTheme]!;
        _backgroundIndex = (_backgroundIndex + 1) % backgrounds.length;
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
    final activeAnimation = _selectedAnimation;

    switch (activeAnimation) {
      case 'Fade':
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 900),
          child: Text(
            key: ValueKey<String>(activeText),
            activeText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: _selectedTextBackground == 'সাদা' ? Colors.black : Colors.white,
              letterSpacing: 1.2,
              height: 1.2,
            ),
          ),
        );
      case 'Slide':
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 28, end: 0),
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, value),
              child: Opacity(
                opacity: value < 15 ? 1.0 : 0.5,
                child: child,
              ),
            );
          },
          child: Text(
            activeText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: _selectedTextBackground == 'সাদা' ? Colors.black : Colors.white,
              letterSpacing: 1.2,
              height: 1.2,
            ),
          ),
        );
      case 'Scale':
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.72, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          child: Text(
            activeText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: _selectedTextBackground == 'সাদা' ? Colors.black : Colors.white,
              letterSpacing: 1.2,
              height: 1.2,
            ),
          ),
        );
      default:
        return Text(
          activeText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: _selectedTextBackground == 'সাদা' ? Colors.black : Colors.white,
            letterSpacing: 1.2,
            height: 1.2,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _themePalettes[_selectedTheme]![
        _backgroundIndex % _themePalettes[_selectedTheme]!.length];
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
                          value: _selectedTheme,
                          items: _themePalettes.keys.map((name) => DropdownMenuItem(value: name, child: Text('থিম: $name'))).toList(),
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
                          items: _textBackgroundChoices.keys.map((name) => DropdownMenuItem(value: name, child: Text('টেক্সট: $name'))).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() { _selectedTextBackground = value; });
                          },
                        ),
                        IconButton(
                          tooltip: 'নিজের লেখা যোগ করুন',
                          onPressed: _addCustomText,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
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
                              color: _textBackgroundChoices[_selectedTextBackground]
                                  ?.withValues(alpha: _textBackgroundOpacity),
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
