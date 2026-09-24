import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/chapter.dart';

class SentenceView extends StatelessWidget {
  final Sentence sentence;
  final bool isActive;
  final bool showFurigana;
  final double fontSize;
  final double lineHeight;
  final VoidCallback? onTap;

  const SentenceView({
    super.key,
    required this.sentence,
    this.isActive = false,
    this.showFurigana = true,
    this.fontSize = 18.0,
    this.lineHeight = 1.8,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primaryContainer.withAlpha(120)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: sentence.isIllustration
            ? _Illustration(bytes: sentence.imageBytes!)
            : showFurigana && sentence.furiganaSegments.isNotEmpty
                ? _buildFuriganaText(context)
                : _buildPlainText(context),
      ),
    );
  }

  Widget _buildPlainText(BuildContext context) {
    return Text(
      sentence.text,
      style: TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        color: isActive
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildFuriganaText(BuildContext context) {
    final textColor = isActive
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurface;
    final rubyColor = Theme.of(context).colorScheme.primary;
    final rubySize = fontSize * 0.42;
    const rubyGap = 1.0;
    final minHeight = (fontSize + rubySize + rubyGap) / fontSize;

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight < minHeight ? minHeight : lineHeight,
          color: textColor,
        ),
        children: sentence.furiganaSegments.map((seg) {
          if (!seg.hasFurigana) {
            return TextSpan(text: seg.text);
          }
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _RubyPair(
              text: seg.text,
              ruby: seg.furigana!,
              fontSize: fontSize,
              rubySize: rubySize,
              rubyGap: rubyGap,
              textColor: textColor,
              rubyColor: rubyColor,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RubyPair extends StatelessWidget {
  final String text;
  final String ruby;
  final double fontSize;
  final double rubySize;
  final double rubyGap;
  final Color textColor;
  final Color rubyColor;

  const _RubyPair({
    required this.text,
    required this.ruby,
    required this.fontSize,
    required this.rubySize,
    required this.rubyGap,
    required this.textColor,
    required this.rubyColor,
  });

  @override
  Widget build(BuildContext context) {
    final kanjiBaseline = rubySize + rubyGap + fontSize * 0.88;
    return Baseline(
      baseline: kanjiBaseline,
      baselineType: TextBaseline.alphabetic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ruby,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: rubySize,
              height: 1.0,
              color: rubyColor,
            ),
          ),
          SizedBox(height: rubyGap),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.0,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  final Uint8List bytes;
  const _Illustration({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
