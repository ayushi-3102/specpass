import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:specpass/main.dart';

void main() {
  testWidgets('SpecPass app bottom tabs and studio smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SpecPassApp(),
      ),
    );

    // Initial load
    await tester.pumpAndSettle();

    // Verify Title and Subtitle
    expect(find.text('SpecPass'), findsOneWidget);
    expect(find.text('Biometric Studio'), findsOneWidget);

    // Verify all 4 bottom tabs are visible
    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('Standards'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Guarantee'), findsOneWidget);

    // Tap on Standards tab
    await tester.tap(find.text('Standards'));
    await tester.pumpAndSettle();
    expect(find.text('Search 140+ countries & visa types...'), findsOneWidget);

    // Tap on Saved tab
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Sovereign Local Archive'), findsOneWidget);

    // Tap on Guarantee tab
    await tester.tap(find.text('Guarantee'));
    await tester.pumpAndSettle();
    expect(find.text('Uniform Pure Background'), findsOneWidget);

    // Tap back to Studio
    await tester.tap(find.text('Studio'));
    await tester.pumpAndSettle();
    expect(find.text('United States'), findsWidgets);
  });
}

