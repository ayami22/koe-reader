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
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primaryContainer.withAlpha(120)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: showFurigana && sentence.furiganaSegments.isNotEmpty
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

    return Wrap(
      children: sentence.furiganaSegments.map((seg) {
        if (!seg.hasFurigana) {
          return Text(
            seg.text,
            style: TextStyle(
              fontSize: fontSize,
              height: lineHeight,
              color: textColor,
            ),
          );
        }
        return _RubyText(
          text: seg.text,
          ruby: seg.furigana!,
          fontSize: fontSize,
          textColor: textColor,
          rubyColor: rubyColor,
        );
      }).toList(),
    );
  }
}

class _RubyText extends StatelessWidget {
  final String text;
  final String ruby;
  final double fontSize;
  final Color textColor;
  final Color rubyColor;

  const _RubyText({
    required this.text,
    required this.ruby,
    required this.fontSize,
    required this.textColor,
    required this.rubyColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ruby,
          style: TextStyle(
            fontSize: fontSize * 0.45,
            color: rubyColor,
            height: 1.0,
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            color: textColor,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
