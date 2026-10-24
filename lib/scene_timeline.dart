/// Pure Dart scene timeline. It is safe to use from a background isolate:
/// no Flutter widgets, rendering context or platform channels are required.
class AizoraSceneTimeline {
  const AizoraSceneTimeline({
    required this.startedAt,
    this.textInterval = const Duration(seconds: 3),
    this.backgroundInterval = const Duration(seconds: 4),
  });

  final DateTime startedAt;
  final Duration textInterval;
  final Duration backgroundInterval;

  int _step(DateTime now, Duration interval) {
    final elapsed = now.difference(startedAt).inMilliseconds;
    if (elapsed <= 0 || interval.inMilliseconds <= 0) return 0;
    return elapsed ~/ interval.inMilliseconds;
  }

  int textIndex(DateTime now, int count) =>
      count <= 0 ? 0 : _step(now, textInterval) % count;

  int backgroundIndex(DateTime now, int count) =>
      count <= 0 ? 0 : _step(now, backgroundInterval) % count;
}
