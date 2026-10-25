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
    await tester.tap(find.text('Settings'));
    await tester.pump();

    final toggle = find.text('Auto change text/background');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('ভালোবাসা মানে একে অপরের পাশে থাকা।'), findsOneWidget);

    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('তোমার হাসিতে আমার পৃথিবী সুন্দর।'), findsOneWidget);
  });
}
