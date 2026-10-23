import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aizora_infinite_text_live/main.dart';

void main() {
  testWidgets('AIZORA automatically changes text every three seconds', (tester) async {
    await tester.pumpWidget(const AizoraApp());

    expect(find.text('AIZORA'), findsOneWidget);
    expect(find.text('ভালোবাসা মানে একে অপরের পাশে থাকা।'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('তোমার হাসিতে আমার পৃথিবী সুন্দর।'), findsOneWidget);
  });

  testWidgets('Animation can still be stopped and restarted', (tester) async {
    await tester.pumpWidget(const AizoraApp());

    await tester.scrollUntilVisible(
      find.text('Stop Animation'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Stop Animation'));
    await tester.pump();
    expect(find.text('Start Animation'), findsOneWidget);

    await tester.tap(find.text('Start Animation'));
    await tester.pump();
    expect(find.text('Stop Animation'), findsOneWidget);
  });
}
