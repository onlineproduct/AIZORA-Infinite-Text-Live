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

  final List<List<Color>> _backgrounds = [
    [const Color(0xFF0B1120), const Color(0xFF1D4ED8)],
    [const Color(0xFF111827), const Color(0xFF7C3AED)],
    [const Color(0xFF1F2937), const Color(0xFF14B8A6)],
    [const Color(0xFF1F1B4D), const Color(0xFFE11D48)],
    [const Color(0xFF0F172A), const Color(0xFF10B981)],
  ];

  final List<String> _texts = [
    'AIZORA Infinite Text Live',
    'স্বাগতম। আপনার সৃষ্টির মুহূর্ত',
    'বাংলা ও English একসাথে',
    'Beautiful motion. Strong rhythm.',
    'Live visuals with a moving story',
    'Automation keeps the scene alive',
    'AIZORA — powered by motion and music',
  ];

  final List<String> _animationNames = ['Fade', 'Slide', 'Scale'];

  String? _selectedMusicPath;
  String _statusMessage = 'Ready';
  bool _isRunning = false;
  bool _isMusicPlaying = false;
  int _backgroundIndex = 0;
  int _textIndex = 0;
  int _animationIndex = 0;

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
        _backgroundIndex = (_backgroundIndex + 1) % _backgrounds.length;
      });
    });

    _textTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isRunning) {
        return;
      }
      setState(() {
        _textIndex = (_textIndex + 1) % _texts.length;
        _animationIndex = (_animationIndex + 1) % _animationNames.length;
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

  Widget _buildAnimatedText() {
    final activeText = _texts[_textIndex];
    final activeAnimation = _animationNames[_animationIndex];

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
              color: Colors.white,
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
              color: Colors.white,
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
              color: Colors.white,
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
            color: Colors.white,
            letterSpacing: 1.2,
            height: 1.2,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _backgrounds[_backgroundIndex];
    final activeAnimation = _animationNames[_animationIndex];

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
                            color: Colors.white.withOpacity(0.08),
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
                    const SizedBox(height: 18),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 20),
                          child: _buildAnimatedText(),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.18),
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
                                    color: Colors.white.withOpacity(0.08),
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
