import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const MethodChannel _liveChannel = MethodChannel('aizora.live');
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  bool _liveBusy = false;
  bool _liveActive = false;
  String _liveStatus = 'Not connected';

  final List<List<Color>> _backgrounds = [
    [const Color(0xFF0B1120), const Color(0xFF1D4ED8)],
    [const Color(0xFF111827), const Color(0xFF7C3AED)],
    [const Color(0xFF1F2937), const Color(0xFF14B8A6)],
    [const Color(0xFF1F1B4D), const Color(0xFFE11D48)],
    [const Color(0xFF0F172A), const Color(0xFF10B981)],
  ];

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
    _serverController.dispose();
    _keyController.dispose();
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

  Future<void> _startLive() async {
    if (_liveBusy) return;
    final server = _serverController.text.trim();
    final key = _keyController.text.trim();
    if (!server.startsWith('rtmp://') && !server.startsWith('rtmps://')) {
      setState(() => _liveStatus = 'Enter a valid RTMP/RTMPS server URL.');
      return;
    }
    if (key.isEmpty) {
      setState(() => _liveStatus = 'Enter your stream key.');
      return;
    }
    setState(() { _liveBusy = true; _liveStatus = 'Connecting...'; });
    try {
      final result = await _liveChannel.invokeMethod<dynamic>('startLive', {
        'serverUrl': server,
        'streamKey': key,
      });
      if (!mounted) return;
      setState(() {
        _liveStatus = 'Publisher response: ${result ?? "No confirmation"}';
        // A platform method returning is not proof of a Facebook stream.
        _liveActive = false;
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() => _liveStatus = 'Live error: ${error.message ?? error.code}');
    } on MissingPluginException {
      if (mounted) setState(() => _liveStatus = 'Live publisher is not installed in this APK.');
    } finally {
      if (mounted) setState(() => _liveBusy = false);
    }
  }

  Future<void> _stopLive() async {
    if (_liveBusy) return;
    setState(() => _liveBusy = true);
    try {
      await _liveChannel.invokeMethod<dynamic>('stopLive');
      if (mounted) setState(() { _liveActive = false; _liveStatus = 'Stop requested.'; });
    } catch (error) {
      if (mounted) setState(() => _liveStatus = 'Stop failed: $error');
    } finally {
      if (mounted) setState(() => _liveBusy = false);
    }
  }

  void _openLiveSetup() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF141D38),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Facebook Live Setup', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _serverController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'RTMPS Server URL', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyController,
                  obscureText: true,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Stream Key', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                const Text('Preview controls are separate from publishing. A successful Facebook stream must be verified on Facebook.',
                  style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                StatefulBuilder(builder: (context, refresh) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _liveBusy ? null : () async { await _startLive(); if (context.mounted) refresh(() {}); },
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('Start Live'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _liveBusy ? null : () async { await _stopLive(); if (context.mounted) refresh(() {}); },
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Stop Live'),
                    ),
                    Text(_liveStatus, style: const TextStyle(color: Colors.white70)),
                  ],
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF141D38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) {
          return SafeArea(
            top: false,
            child: FractionallySizedBox(
              heightFactor: 0.72,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Text category'),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCategory,
                    items: _categories.keys.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() { _selectedCategory = value; _textIndex = 0; });
                      refresh(() {});
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('নিজের লেখা যোগ করুন'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _addCustomText();
                    },
                  ),
                  const Divider(),
                  const Text('Animation effect'),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedAnimation,
                    items: _animationNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedAnimation = value);
                      refresh(() {});
                    },
                  ),
                  const Divider(),
                  const Text('Background music'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.library_music_outlined),
                    title: const Text('Select music'),
                    subtitle: Text(_selectedMusicPath == null
                        ? 'No music selected'
                        : _selectedMusicPath!.split(Platform.pathSeparator).last,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () async {
                      await _pickMusic();
                      if (sheetContext.mounted) refresh(() {});
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_isMusicPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline),
                    title: Text(_isMusicPlaying ? 'Pause music' : 'Play music'),
                    onTap: () async {
                      await _toggleMusic();
                      if (sheetContext.mounted) refresh(() {});
                    },
                  ),
                  const Divider(),
                  Text(_statusMessage, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _backgrounds[_backgroundIndex];
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('AIZORA', style: TextStyle(
                        fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(_isRunning ? 'Running' : 'Stopped',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      tooltip: 'Facebook Live',
                      onPressed: _openLiveSetup,
                      icon: const Icon(Icons.wifi_tethering_rounded),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: _openSettings,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
                      color: Colors.black.withValues(alpha: 0.12),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 330),
                            child: _buildAnimatedText(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _toggleRun,
                    icon: Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    label: Text(_isRunning ? 'Stop Animation' : 'Start Animation',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF5B65E8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
