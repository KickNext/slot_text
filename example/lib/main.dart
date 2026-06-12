import 'package:flutter/material.dart';
import 'package:slot_text/slot_text.dart';

import 'recipes_page.dart';
import 'showcase_page.dart';
import 'studio.dart';

void main() {
  runApp(const SlotTextExampleApp());
}

class SlotTextExampleApp extends StatelessWidget {
  const SlotTextExampleApp({super.key, this.useGoogleFonts = true});

  /// Set to false in widget tests to avoid runtime font fetching.
  final bool useGoogleFonts;

  @override
  Widget build(BuildContext context) {
    Studio.fontsEnabled = useGoogleFonts;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: Studio.lime,
          brightness: Brightness.dark,
        ).copyWith(
          surface: Studio.background,
          primary: Studio.lime,
          secondary: Studio.violet,
          onSurface: Studio.text,
          onSurfaceVariant: Studio.muted,
          outlineVariant: Studio.border,
        );
    return MaterialApp(
      title: 'slot_text studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: Studio.background,
        sliderTheme: SliderThemeData(
          activeTrackColor: Studio.lime,
          thumbColor: Studio.lime,
          inactiveTrackColor: Studio.border,
          overlayColor: Studio.lime.withValues(alpha: 0.10),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(Studio.background),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Studio.lime
                : Studio.border,
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Studio.border),
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Studio.background
                  : Studio.muted,
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Studio.lime
                  : Colors.transparent,
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: Studio.muted),
        ),
      ),
      home: const StudioShell(),
    );
  }
}

class StudioShell extends StatefulWidget {
  const StudioShell({super.key});

  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(page: _page, onPageChanged: (p) => setState(() => _page = p)),
            const Divider(height: 1, color: Studio.border),
            Expanded(
              child: IndexedStack(
                index: _page,
                children: const [ShowcasePage(), RecipesPage()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.page, required this.onPageChanged});

  final int page;
  final ValueChanged<int> onPageChanged;

  static const _rollOptions = SlotTextOptions(
    direction: SlotTextDirection.up,
    duration: Duration(milliseconds: 260),
    stagger: Duration(milliseconds: 22),
    exitOffset: Duration(milliseconds: 32),
    bounce: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Studio.lime,
              borderRadius: BorderRadius.circular(11),
            ),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: Text(
                  'ST',
                  style: Studio.display(
                    size: 14,
                    color: Studio.background,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (!compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'slot_text',
                  style: Studio.display(size: 15, letterSpacing: 0),
                ),
                // The current page name rolls on switch.
                SlotText(
                  page == 0 ? 'SHOWCASE' : 'RECIPES',
                  options: _rollOptions,
                  style: Studio.mono(
                    size: 9.5,
                    color: Studio.faint,
                    weight: FontWeight.w700,
                    letterSpacing: 2.2,
                  ),
                ),
              ],
            ),
          const Spacer(),
          // One toggle: the label names the other page and rolls on tap.
          OutlinedButton.icon(
            onPressed: () => onPageChanged(page == 0 ? 1 : 0),
            style: OutlinedButton.styleFrom(
              foregroundColor: Studio.text,
              side: const BorderSide(color: Studio.borderBright),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            icon: const Icon(Icons.arrow_outward_rounded, size: 15),
            label: SlotText(
              page == 0 ? 'RECIPES' : 'SHOWCASE',
              options: _rollOptions.copyWith(
                direction: page == 0
                    ? SlotTextDirection.up
                    : SlotTextDirection.down,
              ),
              style: Studio.mono(
                size: 12,
                color: Studio.text,
                weight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
