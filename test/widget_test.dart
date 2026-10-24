import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aizora_infinite_text_live/main.dart';

void main() {
  testWidgets('Animated scene changes text every three seconds', (tester) async {
    await tester.pumpWidget(const AizoraApp());

    expect(find.text('ভালোবাসা মানে একে অপরের পাশে থাকা।'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('তোমার হাসিতে আমার পৃথিবী সুন্দর।'), findsOneWidget);
  });

  testWidgets('Animation can be paused and resumed from settings', (tester) async {
    await tester.pumpWidget(const AizoraApp());

    await tester.tap(find.text('Show settings'));
    await tester.pump();

    expect(find.text('Pause animation'), findsOneWidget);
    await tester.tap(find.text('Pause animation'));
    await tester.pump();

    expect(find.text('Resume animation'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('ভালোবাসা মানে একে অপরের পাশে থাকা।'), findsOneWidget);

    await tester.tap(find.text('Resume animation'));
    await tester.pump();
    expect(find.text('Pause animation'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('তোমার হাসিতে আমার পৃথিবী সুন্দর।'), findsOneWidget);
  });
}
