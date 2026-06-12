import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:slot_text/slot_text.dart';

import 'code_view.dart';
import 'studio.dart';

/// Developer-facing screen: each recipe pairs a live, working preview with
/// the exact code that produces it.
class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 880;
    final recipes = <Widget>[
      const _RecipeCard(
        title: 'Declarative swap',
        blurb:
            'The simplest form: rebuild with a different string and only the '
            'changed glyphs roll.',
        preview: _DeclarativePreview(),
        code: _declarativeCode,
      ),
      const _RecipeCard(
        title: 'Copy button with flash()',
        blurb:
            'flash() rolls a temporary label in, then rolls the resting text '
            'back. Rapid taps reset the revert timer instead of stacking.',
        preview: _FlashPreview(),
        code: _flashCode,
      ),
      const _RecipeCard(
        title: 'Counter',
        blurb:
            'Only the digits that actually change roll, and the direction '
            'follows the delta: increments roll bottom-up, decrements '
            'top-down. A monospaced face keeps the slots from shifting.',
        preview: _CounterPreview(),
        code: _counterCode,
      ),
      const _RecipeCard(
        title: 'Async operation with a handle',
        blurb:
            'startWaiting() loops an idle animation until your future '
            'resolves, then the handle rolls in the final label.',
        preview: _AsyncPreview(),
        code: _asyncCode,
      ),
      const _RecipeCard(
        title: 'Waiting presets',
        blurb:
            'Three looks for the same loop: trailing dots, a breathing wave '
            'across the word, or fully custom frames from a builder.',
        preview: _WaitingPreview(),
        code: _waitingCode,
      ),
      const _RecipeCard(
        title: 'Spam-safe button (interrupt: false)',
        blurb:
            'With interrupt: false an in-flight roll finishes first and only '
            'the latest pending target plays next — mash away.',
        preview: _SpamSafePreview(),
        code: _spamSafeCode,
      ),
      const _RecipeCard(
        title: 'Reduced motion',
        blurb:
            'When the platform asks for reduced motion, SlotText snaps to '
            'the target instantly. Toggle the simulation to verify.',
        preview: _ReducedMotionPreview(),
        code: _reducedMotionCode,
      ),
    ];

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 28,
        vertical: 24,
      ),
      itemCount: recipes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, index) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: recipes[index],
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.title,
    required this.blurb,
    required this.preview,
    required this.code,
  });

  final String title;
  final String blurb;
  final Widget preview;
  final String code;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 880;
    final previewBox = DecoratedBox(
      decoration: BoxDecoration(
        color: Studio.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Studio.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: preview),
      ),
    );
    final codeBox = CodeView(code: code);

    return StudioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Studio.display(size: 16, letterSpacing: 0)),
          const SizedBox(height: 7),
          Text(blurb, style: Studio.body(size: 12.5)),
          const SizedBox(height: 16),
          if (compact) ...[
            previewBox,
            const SizedBox(height: 12),
            codeBox,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: previewBox),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: codeBox),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Declarative swap
// ---------------------------------------------------------------------------

const _declarativeCode = '''
bool saved = false;

SlotText(
  saved ? 'Saved' : 'Save',
  options: const SlotTextOptions(
    direction: SlotTextDirection.up,
  ),
  style: const TextStyle(fontSize: 24),
);

// Anywhere in your state:
setState(() => saved = !saved);''';

class _DeclarativePreview extends StatefulWidget {
  const _DeclarativePreview();

  @override
  State<_DeclarativePreview> createState() => _DeclarativePreviewState();
}

class _DeclarativePreviewState extends State<_DeclarativePreview> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SlotText(
          _saved ? 'Saved' : 'Save',
          options: const SlotTextOptions(direction: SlotTextDirection.up),
          style: Studio.display(size: 26, letterSpacing: 0),
        ),
        const SizedBox(height: 16),
        StudioButton(
          onPressed: () => setState(() => _saved = !_saved),
          filled: false,
          child: const Text('Toggle'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. flash()
// ---------------------------------------------------------------------------

const _flashCode = '''
final label = SlotTextController(initialText: 'Copy');

// In build:
SlotText.controller(controller: label);

// On tap:
label.flash(
  'Copied',
  options: SlotTextFlashOptions(
    revertAfter: const Duration(milliseconds: 1400),
    enter: SlotTextOptions(colorBuilder: chromatic()),
    exit: const SlotTextOptions(
      direction: SlotTextDirection.down,
    ),
  ),
);''';

class _FlashPreview extends StatefulWidget {
  const _FlashPreview();

  @override
  State<_FlashPreview> createState() => _FlashPreviewState();
}

class _FlashPreviewState extends State<_FlashPreview> {
  late final SlotTextController _label;

  @override
  void initState() {
    super.initState();
    _label = SlotTextController(initialText: 'Copy');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudioButton(
      onPressed: () {
        _label.flash(
          'Copied',
          options: SlotTextFlashOptions(
            enter: SlotTextOptions(colorBuilder: chromatic()),
            exit: const SlotTextOptions(direction: SlotTextDirection.down),
          ),
        );
      },
      icon: Icons.copy_rounded,
      child: SlotText.controller(
        controller: _label,
        style: Studio.mono(
          size: 12.5,
          color: Studio.background,
          weight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Async operation
// ---------------------------------------------------------------------------

const _asyncCode = '''
final label = SlotTextController(initialText: 'Export');
SlotTextProgress? handle;

Future<void> export() async {
  // Spam-safe: re-taps while waiting do not restart the loop.
  if (handle?.isActive ?? false) {
    return;
  }
  handle = label.startWaiting('Exporting');
  try {
    await doExport();
    handle!.complete('Exported');
  } catch (_) {
    handle!.fail('Failed');
  }
}''';

class _AsyncPreview extends StatefulWidget {
  const _AsyncPreview();

  @override
  State<_AsyncPreview> createState() => _AsyncPreviewState();
}

class _AsyncPreviewState extends State<_AsyncPreview> {
  late final SlotTextController _label;
  Timer? _finish;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _label = SlotTextController(initialText: 'Export');
  }

  @override
  void dispose() {
    _finish?.cancel();
    _label.dispose();
    super.dispose();
  }

  void _run({required bool succeed}) {
    _finish?.cancel();
    setState(() => _running = true);
    final handle = _label.startWaiting(
      'Exporting',
      options: const SlotTextOptions(color: Studio.amber),
    );
    _finish = Timer(const Duration(milliseconds: 2600), () {
      if (succeed) {
        handle.complete(
          'Exported',
          options: const SlotTextOptions(color: Studio.lime),
        );
      } else {
        handle.fail(
          'Failed',
          options: const SlotTextOptions(color: Studio.rose),
        );
      }
      if (mounted) {
        setState(() => _running = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SlotText.controller(
          controller: _label,
          style: Studio.display(size: 24, letterSpacing: 0),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            StudioButton(
              onPressed: _running ? null : () => _run(succeed: true),
              filled: false,
              child: const Text('Run · success'),
            ),
            StudioButton(
              onPressed: _running ? null : () => _run(succeed: false),
              filled: false,
              accent: Studio.rose,
              child: const Text('Run · failure'),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Waiting presets
// ---------------------------------------------------------------------------

const _waitingCode = '''
// Trailing dots: Sync -> Sync. -> Sync.. -> Sync...
label.startWaiting('Sync', waiting: const SlotWaiting.ellipsis());

// The word breathes: a stagger wave sweeps the glyphs, then rests.
label.startWaiting(
  'Sync',
  waiting: const SlotWaiting.wave(rest: Duration(milliseconds: 900)),
);

// Full control: generate any frame per tick.
label.startWaiting(
  'Sync',
  waiting: SlotWaiting.builder((text, tick) {
    final r = math.Random(tick);
    return tick % 4 == 0
        ? text
        : text.substring(0, 3) + 'abcxyz'[r.nextInt(6)];
  }),
);''';

enum _WaitingKind { ellipsis, wave, builder }

class _WaitingPreview extends StatefulWidget {
  const _WaitingPreview();

  @override
  State<_WaitingPreview> createState() => _WaitingPreviewState();
}

class _WaitingPreviewState extends State<_WaitingPreview> {
  late final SlotTextController _label;
  _WaitingKind _kind = _WaitingKind.ellipsis;

  @override
  void initState() {
    super.initState();
    _label = SlotTextController(initialText: 'Sync');
    _start();
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _start() {
    switch (_kind) {
      case _WaitingKind.ellipsis:
        _label.startWaiting(
          'Sync',
          waiting: const SlotWaiting.ellipsis(),
          options: const SlotTextOptions(color: Studio.lime),
        );
      case _WaitingKind.wave:
        _label.startWaiting(
          'Sync',
          waiting: const SlotWaiting.wave(rest: Duration(milliseconds: 900)),
          options: SlotTextOptions(
            colorBuilder: chromatic(from: 190, spread: 70),
          ),
        );
      case _WaitingKind.builder:
        _label.startWaiting(
          'Sync',
          waiting: SlotWaiting.builder((text, tick) {
            if (tick % 4 == 0) {
              return text;
            }
            final r = math.Random(tick * 7919);
            const set = 'abcdefghijklmnopqrstuvwxyz';
            return text.substring(0, 3) + set[r.nextInt(set.length)];
          }, step: const Duration(milliseconds: 280)),
          options: const SlotTextOptions(color: Studio.violet),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: Center(
            child: SlotText.controller(
              controller: _label,
              style: Studio.display(size: 22, letterSpacing: 0),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_WaitingKind>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _WaitingKind.ellipsis, label: Text('dots')),
            ButtonSegment(value: _WaitingKind.wave, label: Text('wave')),
            ButtonSegment(value: _WaitingKind.builder, label: Text('builder')),
          ],
          selected: {_kind},
          onSelectionChanged: (s) {
            setState(() => _kind = s.first);
            _start();
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Counter
// ---------------------------------------------------------------------------

const _counterCode = r'''
int count = 1024;
bool up = true;

SlotText(
  '$count',
  // Only changed digits roll (skipUnchanged: true is the
  // default). Direction follows the delta.
  options: SlotTextOptions(
    direction: up ? SlotTextDirection.up : SlotTextDirection.down,
  ),
  style: const TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    fontFeatures: [FontFeature.tabularFigures()],
  ),
);

// On taps:
setState(() { count += 1; up = true; });
setState(() { count -= 1; up = false; });''';

class _CounterPreview extends StatefulWidget {
  const _CounterPreview();

  @override
  State<_CounterPreview> createState() => _CounterPreviewState();
}

class _CounterPreviewState extends State<_CounterPreview> {
  int _count = 1024;
  bool _up = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SlotText(
          '$_count',
          options: SlotTextOptions(
            direction: _up ? SlotTextDirection.up : SlotTextDirection.down,
          ),
          style: Studio.mono(
            size: 40,
            color: Studio.text,
            weight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            IconButton.outlined(
              onPressed: () => setState(() {
                _count -= 1;
                _up = false;
              }),
              style: IconButton.styleFrom(
                side: const BorderSide(color: Studio.border),
                foregroundColor: Studio.text,
              ),
              icon: const Icon(Icons.remove_rounded),
            ),
            IconButton.outlined(
              onPressed: () => setState(() {
                _count += 1;
                _up = true;
              }),
              style: IconButton.styleFrom(
                side: const BorderSide(color: Studio.border),
                foregroundColor: Studio.text,
              ),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Spam-safe button
// ---------------------------------------------------------------------------

const _spamSafeCode = '''
final label = SlotTextController(initialText: 'Like');
var liked = false;

// On every tap — even very fast ones:
liked = !liked;
label.set(
  liked ? 'Liked' : 'Like',
  options: const SlotTextOptions(
    interrupt: false, // finish the roll, play only the latest
  ),
);''';

class _SpamSafePreview extends StatefulWidget {
  const _SpamSafePreview();

  @override
  State<_SpamSafePreview> createState() => _SpamSafePreviewState();
}

class _SpamSafePreviewState extends State<_SpamSafePreview> {
  late final SlotTextController _label;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _label = SlotTextController(initialText: 'Like');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudioButton(
      onPressed: () {
        _liked = !_liked;
        _label.set(
          _liked ? 'Liked' : 'Like',
          options: const SlotTextOptions(interrupt: false),
        );
      },
      accent: Studio.rose,
      icon: Icons.favorite_rounded,
      child: SlotText.controller(
        controller: _label,
        style: Studio.mono(
          size: 12.5,
          color: Studio.background,
          weight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Reduced motion
// ---------------------------------------------------------------------------

const _reducedMotionCode = '''
// Default: when MediaQuery.disableAnimationsOf(context) is true,
// SlotText snaps to the target text without rolling.
SlotText(
  status,
  respectDisableAnimations: true, // the default
);

// Opt out if the roll is essential to your design:
SlotText(status, respectDisableAnimations: false);''';

class _ReducedMotionPreview extends StatefulWidget {
  const _ReducedMotionPreview();

  @override
  State<_ReducedMotionPreview> createState() => _ReducedMotionPreviewState();
}

class _ReducedMotionPreviewState extends State<_ReducedMotionPreview> {
  bool _reduced = false;
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MediaQuery(
          data: media.copyWith(disableAnimations: _reduced),
          child: SlotText(
            _on ? 'Online' : 'Offline',
            style: Studio.display(size: 22, letterSpacing: 0),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Reduced motion',
              style: TextStyle(color: Studio.muted, fontSize: 12.5),
            ),
            const SizedBox(width: 8),
            Switch(
              value: _reduced,
              onChanged: (v) => setState(() => _reduced = v),
            ),
          ],
        ),
        StudioButton(
          onPressed: () => setState(() => _on = !_on),
          filled: false,
          child: const Text('Toggle status'),
        ),
      ],
    );
  }
}
