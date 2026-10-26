import 'package:flutter_test/flutter_test.dart';
import 'package:aizora_infinite_text_live/scene_timeline.dart';

void main() {
  test('text and background use independent periods', () {
    final start = DateTime.utc(2026, 10, 24);
    final timeline = AizoraSceneTimeline(startedAt: start);
    expect(timeline.textIndex(start, 4), 0);
    expect(timeline.textIndex(start.add(const Duration(seconds: 3)), 4), 1);
    expect(timeline.backgroundIndex(start.add(const Duration(seconds: 3)), 2), 0);
    expect(timeline.backgroundIndex(start.add(const Duration(seconds: 4)), 2), 1);
  });

  test('timeline catches up after a long pause', () {
    final start = DateTime.utc(2026, 10, 24);
    final timeline = AizoraSceneTimeline(startedAt: start);
    final now = start.add(const Duration(seconds: 125));
    expect(timeline.textIndex(now, 4), 1); // 41 modulo 4
    expect(timeline.backgroundIndex(now, 2), 1); // 31 modulo 2
  });

  test('empty scene and negative elapsed time are safe', () {
    final start = DateTime.utc(2026, 10, 24);
    final timeline = AizoraSceneTimeline(startedAt: start);
    expect(timeline.textIndex(start, 0), 0);
    expect(timeline.backgroundIndex(start.subtract(const Duration(seconds: 2)), 2), 0);
  });
}
