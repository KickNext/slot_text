import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slot_text/slot_text.dart';

import 'studio.dart';

/// Dark code block with lightweight Dart highlighting and a copy button.
///
/// The copy button label is itself a [SlotText] driven by `flash()` — the
/// example dogfoods the package everywhere it can.
class CodeView extends StatefulWidget {
  const CodeView({super.key, required this.code});

  final String code;

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  late final SlotTextController _copy;

  @override
  void initState() {
    super.initState();
    _copy = SlotTextController(initialText: 'copy');
  }

  @override
  void dispose() {
    _copy.dispose();
    super.dispose();
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    _copy.flash(
      'copied',
      options: const SlotTextFlashOptions(
        enter: SlotTextOptions(
          duration: Duration(milliseconds: 220),
          stagger: Duration(milliseconds: 20),
          color: Studio.lime,
        ),
        exit: SlotTextOptions(
          duration: Duration(milliseconds: 220),
          stagger: Duration(milliseconds: 20),
          direction: SlotTextDirection.up,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Studio.inset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Studio.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'DART',
                    style: Studio.mono(
                      size: 10,
                      color: Studio.faint,
                      weight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _copyCode,
                  style: TextButton.styleFrom(
                    foregroundColor: Studio.muted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: SlotText.controller(
                    controller: _copy,
                    style: Studio.mono(size: 12, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Studio.border),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: _HighlightedDart(code: widget.code),
          ),
        ],
      ),
    );
  }
}

class _HighlightedDart extends StatelessWidget {
  const _HighlightedDart({required this.code});

  final String code;

  static const _keyword = Color(0xffc792ea);
  static const _string = Color(0xffc3e88d);
  static const _comment = Color(0xff5c6370);
  static const _type = Color(0xff82aaff);
  static const _number = Color(0xfff78c6c);
  static const _plain = Color(0xffd6d3e0);

  static final _pattern = RegExp(
    r"(//[^\n]*)"
    r"|('(?:[^'\\\n]|\\.)*')"
    r'|\b(abstract|as|async|await|break|case|class|const|continue|else|enum|'
    r'extends|false|final|for|if|import|in|late|new|null|required|return|'
    r'show|static|super|switch|this|true|var|void|while|with|yield)\b'
    r'|(@\w+)'
    r'|\b(\d+(?:\.\d+)?)\b'
    r'|\b([A-Z][A-Za-z0-9_]*)\b',
  );

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in _pattern.allMatches(code)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: code.substring(cursor, match.start)));
      }
      final color = match.group(1) != null
          ? _comment
          : match.group(2) != null
          ? _string
          : match.group(3) != null
          ? _keyword
          : match.group(4) != null
          ? _keyword
          : match.group(5) != null
          ? _number
          : _type;
      final style = TextStyle(
        color: color,
        fontStyle: match.group(1) != null ? FontStyle.italic : null,
      );
      spans.add(TextSpan(text: match.group(0), style: style));
      cursor = match.end;
    }
    if (cursor < code.length) {
      spans.add(TextSpan(text: code.substring(cursor)));
    }
    return SelectableText.rich(
      TextSpan(
        style: Studio.mono(size: 12.5, color: _plain, height: 1.55),
        children: spans,
      ),
    );
  }
}
