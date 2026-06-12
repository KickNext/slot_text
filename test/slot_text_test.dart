import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slot_text/slot_text.dart';

void main() {
  test('chromatic creates a stable hue sweep', () {
    final sweep = chromatic(from: 20, spread: 120);

    expect(sweep(0, 3), isA<Color>());
    expect(sweep(0, 3), isNot(sweep(2, 3)));
    expect(sweep(0, 1), sweep(0, 1));
  });

  test('copyWith can replace inherited color mode', () {
    final options = SlotTextOptions(colorBuilder: chromatic());
    final replaced = options.copyWith(
      clearColor: true,
      color: const Color(0xff38bdf8),
    );

    expect(replaced.color, const Color(0xff38bdf8));
    expect(replaced.colorBuilder, isNull);
  });

  testWidgets('renders settled text without animation on first build', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SlotText('Copy'),
      ),
    );

    expect(find.bySemanticsLabel('Copy'), findsOneWidget);
    expect(find.byKey(const ValueKey('slot_text_settled')), findsOneWidget);
  });

  testWidgets('first settled frame keeps the full text run width', (
    tester,
  ) async {
    const style = TextStyle(
      fontSize: 72,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.8,
    );
    const text = 'AVATAR';

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SlotText(text, style: style)),
      ),
    );

    final painter = TextPainter(
      text: const TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    expect(tester.getSize(find.byType(SlotText)).width, painter.size.width);
  });

  testWidgets('declarative text changes roll then settle', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SlotText('Copy'),
      ),
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SlotText(
          'Copied',
          options: SlotTextOptions(
            duration: Duration(milliseconds: 80),
            stagger: Duration(milliseconds: 5),
            exitOffset: Duration.zero,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('slot_text_rolling')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('slot_text_settled')), findsOneWidget);
    expect(find.bySemanticsLabel('Copied'), findsOneWidget);
  });

  testWidgets('wide glyph changes keep faces unconstrained during roll', (
    tester,
  ) async {
    const options = SlotTextOptions(
      duration: Duration(milliseconds: 120),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      skipUnchanged: false,
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SlotText(
            'WWW',
            options: options,
            style: TextStyle(
              fontSize: 48,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SlotText(
            'iii',
            options: options,
            style: TextStyle(
              fontSize: 48,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.byKey(const ValueKey('slot_text_rolling')), findsOneWidget);

    await tester.pumpAndSettle();

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SlotText(
            'WAVY',
            options: options,
            style: TextStyle(
              fontSize: 48,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('WAVY'), findsOneWidget);
  });

  testWidgets('descenders do not break the outgoing glyph handoff', (
    tester,
  ) async {
    const options = SlotTextOptions(
      direction: SlotTextDirection.up,
      duration: Duration(milliseconds: 160),
      stagger: Duration.zero,
      exitOffset: Duration(milliseconds: 20),
      skipUnchanged: false,
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SlotText(
            'gyp',
            options: options,
            style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SlotText(
            'ACE',
            options: options,
            style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const ValueKey('slot_text_rolling')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('ACE'), findsOneWidget);
  });

  testWidgets('slot height stays stable before and during a roll', (
    tester,
  ) async {
    const options = SlotTextOptions(
      duration: Duration(milliseconds: 160),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
    );
    const textStyle = TextStyle(fontSize: 64, fontWeight: FontWeight.w900);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SlotText('Copy', options: options, style: textStyle),
        ),
      ),
    );
    final settledHeight = tester.getSize(find.byType(SlotText)).height;

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SlotText('Copied', options: options, style: textStyle),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    final rollingHeight = tester.getSize(find.byType(SlotText)).height;

    await tester.pumpAndSettle();
    final finalHeight = tester.getSize(find.byType(SlotText)).height;

    expect(rollingHeight, closeTo(settledHeight, 0.01));
    expect(finalHeight, closeTo(settledHeight, 0.01));
  });

  testWidgets('settled width matches final per-glyph animation width', (
    tester,
  ) async {
    const options = SlotTextOptions(
      duration: Duration(milliseconds: 120),
      stagger: Duration.zero,
      exitOffset: Duration.zero,
      skipUnchanged: false,
      bounce: 0,
    );
    const textStyle = TextStyle(
      fontSize: 40,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w900,
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SlotText('fit lit', options: options, style: textStyle),
        ),
      ),
    );

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SlotText('WAVY WWW', options: options, style: textStyle),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 180));
    final lastRollingWidth = tester.getSize(find.byType(SlotText)).width;

    await tester.pumpAndSettle();
    final settledWidth = tester.getSize(find.byType(SlotText)).width;

    expect(settledWidth, closeTo(lastRollingWidth, 0.01));
  });

  testWidgets('controller set cancels a pending flash revert', (tester) async {
    final controller = SlotTextController(initialText: 'Copy');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SlotText.controller(
          controller: controller,
          options: const SlotTextOptions(
            duration: Duration(milliseconds: 40),
            stagger: Duration.zero,
            exitOffset: Duration.zero,
          ),
        ),
      ),
    );

    controller.flash(
      'Copied',
      options: const SlotTextFlashOptions(
        revertAfter: Duration(milliseconds: 200),
        enter: SlotTextOptions(duration: Duration(milliseconds: 40)),
        exit: SlotTextOptions(duration: Duration(milliseconds: 40)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    controller.set('Saved');
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(controller.value, 'Saved');
    expect(find.bySemanticsLabel('Saved'), findsOneWidget);
    expect(find.bySemanticsLabel('Copy'), findsNothing);
  });

  testWidgets('flash reverts to the original resting text after last flash', (
    tester,
  ) async {
    final controller = SlotTextController(initialText: 'Copy');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SlotText.controller(
          controller: controller,
          options: const SlotTextOptions(
            duration: Duration(milliseconds: 30),
            stagger: Duration.zero,
            exitOffset: Duration.zero,
          ),
        ),
      ),
    );

    controller.flash(
      'Copied',
      options: const SlotTextFlashOptions(
        revertAfter: Duration(milliseconds: 100),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    controller.flash(
      'Copied again',
      options: const SlotTextFlashOptions(
        revertAfter: Duration(milliseconds: 100),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    expect(controller.value, 'Copied again');

    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();

    expect(controller.value, 'Copy');
    expect(find.bySemanticsLabel('Copy'), findsOneWidget);
  });

  testWidgets('progress keeps rolling until completed', (tester) async {
    final controller = SlotTextController(initialText: 'Export');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SlotText.controller(
          controller: controller,
          options: const SlotTextOptions(
            duration: Duration(milliseconds: 20),
            stagger: Duration.zero,
            exitOffset: Duration.zero,
          ),
        ),
      ),
    );

    final progress = controller.startProgress(
      'Exporter',
      frames: const ['Exported'],
      interval: const Duration(milliseconds: 70),
      options: const SlotTextOptions(duration: Duration(milliseconds: 20)),
    );
    await tester.pump();

    expect(progress.isActive, isTrue);
    expect(controller.value, 'Exporter');
    expect(find.byType(ClipRect), findsNWidgets(2));

    await tester.pump(const Duration(milliseconds: 80));
    expect(controller.value, 'Exported');

    progress.complete(
      'Exported',
      options: const SlotTextOptions(color: Color(0xff38bdf8)),
    );
    await tester.pumpAndSettle();

    expect(progress.isActive, isFalse);
    expect(controller.value, 'Exported');
    expect(find.bySemanticsLabel('Exported'), findsOneWidget);
  });

  testWidgets('set cancels an active progress loop', (tester) async {
    final controller = SlotTextController(initialText: 'Export');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SlotText.controller(
          controller: controller,
          options: const SlotTextOptions(
            duration: Duration(milliseconds: 20),
            stagger: Duration.zero,
            exitOffset: Duration.zero,
          ),
        ),
      ),
    );

    final progress = controller.startProgress(
      'Exporter',
      interval: const Duration(milliseconds: 60),
      options: const SlotTextOptions(duration: Duration(milliseconds: 20)),
    );
    await tester.pump();

    controller.set('Idle');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 80));

    expect(progress.isActive, isFalse);
    expect(controller.value, 'Idle');
    expect(find.bySemanticsLabel('Idle'), findsOneWidget);
  });

  testWidgets('startWaiting ellipsis cycles trailing dots', (tester) async {
    final controller = SlotTextController(initialText: 'Load');
    addTearDown(controller.dispose);
    final seen = <String>[];
    controller.addListener(() => seen.add(controller.value));

    final handle = controller.startWaiting(
      'Load',
      waiting: const SlotWaiting.ellipsis(step: Duration(milliseconds: 100)),
    );

    await tester.pump(const Duration(milliseconds: 450));
    expect(seen, ['Load', 'Load.', 'Load..', 'Load...', 'Load']);
    expect(handle.isActive, isTrue);

    handle.complete('Done');
    expect(handle.isActive, isFalse);
    expect(controller.value, 'Done');

    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.value, 'Done');
  });

  testWidgets('startWaiting wave periodically re-rolls the same label', (
    tester,
  ) async {
    final controller = SlotTextController(initialText: 'Sync');
    addTearDown(controller.dispose);
    var emits = 0;
    controller.addListener(() => emits++);

    final handle = controller.startWaiting(
      'Sync',
      waiting: const SlotWaiting.wave(rest: Duration(milliseconds: 200)),
      options: const SlotTextOptions(
        duration: Duration(milliseconds: 100),
        stagger: Duration(milliseconds: 10),
        exitOffset: Duration.zero,
        bounce: 0,
      ),
    );

    expect(emits, 1);
    expect(controller.value, 'Sync');

    await tester.pump(const Duration(milliseconds: 1000));
    expect(emits, greaterThanOrEqualTo(3));
    expect(controller.value, 'Sync');

    handle.cancel();
    expect(handle.isActive, isFalse);
  });

  testWidgets('startWaiting builder generates one frame per tick', (
    tester,
  ) async {
    final controller = SlotTextController(initialText: 'Go');
    addTearDown(controller.dispose);
    final seen = <String>[];
    controller.addListener(() => seen.add(controller.value));

    final handle = controller.startWaiting(
      'Go',
      waiting: SlotWaiting.builder(
        (text, tick) => '$text$tick',
        step: const Duration(milliseconds: 50),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));
    expect(seen, ['Go0', 'Go1', 'Go2']);

    handle.cancel(text: 'Go');
    expect(controller.value, 'Go');

    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.value, 'Go');
  });

  testWidgets('snaps without rolling when animations are disabled', (
    tester,
  ) async {
    Widget wrap(String text) {
      return MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SlotText(text),
        ),
      );
    }

    await tester.pumpWidget(wrap('Copy'));
    await tester.pumpWidget(wrap('Copied'));
    await tester.pump();

    expect(find.byKey(const ValueKey('slot_text_rolling')), findsNothing);
    expect(find.byKey(const ValueKey('slot_text_settled')), findsOneWidget);
    expect(find.bySemanticsLabel('Copied'), findsOneWidget);
  });

  testWidgets('respectDisableAnimations can opt out of reduced motion', (
    tester,
  ) async {
    Widget wrap(String text) {
      return MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SlotText(
            text,
            respectDisableAnimations: false,
            options: const SlotTextOptions(
              duration: Duration(milliseconds: 60),
              stagger: Duration.zero,
              exitOffset: Duration.zero,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(wrap('Copy'));
    await tester.pumpWidget(wrap('Copied'));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(const ValueKey('slot_text_rolling')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Copied'), findsOneWidget);
  });
}
