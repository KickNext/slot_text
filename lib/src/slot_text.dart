import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Roll direction used by [SlotText].
enum SlotTextDirection {
  /// New glyphs enter from below and old glyphs leave upward.
  up,

  /// New glyphs enter from above and old glyphs leave downward.
  down,
}

/// Builds a color for one glyph.
typedef SlotTextColorBuilder = Color Function(int index, int total);

/// Options for a [SlotText] roll animation.
@immutable
class SlotTextOptions {
  /// Creates roll animation options.
  const SlotTextOptions({
    this.direction = SlotTextDirection.down,
    this.stagger = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 300),
    this.exitOffset = const Duration(milliseconds: 50),
    this.curve = const Cubic(0.34, 1.56, 0.64, 1),
    this.bounce = 0.6,
    this.color,
    this.colorBuilder,
    this.colorFade = const Duration(milliseconds: 280),
    this.skipUnchanged = true,
    this.interrupt = true,
  }) : assert(bounce >= 0);

  /// Roll direction.
  final SlotTextDirection direction;

  /// Delay between glyph starts.
  final Duration stagger;

  /// Per-glyph slide duration.
  final Duration duration;

  /// Delay before incoming glyphs chase outgoing glyphs.
  final Duration exitOffset;

  /// Slide curve.
  final Curve curve;

  /// Amount of deterministic per-glyph timing and tilt variation.
  final double bounce;

  /// Flat color used by incoming glyphs before fading back to the text color.
  final Color? color;

  /// Per-glyph color used by incoming glyphs before fading back.
  final SlotTextColorBuilder? colorBuilder;

  /// Duration of the color fade back to the inherited text color.
  final Duration colorFade;

  /// Keeps equal characters at the same index static.
  final bool skipUnchanged;

  /// Whether a new target snaps an in-flight roll to its target before starting.
  ///
  /// When false, the current roll finishes and only the latest pending target is
  /// played next. This is useful for spam-prone buttons.
  final bool interrupt;

  /// Returns a copy with selected fields changed.
  SlotTextOptions copyWith({
    SlotTextDirection? direction,
    Duration? stagger,
    Duration? duration,
    Duration? exitOffset,
    Curve? curve,
    double? bounce,
    Color? color,
    SlotTextColorBuilder? colorBuilder,
    bool clearColor = false,
    Duration? colorFade,
    bool? skipUnchanged,
    bool? interrupt,
  }) {
    return SlotTextOptions(
      direction: direction ?? this.direction,
      stagger: stagger ?? this.stagger,
      duration: duration ?? this.duration,
      exitOffset: exitOffset ?? this.exitOffset,
      curve: curve ?? this.curve,
      bounce: bounce ?? this.bounce,
      color: clearColor ? color : color ?? this.color,
      colorBuilder: clearColor
          ? colorBuilder
          : colorBuilder ?? this.colorBuilder,
      colorFade: colorFade ?? this.colorFade,
      skipUnchanged: skipUnchanged ?? this.skipUnchanged,
      interrupt: interrupt ?? this.interrupt,
    );
  }

  SlotTextOptions _merge(SlotTextOptions? other) => other ?? this;
}

/// Builds one waiting frame for [SlotWaiting.builder].
///
/// [text] is the base label passed to [SlotTextController.startWaiting] and
/// [tick] is the zero-based loop counter.
typedef SlotWaitingFrameBuilder = String Function(String text, int tick);

enum _SlotWaitingKind { ellipsis, wave, frames, builder }

/// A looping idle animation used by [SlotTextController.startWaiting].
///
/// Presets compile down to the same roll engine as regular text changes, so
/// they inherit direction, curve, stagger, and color from [SlotTextOptions].
@immutable
class SlotWaiting {
  /// Dots roll in one at a time after the label, then all roll away together:
  /// `Load` -> `Load.` -> `Load..` -> `Load...` -> `Load`.
  ///
  /// When [step] is omitted, the cadence is derived from the roll duration so
  /// every dot lands on a steady, metronome-like beat.
  const SlotWaiting.ellipsis({this.dots = 3, this.dot = '.', this.step})
    : assert(dots > 0),
      _kind = _SlotWaitingKind.ellipsis,
      rest = Duration.zero,
      frames = const <String>[],
      frameBuilder = null;

  /// The whole label stays readable and periodically "breathes": a single
  /// stagger wave of self-rolls sweeps across the glyphs, then the label
  /// rests for [rest] before the next sweep.
  ///
  /// Without explicit options the wave uses a calm, non-springy curve and
  /// almost no tilt so the loop reads as a ripple instead of a glitch.
  const SlotWaiting.wave({this.rest = const Duration(milliseconds: 1300)})
    : _kind = _SlotWaitingKind.wave,
      dots = 0,
      dot = '',
      step = null,
      frames = const <String>[],
      frameBuilder = null;

  /// Cycles through explicit [frames] every [step].
  const SlotWaiting.frames(this.frames, {this.step})
    : _kind = _SlotWaitingKind.frames,
      dots = 0,
      dot = '',
      rest = Duration.zero,
      frameBuilder = null;

  /// Generates each frame with [frameBuilder] every [step].
  const SlotWaiting.builder(SlotWaitingFrameBuilder this.frameBuilder, {this.step})
    : _kind = _SlotWaitingKind.builder,
      dots = 0,
      dot = '',
      rest = Duration.zero,
      frames = const <String>[];

  final _SlotWaitingKind _kind;

  /// Maximum number of trailing dots for [SlotWaiting.ellipsis].
  final int dots;

  /// Dot glyph for [SlotWaiting.ellipsis].
  final String dot;

  /// Interval between frames for [ellipsis], [frames], and [builder].
  ///
  /// When null, a steady cadence is derived from the effective roll duration.
  final Duration? step;

  /// Quiet pause between sweeps for [SlotWaiting.wave].
  final Duration rest;

  /// Explicit frames for [SlotWaiting.frames].
  final List<String> frames;

  /// Frame generator for [SlotWaiting.builder].
  final SlotWaitingFrameBuilder? frameBuilder;
}

/// Options for [SlotTextController.flash].
@immutable
class SlotTextFlashOptions {
  /// Creates flash options.
  const SlotTextFlashOptions({
    this.revertAfter = const Duration(milliseconds: 1400),
    this.enter,
    this.exit,
  });

  /// How long the flash text remains before rolling back.
  final Duration revertAfter;

  /// Options for rolling the flash text in.
  final SlotTextOptions? enter;

  /// Options for rolling the original text back in.
  final SlotTextOptions? exit;
}

/// Imperative controller for [SlotText.controller].
class SlotTextController extends ChangeNotifier {
  /// Creates a controller with an initial displayed text.
  SlotTextController({required String initialText}) : _value = initialText;

  Timer? _revertTimer;
  Timer? _progressTimer;
  String _value;
  String? _restingText;
  _SlotTextCommand? _command;
  int _progressEpoch = 0;

  /// The currently requested text.
  String get value => _value;

  _SlotTextCommand? get _currentCommand => _command;

  /// Permanently rolls to [text] and cancels any pending flash revert.
  void set(String text, {SlotTextOptions? options}) {
    _cancelFlash();
    _cancelProgress();
    _emit(text, options);
  }

  /// Temporarily rolls to [text], then rolls back to the previous resting text.
  ///
  /// Repeated calls reset the revert timer instead of queueing extra reverts.
  void flash(
    String text, {
    SlotTextFlashOptions options = const SlotTextFlashOptions(),
  }) {
    _cancelProgress();
    _restingText ??= _value;
    _emit(
      text,
      (options.enter ?? const SlotTextOptions()).copyWith(interrupt: false),
    );

    _revertTimer?.cancel();
    _revertTimer = Timer(options.revertAfter, () {
      final back = _restingText!;
      _restingText = null;
      _revertTimer = null;
      _emit(
        back,
        (options.exit ?? const SlotTextOptions()).copyWith(interrupt: false),
      );
    });
  }

  /// Starts an operation label that keeps rolling until the returned handle is
  /// completed, failed, or cancelled.
  ///
  /// [text] is emitted immediately. [frames] can contain additional intermediate
  /// labels, for example `Exportaa`, `Exportee`, and `Exportii`. Matching
  /// glyphs stay fixed by default, so progress should animate only the
  /// uncertain fragment of the word. When [interval] is omitted, frames tick
  /// fast enough to keep the roll continuous. Set [animateUnchanged] to true for
  /// decorative loops that intentionally re-roll identical glyphs.
  SlotTextProgress startProgress(
    String text, {
    List<String> frames = const <String>[],
    SlotTextOptions? options,
    Duration? interval,
    bool animateUnchanged = false,
  }) {
    final sequence = frames.isEmpty
        ? <String>[text]
        : frames.first == text
        ? List<String>.of(frames)
        : <String>[text, ...frames];
    final progressOptions = (options ?? const SlotTextOptions()).copyWith(
      interrupt: false,
      skipUnchanged: !animateUnchanged,
    );
    final tickInterval =
        interval ??
        Duration(
          milliseconds: (progressOptions.duration.inMilliseconds * 0.55)
              .round()
              .clamp(80, 220)
              .toInt(),
        );

    return _startFrameLoop(
      initial: sequence.first,
      frameAt: (tick) => sequence[tick % sequence.length],
      interval: tickInterval,
      options: progressOptions,
    );
  }

  // Calm motion tuned for the dot/frames loops: short rolls, light bounce.
  static const _tickWaitingDefaults = SlotTextOptions(
    duration: Duration(milliseconds: 240),
    stagger: Duration(milliseconds: 34),
    exitOffset: Duration(milliseconds: 40),
    bounce: 0.25,
  );

  // Calm motion tuned for the breathing wave: slower, no overshoot, almost
  // no tilt, so the loop reads as a ripple instead of a glitch.
  static const _waveWaitingDefaults = SlotTextOptions(
    duration: Duration(milliseconds: 520),
    stagger: Duration(milliseconds: 46),
    exitOffset: Duration(milliseconds: 64),
    curve: Cubic(0.22, 1.0, 0.36, 1.0),
    bounce: 0.1,
  );

  /// Starts a looping idle animation that keeps rolling until the returned
  /// handle is completed, failed, or cancelled.
  ///
  /// [text] is the readable base label. The look of the loop is picked with a
  /// [SlotWaiting] preset: [SlotWaiting.ellipsis] appends rolling dots,
  /// [SlotWaiting.wave] periodically sweeps a re-roll wave across the glyphs,
  /// and [SlotWaiting.frames]/[SlotWaiting.builder] give full control over the
  /// frame sequence.
  ///
  /// ```dart
  /// final handle = controller.startWaiting('Saving');
  /// await save();
  /// handle.complete('Saved');
  /// ```
  ///
  /// Calling [startWaiting] again restarts the loop from the first frame. If
  /// the trigger can be tapped repeatedly, keep the handle and skip re-entry
  /// while [SlotTextProgress.isActive] is true.
  SlotTextProgress startWaiting(
    String text, {
    SlotWaiting waiting = const SlotWaiting.ellipsis(),
    SlotTextOptions? options,
  }) {
    switch (waiting._kind) {
      case _SlotWaitingKind.ellipsis:
        final base = options ?? _tickWaitingDefaults;
        return startProgress(
          text,
          frames: <String>[
            for (var i = 0; i <= waiting.dots; i++) '$text${waiting.dot * i}',
          ],
          interval: waiting.step ?? _steadyStep(base),
          options: base,
        );
      case _SlotWaitingKind.wave:
        final base = options ?? _waveWaitingDefaults;
        final glyphCount = math.max(1, text.characters.length);
        final sweepMs =
            (glyphCount - 1) * base.stagger.inMilliseconds +
            base.exitOffset.inMilliseconds +
            (base.duration.inMilliseconds * (1 + base.bounce * 0.45)).round() +
            (base.color != null || base.colorBuilder != null
                ? base.colorFade.inMilliseconds
                : 0) +
            120;
        return startProgress(
          text,
          interval: Duration(milliseconds: sweepMs) + waiting.rest,
          animateUnchanged: true,
          options: base,
        );
      case _SlotWaitingKind.frames:
        final base = options ?? _tickWaitingDefaults;
        return startProgress(
          text,
          frames: waiting.frames,
          interval: waiting.step ?? _steadyStep(base),
          options: base,
        );
      case _SlotWaitingKind.builder:
        final base = options ?? _tickWaitingDefaults;
        final frame = waiting.frameBuilder!;
        return _startFrameLoop(
          initial: frame(text, 0),
          frameAt: (tick) => frame(text, tick),
          interval: waiting.step ?? _steadyStep(base),
          options: base.copyWith(interrupt: false),
        );
    }
  }

  /// A frame cadence that lets one glyph roll fully finish — including its
  /// bounce variation, exit offset, and color fade — plus a short rest, so
  /// ticks land on a steady beat instead of queueing behind in-flight rolls.
  static Duration _steadyStep(SlotTextOptions options) {
    final rollMs = (options.duration.inMilliseconds * (1 + options.bounce * 0.45))
        .round();
    final fadeMs = options.color != null || options.colorBuilder != null
        ? options.colorFade.inMilliseconds
        : 0;
    return Duration(
      milliseconds:
          rollMs + options.exitOffset.inMilliseconds + fadeMs + 160,
    );
  }

  SlotTextProgress _startFrameLoop({
    required String initial,
    required String Function(int tick) frameAt,
    required Duration interval,
    required SlotTextOptions options,
  }) {
    _cancelFlash();
    _cancelProgress();

    final epoch = ++_progressEpoch;
    var tick = 0;

    _emit(initial, options, force: true);
    _progressTimer = Timer.periodic(interval, (_) {
      if (epoch != _progressEpoch) {
        return;
      }
      tick++;
      _emit(frameAt(tick), options, force: true);
    });

    return SlotTextProgress._(this, epoch);
  }

  void _completeProgress(int epoch, String text, {SlotTextOptions? options}) {
    if (!_isProgressActive(epoch)) {
      return;
    }
    _cancelProgress();
    _emit(text, options);
  }

  void _cancelProgressHandle(
    int epoch, {
    String? text,
    SlotTextOptions? options,
  }) {
    if (!_isProgressActive(epoch)) {
      return;
    }
    _cancelProgress();
    if (text != null) {
      _emit(text, options);
    }
  }

  bool _isProgressActive(int epoch) {
    return _progressTimer != null && _progressEpoch == epoch;
  }

  void _cancelFlash() {
    _revertTimer?.cancel();
    _revertTimer = null;
    _restingText = null;
  }

  void _cancelProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _progressEpoch++;
  }

  void _emit(String text, SlotTextOptions? options, {bool force = false}) {
    _value = text;
    _command = _SlotTextCommand(text, options, force: force);
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelFlash();
    _cancelProgress();
    super.dispose();
  }
}

/// Handle returned by [SlotTextController.startProgress].
///
/// Keep the handle for the async operation that owns the in-progress label and
/// resolve it with [complete] or [fail]. Calling any method after the handle is
/// no longer active is a no-op.
class SlotTextProgress {
  const SlotTextProgress._(this._controller, this._epoch);

  final SlotTextController _controller;
  final int _epoch;

  /// Whether this handle still owns the controller progress loop.
  bool get isActive => _controller._isProgressActive(_epoch);

  /// Stops the progress loop and rolls to [text].
  void complete(String text, {SlotTextOptions? options}) {
    _controller._completeProgress(_epoch, text, options: options);
  }

  /// Stops the progress loop and rolls to an error [text].
  void fail(String text, {SlotTextOptions? options}) {
    complete(text, options: options);
  }

  /// Stops the progress loop. When [text] is provided, it is emitted as the next
  /// resting label.
  void cancel({String? text, SlotTextOptions? options}) {
    _controller._cancelProgressHandle(_epoch, text: text, options: options);
  }
}

/// Returns a per-character rainbow color sweep.
SlotTextColorBuilder chromatic({
  double from = 0,
  double spread = 320,
  double saturation = 0.92,
  double lightness = 0.60,
}) {
  return (index, total) {
    final t = total <= 1 ? 0.0 : index / (total - 1);
    final hue = (from + t * spread) % 360;
    return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
  };
}

/// Text widget that rolls changed glyphs through clipped slots.
class SlotText extends StatefulWidget {
  /// Creates a declarative slot text widget.
  const SlotText(
    this.text, {
    super.key,
    this.options = const SlotTextOptions(),
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.strutStyle,
    this.semanticsLabel,
    this.respectDisableAnimations = true,
  }) : controller = null;

  /// Creates an imperative slot text widget driven by [controller].
  const SlotText.controller({
    super.key,
    required SlotTextController this.controller,
    this.options = const SlotTextOptions(),
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.strutStyle,
    this.semanticsLabel,
    this.respectDisableAnimations = true,
  }) : text = null;

  /// Target text in declarative mode.
  final String? text;

  /// Controller in imperative mode.
  final SlotTextController? controller;

  /// Default animation options.
  final SlotTextOptions options;

  /// Text style.
  final TextStyle? style;

  /// Text alignment.
  final TextAlign? textAlign;

  /// Text direction.
  final TextDirection? textDirection;

  /// Text locale.
  final Locale? locale;

  /// Strut style.
  final StrutStyle? strutStyle;

  /// Accessibility label. Defaults to the current value.
  final String? semanticsLabel;

  /// Snaps to the target text without rolling when the platform requests
  /// reduced motion ([MediaQuery.disableAnimationsOf]).
  final bool respectDisableAnimations;

  @override
  State<SlotText> createState() => _SlotTextState();
}

class _SlotTextState extends State<SlotText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late String _displayedText;
  String? _targetText;
  _RollPlan? _plan;
  _SlotTextCommand? _pending;

  String get _effectiveText => widget.controller?.value ?? widget.text ?? '';

  @override
  void initState() {
    super.initState();
    _displayedText = _effectiveText;
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finishRoll();
        }
      });
    widget.controller?.addListener(_handleControllerChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Snap an in-flight roll when the platform switches to reduced motion.
    if (_animationsDisabled && _targetText != null) {
      _controller.stop();
      _displayedText = _targetText!;
      _targetText = null;
      _plan = null;
      _pending = null;
    }
  }

  @override
  void didUpdateWidget(covariant SlotText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChange);
      widget.controller?.addListener(_handleControllerChange);
      _displayedText = _effectiveText;
      _targetText = null;
      _plan = null;
      _controller.stop();
    } else if (widget.controller == null && oldWidget.text != widget.text) {
      _rollTo(widget.text ?? '', widget.options);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChange);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    if (!mounted) {
      return;
    }
    final command = widget.controller!._currentCommand;
    if (command == null) {
      return;
    }
    _rollTo(
      command.text,
      widget.options._merge(command.options),
      force: command.force,
    );
  }

  bool get _animationsDisabled =>
      widget.respectDisableAnimations &&
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _rollTo(String text, SlotTextOptions options, {bool force = false}) {
    if (_animationsDisabled) {
      _controller.stop();
      setState(() {
        _displayedText = text;
        _targetText = null;
        _plan = null;
        _pending = null;
      });
      return;
    }

    if (_controller.isAnimating && !options.interrupt) {
      if (force || text != _targetText) {
        _pending = _SlotTextCommand(text, options, force: force);
      }
      return;
    }

    if (_controller.isAnimating && options.interrupt && _targetText != null) {
      _controller.stop();
      _displayedText = _targetText!;
      _pending = null;
      _plan = null;
    }

    if (_displayedText == text && !force) {
      setState(() {
        _targetText = text;
      });
      return;
    }

    final plan = _RollPlan.create(
      fromText: _displayedText,
      toText: text,
      options: options,
    );

    setState(() {
      _targetText = text;
      _plan = plan;
    });

    if (!plan.hasMotion) {
      _finishRoll();
      return;
    }

    _controller.duration = plan.totalDuration;
    _controller.forward(from: 0);
  }

  void _finishRoll() {
    final finishedText = _targetText;
    if (finishedText == null) {
      return;
    }
    _controller.stop();
    setState(() {
      _displayedText = finishedText;
      _plan = null;
      _targetText = null;
    });

    final pending = _pending;
    _pending = null;
    if (pending != null && (pending.force || pending.text != _displayedText)) {
      _rollTo(
        pending.text,
        widget.options._merge(pending.options),
        force: pending.force,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final direction =
        widget.textDirection ??
        Directionality.maybeOf(context) ??
        TextDirection.ltr;
    final defaultStyle = DefaultTextStyle.of(context).style;
    final style = defaultStyle.merge(widget.style);
    final visibleText = _targetText ?? _displayedText;
    final plan = _plan;

    Widget child;
    if (plan == null) {
      child = _SettledSlotText(
        text: _displayedText,
        key: const ValueKey('slot_text_settled'),
        style: style,
        textDirection: direction,
        locale: widget.locale,
        strutStyle: widget.strutStyle,
      );
    } else {
      child = AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            key: const ValueKey('slot_text_rolling'),
            mainAxisSize: MainAxisSize.min,
            textDirection: direction,
            children: [
              for (final slot in plan.slots)
                _GlyphSlot(
                  slot: slot,
                  progressMs:
                      _controller.value * plan.totalDuration.inMilliseconds,
                  style: style,
                  textDirection: direction,
                  locale: widget.locale,
                  strutStyle: widget.strutStyle,
                ),
            ],
          );
        },
      );
    }

    return Semantics(
      label: widget.semanticsLabel ?? visibleText,
      child: ExcludeSemantics(child: child),
    );
  }
}

class _SettledSlotText extends StatelessWidget {
  const _SettledSlotText({
    super.key,
    required this.text,
    required this.style,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
  });

  final String text;
  final TextStyle style;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    final metrics = _GlyphMetrics.of(
      context: context,
      style: style,
      textDirection: textDirection,
      locale: locale,
      strutStyle: strutStyle,
      from: text,
      to: text,
    );
    return SizedBox(
      height: metrics.height,
      child: Row(
        key: const ValueKey('slot_text_settled_glyphs'),
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          for (final glyph in text.characters)
            _SettledGlyphSlot(
              glyph,
              height: metrics.height,
              style: style,
              textDirection: textDirection,
              locale: locale,
              strutStyle: strutStyle,
            ),
        ],
      ),
    );
  }
}

class _SettledGlyphSlot extends StatelessWidget {
  const _SettledGlyphSlot(
    this.glyph, {
    required this.height,
    required this.style,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
  });

  final String glyph;
  final double height;
  final TextStyle style;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    final metrics = _GlyphMetrics.of(
      context: context,
      style: style,
      textDirection: textDirection,
      locale: locale,
      strutStyle: strutStyle,
      from: glyph,
      to: glyph,
    );
    return SizedBox(
      width: metrics.toWidth,
      height: height,
      child: Align(
        alignment: Alignment.center,
        child: _GlyphFace(
          glyph,
          width: metrics.toWidth,
          height: height,
          style: style,
          textDirection: textDirection,
          locale: locale,
          strutStyle: strutStyle,
        ),
      ),
    );
  }
}

class _GlyphSlot extends StatelessWidget {
  const _GlyphSlot({
    required this.slot,
    required this.progressMs,
    required this.style,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
  });

  final _SlotPlan slot;
  final double progressMs;
  final TextStyle style;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    if (!slot.changed) {
      return _GlyphText(
        slot.to,
        style: style,
        textDirection: textDirection,
        locale: locale,
        strutStyle: strutStyle,
      );
    }

    final metrics = _GlyphMetrics.of(
      context: context,
      style: style,
      textDirection: textDirection,
      locale: locale,
      strutStyle: strutStyle,
      from: slot.from,
      to: slot.to,
    );
    final width = ui.lerpDouble(
      metrics.fromWidth,
      metrics.toWidth,
      slot.widthT(progressMs),
    )!;
    final textColor =
        style.color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
    final incomingColor = slot.color == null
        ? textColor
        : Color.lerp(slot.color, textColor, slot.colorT(progressMs))!;

    return ClipRect(
      clipper: const _VerticalSlotClipper(),
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: width,
        height: metrics.height,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (slot.from.isNotEmpty)
              Opacity(
                opacity: slot.outOpacity(progressMs),
                child: Transform.translate(
                  offset: Offset(0, slot.outY(progressMs, metrics.height)),
                  child: Transform.rotate(
                    angle: -slot.tiltRadians * slot.outT(progressMs),
                    child: _GlyphFace(
                      slot.from,
                      width: metrics.fromWidth,
                      height: metrics.height,
                      style: style,
                      textDirection: textDirection,
                      locale: locale,
                      strutStyle: strutStyle,
                    ),
                  ),
                ),
              ),
            if (slot.to.isNotEmpty)
              Transform.translate(
                offset: Offset(0, slot.inY(progressMs, metrics.height)),
                child: Transform.rotate(
                  angle: slot.tiltRadians * (1 - slot.inT(progressMs)),
                  child: _GlyphFace(
                    slot.to,
                    width: metrics.toWidth,
                    height: metrics.height,
                    style: style.copyWith(color: incomingColor),
                    textDirection: textDirection,
                    locale: locale,
                    strutStyle: strutStyle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VerticalSlotClipper extends CustomClipper<Rect> {
  const _VerticalSlotClipper();

  @override
  Rect getClip(Size size) {
    const horizontalBleed = 100000.0;
    return Rect.fromLTRB(
      -horizontalBleed,
      0,
      size.width + horizontalBleed,
      size.height,
    );
  }

  @override
  bool shouldReclip(covariant _VerticalSlotClipper oldClipper) => false;
}

class _GlyphFace extends StatelessWidget {
  const _GlyphFace(
    this.text, {
    required this.width,
    required this.height,
    required this.style,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
  });

  final String text;
  final double width;
  final double height;
  final TextStyle style;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      alignment: Alignment.center,
      minWidth: width,
      maxWidth: width,
      minHeight: height,
      maxHeight: height,
      child: Center(
        child: _GlyphText(
          text,
          style: style,
          textDirection: textDirection,
          locale: locale,
          strutStyle: strutStyle,
        ),
      ),
    );
  }
}

class _GlyphText extends StatelessWidget {
  const _GlyphText(
    this.text, {
    required this.style,
    required this.textDirection,
    required this.locale,
    required this.strutStyle,
  });

  final String text;
  final TextStyle style;
  final TextDirection textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      textDirection: textDirection,
      locale: locale,
      strutStyle: strutStyle,
      softWrap: false,
    );
  }
}

class _GlyphMetrics {
  const _GlyphMetrics({
    required this.fromWidth,
    required this.toWidth,
    required this.height,
  });

  final double fromWidth;
  final double toWidth;
  final double height;

  static _GlyphMetrics of({
    required BuildContext context,
    required TextStyle style,
    required TextDirection textDirection,
    required Locale? locale,
    required StrutStyle? strutStyle,
    required String from,
    required String to,
  }) {
    final textScaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final fromSize = _measure(
      text: from.isEmpty ? ' ' : from,
      style: style,
      textDirection: textDirection,
      locale: locale,
      strutStyle: strutStyle,
      textScaler: textScaler,
    );
    final toSize = _measure(
      text: to.isEmpty ? ' ' : to,
      style: style,
      textDirection: textDirection,
      locale: locale,
      strutStyle: strutStyle,
      textScaler: textScaler,
    );
    final textHeight = math.max(fromSize.height, toSize.height);
    final verticalBreathingRoom = math.max(6.0, textHeight * 0.18);
    return _GlyphMetrics(
      fromWidth: from.isEmpty ? 0 : fromSize.width,
      toWidth: to.isEmpty ? 0 : toSize.width,
      height: textHeight + verticalBreathingRoom * 2,
    );
  }

  static Size _measure({
    required String text,
    required TextStyle style,
    required TextDirection textDirection,
    required Locale? locale,
    required StrutStyle? strutStyle,
    required TextScaler textScaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      strutStyle: strutStyle,
      maxLines: 1,
    )..layout();
    return painter.size;
  }
}

class _SlotTextCommand {
  const _SlotTextCommand(this.text, this.options, {this.force = false});

  final String text;
  final SlotTextOptions? options;
  final bool force;
}

class _RollPlan {
  const _RollPlan({required this.slots, required this.totalDuration});

  final List<_SlotPlan> slots;
  final Duration totalDuration;

  bool get hasMotion => slots.any((slot) => slot.changed);

  static _RollPlan create({
    required String fromText,
    required String toText,
    required SlotTextOptions options,
  }) {
    final fromChars = fromText.characters.toList();
    final toChars = toText.characters.toList();
    final maxLen = math.max(fromChars.length, toChars.length);
    var maxEndMs = 1;
    // The stagger cascade runs across *changed* slots only, so a diff that
    // touches just the tail (counters, ellipsis dots) starts instantly instead
    // of inheriting dead delay from untouched leading glyphs.
    var changeOrder = 0;
    final slots = <_SlotPlan>[];

    for (var i = 0; i < maxLen; i++) {
      final from = i < fromChars.length ? fromChars[i] : '';
      final to = i < toChars.length ? toChars[i] : '';
      final unchanged = from == to && (options.skipUnchanged || from.isEmpty);
      final isTail = to.isEmpty;
      final durationMs = math.max(
        1,
        (options.duration.inMilliseconds *
                (isTail ? 0.75 : 1.0) *
                (1 + options.bounce * 0.45 * _wobble(i, 1)))
            .round(),
      );
      // Removed tail slots cascade faster so shrinking feels like one motion.
      final staggerIndex = isTail ? changeOrder * 0.5 : changeOrder.toDouble();
      final baseMs = unchanged
          ? 0
          : math.max(
              0,
              (staggerIndex *
                      options.stagger.inMilliseconds *
                      (1 + options.bounce * 0.25 * _wobble(i, 2)))
                  .round(),
            );
      // An incoming glyph only waits for exitOffset when it has to chase an
      // outgoing one; an empty slot fills immediately.
      final exitOffsetMs = from.isEmpty ? 0 : options.exitOffset.inMilliseconds;
      final color = options.colorBuilder?.call(i, maxLen) ?? options.color;
      final endMs =
          baseMs +
          exitOffsetMs +
          durationMs +
          (color == null ? 0 : options.colorFade.inMilliseconds);
      if (!unchanged) {
        changeOrder++;
        maxEndMs = math.max(maxEndMs, endMs + 80);
      }
      slots.add(
        _SlotPlan(
          from: from,
          to: to,
          changed: !unchanged,
          baseMs: baseMs,
          durationMs: durationMs,
          exitOffsetMs: exitOffsetMs,
          colorFadeMs: options.colorFade.inMilliseconds,
          direction: options.direction,
          curve: options.curve,
          color: color,
          tiltRadians: options.bounce * 5 * math.pi / 180 * _wobble(i, 3),
        ),
      );
    }

    return _RollPlan(
      slots: slots,
      totalDuration: Duration(milliseconds: maxEndMs),
    );
  }
}

class _SlotPlan {
  const _SlotPlan({
    required this.from,
    required this.to,
    required this.changed,
    required this.baseMs,
    required this.durationMs,
    required this.exitOffsetMs,
    required this.colorFadeMs,
    required this.direction,
    required this.curve,
    required this.color,
    required this.tiltRadians,
  });

  final String from;
  final String to;
  final bool changed;
  final int baseMs;
  final int durationMs;
  final int exitOffsetMs;
  final int colorFadeMs;
  final SlotTextDirection direction;
  final Curve curve;
  final Color? color;
  final double tiltRadians;

  double outT(double nowMs) => _curved(nowMs, baseMs, durationMs);

  double outOpacity(double nowMs) {
    final t = outT(nowMs);
    return 1 - _smoothstep((t - 0.78) / 0.22);
  }

  double inT(double nowMs) => _curved(nowMs, baseMs + exitOffsetMs, durationMs);

  double widthT(double nowMs) {
    if (to.isEmpty) {
      return _linear(
        nowMs,
        baseMs + (durationMs * 0.55).round(),
        math.max(140, (durationMs * 0.6).round()),
      );
    }
    if (from.isEmpty) {
      return _linear(nowMs, baseMs, math.max(140, (durationMs * 0.45).round()));
    }
    return _linear(nowMs, baseMs, durationMs);
  }

  double colorT(double nowMs) {
    if (color == null || colorFadeMs <= 0) {
      return 1;
    }
    return _linear(nowMs, baseMs + exitOffsetMs + durationMs, colorFadeMs);
  }

  double outY(double nowMs, double height) {
    final sign = direction == SlotTextDirection.down ? 1.0 : -1.0;
    return sign * height * outT(nowMs);
  }

  double inY(double nowMs, double height) {
    final sign = direction == SlotTextDirection.down ? -1.0 : 1.0;
    return sign * height * (1 - inT(nowMs));
  }

  double _curved(double nowMs, int startMs, int spanMs) {
    return curve.transform(_linear(nowMs, startMs, spanMs)).clamp(0.0, 1.0);
  }
}

double _linear(double nowMs, int startMs, int spanMs) {
  if (spanMs <= 0) {
    return nowMs >= startMs ? 1 : 0;
  }
  return ((nowMs - startMs) / spanMs).clamp(0.0, 1.0);
}

double _smoothstep(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _wobble(int i, int salt) {
  final n = math.sin((i + 1) * 12.9898 + salt * 78.233) * 43758.5453;
  return (n - n.floor()) * 2 - 1;
}
