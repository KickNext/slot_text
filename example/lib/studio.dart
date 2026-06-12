import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared palette, typography, and building blocks for the studio example.
abstract final class Studio {
  /// When false (tests), system fonts are used and no font fetching happens.
  static bool fontsEnabled = true;

  static const background = Color(0xff09090d);
  static const surface = Color(0xff101016);
  static const surfaceRaised = Color(0xff15151d);
  static const inset = Color(0xff0c0c11);
  static const border = Color(0xff22222c);
  static const borderBright = Color(0xff31313d);
  static const text = Color(0xfff5f3f9);
  static const muted = Color(0xff8e8c9a);
  static const faint = Color(0xff55535f);
  static const lime = Color(0xffc8ff4d);
  static const violet = Color(0xff8b7cff);
  static const sky = Color(0xff56c8ff);
  static const rose = Color(0xffff5c87);
  static const amber = Color(0xffffb84d);

  /// Display face: Archivo Black — single heavy weight, poster energy.
  static TextStyle display({
    double size = 64,
    Color color = text,
    double height = 1.0,
    double letterSpacing = -1,
  }) {
    final style = TextStyle(
      color: color,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: FontWeight.w900,
    );
    return fontsEnabled
        ? GoogleFonts.archivoBlack(textStyle: style)
        : style;
  }

  /// Technical face: Space Mono — captions, numbers, code.
  static TextStyle mono({
    double size = 12,
    Color color = muted,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1.4,
  }) {
    final style = TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      fontFamilyFallback: const ['Menlo', 'Consolas', 'monospace'],
    );
    return fontsEnabled ? GoogleFonts.spaceMono(textStyle: style) : style;
  }

  /// Body face: system, quiet on purpose.
  static TextStyle body({
    double size = 13.5,
    Color color = muted,
    double height = 1.55,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(color: color, fontSize: size, height: height, fontWeight: weight);
  }
}

/// Rounded panel with the studio border treatment.
class StudioPanel extends StatelessWidget {
  const StudioPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = Studio.surface,
    this.borderColor = Studio.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Tiny uppercase mono caption used above blocks.
class StudioCaption extends StatelessWidget {
  const StudioCaption(this.label, {super.key, this.color = Studio.muted});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Studio.mono(
        size: 10.5,
        color: color,
        weight: FontWeight.w700,
        letterSpacing: 2.6,
      ),
    );
  }
}

/// Small outlined pill chip with a mono label.
class StudioChip extends StatelessWidget {
  const StudioChip(this.label, {super.key, this.color = Studio.muted});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: Studio.mono(
            size: 10.5,
            color: color,
            weight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Action button: filled accent or quiet outline, mono label.
class StudioButton extends StatelessWidget {
  const StudioButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.accent = Studio.lime,
    this.filled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final Color accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final textStyle = Studio.mono(
      size: 12.5,
      weight: FontWeight.w700,
      letterSpacing: 0.8,
      color: filled ? Studio.background : accent,
    );
    final style = filled
        ? FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Studio.background,
            textStyle: textStyle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.45)),
            textStyle: textStyle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          );
    if (icon == null) {
      return filled
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton(onPressed: onPressed, style: style, child: child);
    }
    return filled
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
            label: child,
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
            label: child,
          );
  }
}

/// Faint blueprint grid + soft radial glows, used behind the hero.
class StudioBackdrop extends StatelessWidget {
  const StudioBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            Positioned(
              top: -180,
              right: -120,
              child: _glow(Studio.violet, 460),
            ),
            Positioned(
              bottom: -220,
              left: -140,
              child: _glow(Studio.lime, 520),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.13), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const cell = 56.0;
    for (var x = 0.0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
