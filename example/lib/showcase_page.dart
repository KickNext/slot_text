import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:slot_text/slot_text.dart';

import 'studio.dart';

enum _ColorMode { mono, chromatic }

enum _Phase { idle, waiting, done, failed }

/// The designed landing of the example: hero, idle presets, live board,
/// async operation, counter, and copy feedback.
class ShowcasePage extends StatefulWidget {
  const ShowcasePage({super.key});

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  // Consecutive words share most letters at the same indices, so each cycle
  // rolls only 1-3 glyphs while the rest of the word stays planted:
  // CRAFT -> DRAFT (C->D), DRAFT -> DRIFT (A->I), DRIFT -> SHIFT (DR->SH),
  // SHIFT -> SWIFT (H->W), SWIFT -> CRAFT (SWI->CRA).
  static const _heroWords = ['CRAFT', 'DRAFT', 'DRIFT', 'SHIFT', 'SWIFT'];
  static const _scrambleSet = 'abcdefghijklmnopqrstuvwxyz';

  late final SlotTextController _hero;
  late final SlotTextController _ellipsis;
  late final SlotTextController _wave;
  late final SlotTextController _scramble;
  late final SlotTextController _operation;
  late final SlotTextController _copy;

  Timer? _heroTimer;
  SlotTextProgress? _operationHandle;
  _Phase _phase = _Phase.idle;
  int _heroIndex = 0;
  int _count = 1024;
  bool _countUp = true;
  bool _directionUp = true;
  double _speed = 320;
  _ColorMode _colorMode = _ColorMode.chromatic;

  @override
  void initState() {
    super.initState();
    _hero = SlotTextController(initialText: _heroWords.first);
    _ellipsis = SlotTextController(initialText: 'Loading');
    _wave = SlotTextController(initialText: 'Syncing');
    _scramble = SlotTextController(initialText: 'Thinking');
    _operation = SlotTextController(initialText: 'Export');
    _copy = SlotTextController(initialText: 'Copy');

    _heroTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      _heroIndex = (_heroIndex + 1) % _heroWords.length;
      _hero.set(
        _heroWords[_heroIndex],
        options: SlotTextOptions(
          duration: const Duration(milliseconds: 460),
          stagger: const Duration(milliseconds: 58),
          exitOffset: const Duration(milliseconds: 66),
          bounce: 0.6,
          direction: _heroIndex.isEven
              ? SlotTextDirection.up
              : SlotTextDirection.down,
          colorBuilder: chromatic(
            from: 70.0 + _heroIndex * 54,
            spread: 130,
            saturation: 0.85,
            lightness: 0.66,
          ),
        ),
      );
    });

    _startIdleLoops();
  }

  void _startIdleLoops() {
    // ellipsis and wave run on their designed default motion — what you get
    // out of the box with `controller.startWaiting(text)`.
    _ellipsis.startWaiting('Loading');
    _wave.startWaiting('Syncing', waiting: const SlotWaiting.wave());
    _scramble.startWaiting(
      'Thinking',
      waiting: SlotWaiting.builder((text, tick) {
        if (tick % 4 == 0) {
          return text;
        }
        final r = math.Random(tick * 9973);
        final chars = text.characters.toList();
        for (var n = 0; n < 2; n++) {
          final i = chars.length - 1 - r.nextInt(3);
          chars[i] = _scrambleSet[r.nextInt(_scrambleSet.length)];
        }
        return chars.join();
      }),
      options: const SlotTextOptions(
        duration: Duration(milliseconds: 230),
        stagger: Duration(milliseconds: 26),
        exitOffset: Duration(milliseconds: 36),
        bounce: 0.2,
        color: Studio.violet,
      ),
    );
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _operationHandle?.cancel();
    _hero.dispose();
    _ellipsis.dispose();
    _wave.dispose();
    _scramble.dispose();
    _operation.dispose();
    _copy.dispose();
    super.dispose();
  }

  SlotTextOptions get _deskOptions {
    return SlotTextOptions(
      direction: _directionUp ? SlotTextDirection.up : SlotTextDirection.down,
      duration: Duration(milliseconds: _speed.round()),
      stagger: const Duration(milliseconds: 38),
      exitOffset: const Duration(milliseconds: 44),
      bounce: 0.45,
      colorBuilder: _colorMode == _ColorMode.chromatic
          ? chromatic(from: 80, spread: 110, saturation: 0.8, lightness: 0.64)
          : null,
      color: _colorMode == _ColorMode.mono ? Studio.lime : null,
    );
  }

  SlotTextOptions _toneOptions(Color color) {
    return _deskOptions.copyWith(clearColor: true, color: color);
  }

  void _startOperation() {
    // Re-taps while the operation is already waiting are a no-op — the loop
    // keeps its rhythm instead of restarting from the first frame.
    if (_operationHandle?.isActive ?? false) {
      return;
    }
    setState(() => _phase = _Phase.waiting);
    _operationHandle = _operation.startWaiting(
      'Exporting',
      options: const SlotTextOptions(
        duration: Duration(milliseconds: 240),
        stagger: Duration(milliseconds: 34),
        exitOffset: Duration(milliseconds: 40),
        bounce: 0.25,
        color: Studio.amber,
      ),
    );
  }

  void _completeOperation() {
    final handle = _operationHandle;
    if (handle != null && handle.isActive) {
      handle.complete('Exported', options: _toneOptions(Studio.lime));
    } else {
      _operation.set('Exported', options: _toneOptions(Studio.lime));
    }
    setState(() {
      _operationHandle = null;
      _phase = _Phase.done;
    });
  }

  void _failOperation() {
    final handle = _operationHandle;
    if (handle != null && handle.isActive) {
      handle.fail('Failed', options: _toneOptions(Studio.rose));
    } else {
      _operation.set('Failed', options: _toneOptions(Studio.rose));
    }
    setState(() {
      _operationHandle = null;
      _phase = _Phase.failed;
    });
  }

  void _resetOperation() {
    final handle = _operationHandle;
    if (handle != null && handle.isActive) {
      handle.cancel(text: 'Export', options: _deskOptions);
    } else {
      _operation.set('Export', options: _deskOptions);
    }
    setState(() {
      _operationHandle = null;
      _phase = _Phase.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 880;
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 28,
        vertical: 24,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(controller: _hero, compact: compact),
                const SizedBox(height: 16),
                _IdleTrio(
                  compact: compact,
                  ellipsis: _ellipsis,
                  wave: _wave,
                  scramble: _scramble,
                ),
                const SizedBox(height: 16),
                _split(
                  compact: compact,
                  left: const _LiveBoard(),
                  right: _CounterPanel(
                    count: _count,
                    // Increment rolls digits bottom-up, decrement top-down —
                    // the motion itself tells you which way the value moved.
                    options: _deskOptions.copyWith(
                      direction: _countUp
                          ? SlotTextDirection.up
                          : SlotTextDirection.down,
                    ),
                    onIncrement: () => setState(() {
                      _count += 1;
                      _countUp = true;
                    }),
                    onDecrement: () => setState(() {
                      _count -= 1;
                      _countUp = false;
                    }),
                    onJump: () => setState(() {
                      _count += 111;
                      _countUp = true;
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                _split(
                  compact: compact,
                  left: _OperationPanel(
                    controller: _operation,
                    phase: _phase,
                    onStart: _startOperation,
                    onComplete: _completeOperation,
                    onFail: _failOperation,
                    onReset: _resetOperation,
                  ),
                  right: _MotionDesk(
                    directionUp: _directionUp,
                    speed: _speed,
                    colorMode: _colorMode,
                    copyController: _copy,
                    copyOptions: _deskOptions,
                    onDirectionChanged: (v) => setState(() => _directionUp = v),
                    onSpeedChanged: (v) => setState(() => _speed = v),
                    onColorModeChanged: (v) => setState(() => _colorMode = v),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'slot_text · MIT',
                    style: Studio.mono(
                      size: 10.5,
                      color: Studio.faint,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _split({
    required bool compact,
    required Widget left,
    required Widget right,
  }) {
    if (compact) {
      return Column(children: [left, const SizedBox(height: 16), right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 11, child: left),
        const SizedBox(width: 16),
        Expanded(flex: 9, child: right),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.controller, required this.compact});

  final SlotTextController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StudioPanel(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          const StudioBackdrop(),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 24 : 48,
              vertical: compact ? 36 : 56,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    StudioChip('FLUTTER PACKAGE', color: Studio.lime),
                    SizedBox(width: 8),
                    StudioChip('ZERO DEPS', color: Studio.violet),
                  ],
                ),
                SizedBox(height: compact ? 26 : 38),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SlotText.controller(
                    controller: controller,
                    style: Studio.display(
                      size: compact ? 68 : 116,
                      letterSpacing: compact ? 0 : 1,
                    ),
                  ),
                ),
                SizedBox(height: compact ? 18 : 24),
                Text('Only the glyphs that change roll.', style: Studio.body()),
                SizedBox(height: compact ? 26 : 36),
                const _HeroTicker(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTicker extends StatelessWidget {
  const _HeroTicker();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const _LiveClock(),
        Text('/', style: Studio.mono(size: 12, color: Studio.faint)),
        Text(
          'v0.0.1',
          style: Studio.mono(
            size: 12,
            color: Studio.muted,
            weight: FontWeight.w700,
          ),
        ),
        Text('/', style: Studio.mono(size: 12, color: Studio.faint)),
        Text(
          'MIT',
          style: Studio.mono(
            size: 12,
            color: Studio.muted,
            weight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _timer;
  String _time = _now();

  static String _now() {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _time = _now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlotText(
      _time,
      options: const SlotTextOptions(
        direction: SlotTextDirection.up,
        duration: Duration(milliseconds: 300),
        stagger: Duration(milliseconds: 30),
        exitOffset: Duration(milliseconds: 36),
        bounce: 0.2,
      ),
      style: Studio.mono(size: 12, color: Studio.lime, weight: FontWeight.w700),
    );
  }
}

// ---------------------------------------------------------------------------
// Idle trio
// ---------------------------------------------------------------------------

class _IdleTrio extends StatelessWidget {
  const _IdleTrio({
    required this.compact,
    required this.ellipsis,
    required this.wave,
    required this.scramble,
  });

  final bool compact;
  final SlotTextController ellipsis;
  final SlotTextController wave;
  final SlotTextController scramble;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _IdleCard(
        title: 'ellipsis',
        signature: 'SlotWaiting.ellipsis()',
        accent: Studio.lime,
        controller: ellipsis,
      ),
      _IdleCard(
        title: 'wave',
        signature: 'SlotWaiting.wave()',
        accent: Studio.sky,
        controller: wave,
      ),
      _IdleCard(
        title: 'builder',
        signature: 'SlotWaiting.builder(...)',
        accent: Studio.violet,
        controller: scramble,
      ),
    ];
    if (compact) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            cards[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _IdleCard extends StatelessWidget {
  const _IdleCard({
    required this.title,
    required this.signature,
    required this.accent,
    required this.controller,
  });

  final String title;
  final String signature;
  final Color accent;
  final SlotTextController controller;

  @override
  Widget build(BuildContext context) {
    return StudioPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              StudioCaption('waiting / $title', color: accent),
            ],
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Studio.inset,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Studio.border),
            ),
            child: SizedBox(
              height: 92,
              width: double.infinity,
              child: Center(
                child: SlotText.controller(
                  controller: controller,
                  style: Studio.display(size: 23, letterSpacing: 0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(signature, style: Studio.mono(size: 11, color: Studio.faint)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live board
// ---------------------------------------------------------------------------

class _BoardRowData {
  _BoardRowData(this.symbol, this.price);

  final String symbol;
  double price;
  double deltaPct = 0;
  bool up = true;
}

class _LiveBoard extends StatefulWidget {
  const _LiveBoard();

  @override
  State<_LiveBoard> createState() => _LiveBoardState();
}

class _LiveBoardState extends State<_LiveBoard> {
  final _random = math.Random(42);
  late final List<_BoardRowData> _rows;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _rows = [
      _BoardRowData('BTC', 67412.50),
      _BoardRowData('ETH', 3521.08),
      _BoardRowData('SOL', 142.77),
      _BoardRowData('LINK', 18.43),
    ];
    _timer = Timer.periodic(const Duration(milliseconds: 2100), (_) => _tick());
  }

  void _tick() {
    setState(() {
      final touched = <int>{
        _random.nextInt(_rows.length),
        _random.nextInt(_rows.length),
      };
      for (final i in touched) {
        final row = _rows[i];
        final pct =
            (_random.nextDouble() * 1.4 + 0.05) * (_random.nextBool() ? 1 : -1);
        row.deltaPct = pct;
        row.up = pct >= 0;
        row.price = math.max(0.01, row.price * (1 + pct / 100));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    final dot = s.indexOf('.');
    final b = StringBuffer();
    for (var i = 0; i < dot; i++) {
      final rem = dot - i;
      b.write(s[i]);
      if (rem > 1 && rem % 3 == 1) {
        b.write(',');
      }
    }
    b.write(s.substring(dot));
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return StudioPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: StudioCaption('live board')),
              StudioCaption('direction follows delta', color: Studio.faint),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Divider(height: 1, color: Studio.border),
              ),
            _BoardRow(data: _rows[i], fmt: _fmt),
          ],
        ],
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.data, required this.fmt});

  final _BoardRowData data;
  final String Function(double) fmt;

  @override
  Widget build(BuildContext context) {
    final tone = data.deltaPct == 0
        ? Studio.muted
        : data.up
        ? Studio.lime
        : Studio.rose;
    final options = SlotTextOptions(
      direction: data.up ? SlotTextDirection.up : SlotTextDirection.down,
      duration: const Duration(milliseconds: 320),
      stagger: const Duration(milliseconds: 26),
      exitOffset: const Duration(milliseconds: 38),
      bounce: 0.25,
      color: tone,
    );
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            data.symbol,
            style: Studio.mono(
              size: 12,
              color: Studio.muted,
              weight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: SlotText(
            fmt(data.price),
            options: options,
            style: Studio.mono(
              size: 21,
              color: Studio.text,
              weight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 76,
          child: Align(
            alignment: Alignment.centerRight,
            child: SlotText(
              data.deltaPct == 0
                  ? '--'
                  : '${data.up ? '+' : '-'}'
                        '${data.deltaPct.abs().toStringAsFixed(2)}%',
              options: options,
              style: Studio.mono(
                size: 12,
                color: tone,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Operation
// ---------------------------------------------------------------------------

class _OperationPanel extends StatelessWidget {
  const _OperationPanel({
    required this.controller,
    required this.phase,
    required this.onStart,
    required this.onComplete,
    required this.onFail,
    required this.onReset,
  });

  final SlotTextController controller;
  final _Phase phase;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onFail;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final phaseColor = switch (phase) {
      _Phase.idle => Studio.muted,
      _Phase.waiting => Studio.amber,
      _Phase.done => Studio.lime,
      _Phase.failed => Studio.rose,
    };
    final phaseLabel = switch (phase) {
      _Phase.idle => 'IDLE',
      _Phase.waiting => 'WAITING',
      _Phase.done => 'DONE',
      _Phase.failed => 'FAILED',
    };
    return StudioPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: StudioCaption('async operation')),
              _PhaseChip(label: phaseLabel, color: phaseColor),
            ],
          ),
          const SizedBox(height: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SlotText.controller(
              controller: controller,
              style: Studio.display(size: 46, letterSpacing: 0),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StudioButton(
                onPressed: onStart,
                icon: Icons.play_arrow_rounded,
                child: const Text('Start'),
              ),
              StudioButton(
                onPressed: onComplete,
                icon: Icons.check_rounded,
                filled: false,
                child: const Text('Complete'),
              ),
              StudioButton(
                onPressed: onFail,
                icon: Icons.close_rounded,
                filled: false,
                accent: Studio.rose,
                child: const Text('Fail'),
              ),
              StudioButton(
                onPressed: onReset,
                icon: Icons.restart_alt_rounded,
                filled: false,
                accent: Studio.muted,
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'The loop runs until the handle is completed, failed, or '
            'cancelled. Re-taps on Start are ignored.',
            style: Studio.body(size: 12),
          ),
        ],
      ),
    );
  }
}

/// Status chip whose label rolls between phases.
class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SlotText(
        label,
        options: SlotTextOptions(
          direction: SlotTextDirection.up,
          duration: const Duration(milliseconds: 240),
          stagger: const Duration(milliseconds: 22),
          exitOffset: const Duration(milliseconds: 30),
          bounce: 0.2,
          color: color,
        ),
        style: Studio.mono(
          size: 10.5,
          color: color,
          weight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counter + motion desk
// ---------------------------------------------------------------------------

class _CounterPanel extends StatelessWidget {
  const _CounterPanel({
    required this.count,
    required this.options,
    required this.onIncrement,
    required this.onDecrement,
    required this.onJump,
  });

  final int count;
  final SlotTextOptions options;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    return StudioPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: StudioCaption('counter')),
              StudioCaption('direction follows delta', color: Studio.faint),
            ],
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Studio.inset,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Studio.border),
            ),
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: Center(
                child: SlotText(
                  // Default skipUnchanged: true — only digits that actually
                  // change roll; the rest of the number stays planted.
                  '$count',
                  options: options,
                  style: Studio.mono(
                    size: 52,
                    color: Studio.text,
                    weight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _RoundIcon(icon: Icons.remove_rounded, onTap: onDecrement),
              const SizedBox(width: 8),
              _RoundIcon(icon: Icons.add_rounded, onTap: onIncrement),
              const Spacer(),
              StudioButton(
                onPressed: onJump,
                filled: false,
                accent: Studio.violet,
                icon: Icons.bolt_rounded,
                child: const Text('+111'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onTap,
      style: IconButton.styleFrom(
        side: const BorderSide(color: Studio.borderBright),
        foregroundColor: Studio.text,
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _MotionDesk extends StatelessWidget {
  const _MotionDesk({
    required this.directionUp,
    required this.speed,
    required this.colorMode,
    required this.copyController,
    required this.copyOptions,
    required this.onDirectionChanged,
    required this.onSpeedChanged,
    required this.onColorModeChanged,
  });

  final bool directionUp;
  final double speed;
  final _ColorMode colorMode;
  final SlotTextController copyController;
  final SlotTextOptions copyOptions;
  final ValueChanged<bool> onDirectionChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<_ColorMode> onColorModeChanged;

  @override
  Widget build(BuildContext context) {
    return StudioPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: StudioCaption('motion desk')),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Only the digits roll; the unit is a plain static label.
                  SlotText(
                    '${speed.round()}',
                    options: const SlotTextOptions(
                      direction: SlotTextDirection.up,
                      duration: Duration(milliseconds: 160),
                      stagger: Duration(milliseconds: 14),
                    ),
                    style: Studio.mono(
                      size: 12,
                      color: Studio.lime,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    ' MS',
                    style: Studio.mono(
                      size: 12,
                      color: Studio.lime,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Roll upward',
                  style: Studio.body(color: Studio.text),
                ),
              ),
              Switch(value: directionUp, onChanged: onDirectionChanged),
            ],
          ),
          Slider(
            min: 140,
            max: 700,
            divisions: 28,
            value: speed,
            onChanged: onSpeedChanged,
          ),
          const SizedBox(height: 8),
          SegmentedButton<_ColorMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _ColorMode.mono, label: Text('Mono')),
              ButtonSegment(
                value: _ColorMode.chromatic,
                label: Text('Chromatic'),
              ),
            ],
            selected: {colorMode},
            onSelectionChanged: (s) => onColorModeChanged(s.first),
          ),
          const SizedBox(height: 18),
          Center(
            child: StudioButton(
              onPressed: () {
                copyController.flash(
                  'Copied',
                  options: SlotTextFlashOptions(
                    enter: copyOptions,
                    exit: copyOptions.copyWith(
                      clearColor: true,
                      direction: copyOptions.direction == SlotTextDirection.up
                          ? SlotTextDirection.down
                          : SlotTextDirection.up,
                    ),
                  ),
                );
              },
              icon: Icons.copy_rounded,
              child: SlotText.controller(
                controller: copyController,
                options: copyOptions,
                style: Studio.mono(
                  size: 12.5,
                  color: Studio.background,
                  weight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
