import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A beautifully styled code block with syntax highlighting appearance.
///
/// Features:
/// - Dark code editor theme
/// - Line numbers (optional)
/// - Copy to clipboard button
/// - Keyword/string/comment coloring (simple regex-based)
class CodeBlock extends StatelessWidget {
  final String code;
  final String? title;
  final bool showLineNumbers;
  final bool showCopyButton;

  const CodeBlock({
    super.key,
    required this.code,
    this.title,
    this.showLineNumbers = false,
    this.showCopyButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final lines = code.split('\n');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                // Traffic light dots
                Row(
                  children: [
                    _Dot(color: const Color(0xFFFF5F56)),
                    const SizedBox(width: 6),
                    _Dot(color: const Color(0xFFFFBD2E)),
                    const SizedBox(width: 6),
                    _Dot(color: const Color(0xFF27C93F)),
                  ],
                ),
                const SizedBox(width: 16),
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (showCopyButton) _CopyButton(code: code),
              ],
            ),
          ),

          // Code content
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line numbers
                  if (showLineNumbers)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                          lines.length,
                          (i) => Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono, SF Mono, monospace',
                              fontSize: 13,
                              height: 1.6,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Code
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines.map((line) => _buildLine(line)).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLine(String line) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'JetBrains Mono, SF Mono, monospace',
          fontSize: 13,
          height: 1.6,
        ),
        children: _highlightSyntax(line),
      ),
    );
  }

  List<TextSpan> _highlightSyntax(String line) {
    final spans = <TextSpan>[];

    // Simple syntax highlighting using regex
    final patterns = [
      // Comments
      (RegExp(r'//.*$'), const Color(0xFF6B7280)),
      // Strings
      (RegExp(r"'[^']*'"), const Color(0xFFA5D6A7)),
      // Keywords
      (
        RegExp(
            r'\b(final|const|var|void|async|await|class|extends|return|if|else|for|while|new|this|super|try|catch|throw|import|export|from|get|set|static|late|required)\b'),
        const Color(0xFFFF79C6)
      ),
      // Types
      (
        RegExp(
            r'\b(String|int|double|bool|List|Map|Set|Future|Stream|dynamic|Object|Function|Type|void)\b'),
        const Color(0xFF8BE9FD)
      ),
      // Numbers
      (RegExp(r'\b\d+\.?\d*\b'), const Color(0xFFBD93F9)),
      // Function calls
      (RegExp(r'\b\w+(?=\()'), const Color(0xFF50FA7B)),
      // Properties/methods after dot
      (RegExp(r'(?<=\.)\w+'), const Color(0xFFF8F8F2)),
    ];

    // Default color
    const defaultColor = Color(0xFFF8F8F2);

    // Build a list of colored segments
    final segments = <({int start, int end, Color color})>[];

    for (final (pattern, color) in patterns) {
      for (final match in pattern.allMatches(line)) {
        segments.add((start: match.start, end: match.end, color: color));
      }
    }

    // Sort by start position
    segments.sort((a, b) => a.start.compareTo(b.start));

    // Remove overlapping segments (keep first)
    final cleanSegments = <({int start, int end, Color color})>[];
    for (final seg in segments) {
      final overlaps = cleanSegments.any(
        (s) => seg.start < s.end && seg.end > s.start,
      );
      if (!overlaps) {
        cleanSegments.add(seg);
      }
    }

    // Build spans
    int pos = 0;
    for (final seg in cleanSegments) {
      if (pos < seg.start) {
        spans.add(TextSpan(
          text: line.substring(pos, seg.start),
          style: TextStyle(color: defaultColor),
        ));
      }
      spans.add(TextSpan(
        text: line.substring(seg.start, seg.end),
        style: TextStyle(color: seg.color),
      ));
      pos = seg.end;
    }

    if (pos < line.length) {
      spans.add(TextSpan(
        text: line.substring(pos),
        style: TextStyle(color: defaultColor),
      ));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: line, style: TextStyle(color: defaultColor)));
    }

    return spans;
  }
}

class _Dot extends StatelessWidget {
  final Color color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String code;

  const _CopyButton({required this.code});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _copy,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check : Icons.copy,
                size: 14,
                color: _copied ? Colors.green : Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                _copied ? 'Copied!' : 'Copy',
                style: TextStyle(
                  fontSize: 11,
                  color: _copied ? Colors.green : Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
