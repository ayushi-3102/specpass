import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:specpass/main.dart';

void main() {
  testWidgets('SpecPass app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SpecPassApp(),
      ),
    );

    expect(find.text('SpecPass'), findsOneWidget);
  });
}
