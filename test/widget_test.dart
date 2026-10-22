import 'package:flutter_test/flutter_test.dart';
import 'package:aizora_infinite_text_live/main.dart';

void main() {
  testWidgets('AIZORA app loads and Start Animation toggles to Stop Animation', (tester) async {
    await tester.pumpWidget(const AizoraApp());

    expect(find.text('AIZORA'), findsOneWidget);
    expect(find.text('Start Animation'), findsOneWidget);

    await tester.tap(find.text('Start Animation'));
    await tester.pump();

    expect(find.text('Stop Animation'), findsOneWidget);
  });
}
