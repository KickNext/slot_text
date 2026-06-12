import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slot_text_example/main.dart';

void main() {
  testWidgets('studio shell renders the showcase and runs an operation', (
    tester,
  ) async {
    await tester.pumpWidget(const SlotTextExampleApp(useGoogleFonts: false));
    await tester.pump(const Duration(milliseconds: 600));

    // Top bar: the current page name and the toggle target are SlotTexts.
    expect(find.bySemanticsLabel('SHOWCASE'), findsOneWidget);
    expect(find.bySemanticsLabel('RECIPES'), findsOneWidget);

    final start = find.text('Start').last;
    final complete = find.text('Complete').last;
    await tester.scrollUntilVisible(
      start,
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(complete, findsOneWidget);

    await tester.tap(start);
    await tester.pump();
    expect(find.byKey(const ValueKey('slot_text_rolling')), findsWidgets);

    await tester.tap(complete);
    await tester.pump();
    expect(find.byKey(const ValueKey('slot_text_rolling')), findsWidgets);
  });

  testWidgets('recipes page shows live previews with code', (tester) async {
    await tester.pumpWidget(const SlotTextExampleApp(useGoogleFonts: false));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.bySemanticsLabel('RECIPES'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Declarative swap'), findsOneWidget);

    await tester.tap(find.text('Toggle'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('slot_text_rolling')), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Waiting presets'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Waiting presets'), findsOneWidget);
  });
}
