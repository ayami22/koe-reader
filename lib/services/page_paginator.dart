import 'package:flutter/material.dart';
import '../models/chapter.dart';

class ReaderPage {
  final int startIndex;
  final int endIndex;
  final List<Sentence> sentences;

  const ReaderPage({
    required this.startIndex,
    required this.endIndex,
    required this.sentences,
  });
}

class PagePaginator {
  static List<ReaderPage> paginate({
    required List<Sentence> sentences,
    required Size size,
    required double fontSize,
    required double lineHeight,
    required bool showFurigana,
  }) {
    if (sentences.isEmpty || size.width <= 0 || size.height <= 0) {
      return const [];
    }

    final pages = <ReaderPage>[];
    var cursor = 0;
    final rubyReserve = showFurigana ? fontSize * 0.55 : 0.0;
    final linePx = fontSize * lineHeight + rubyReserve;
    final imageHeight = (size.height * 0.72).clamp(120.0, size.height);

    while (cursor < sentences.length) {
      var used = 0.0;
      final start = cursor;
      while (cursor < sentences.length) {
        final sentence = sentences[cursor];
        final need = sentence.isIllustration
            ? imageHeight
            : _textHeight(sentence.text, size.width, fontSize, linePx);
        if (used > 0 && used + need > size.height) break;
        used += need;
        cursor++;
        if (sentence.isIllustration && used >= size.height * 0.6) break;
      }
      if (cursor == start) cursor++;
      pages.add(ReaderPage(
        startIndex: start,
        endIndex: cursor,
        sentences: sentences.sublist(start, cursor),
      ));
    }
    return pages;
  }

  static int pageIndexForSentence(List<ReaderPage> pages, int sentenceIndex) {
    for (var i = 0; i < pages.length; i++) {
      if (sentenceIndex >= pages[i].startIndex &&
          sentenceIndex < pages[i].endIndex) {
        return i;
      }
    }
    return pages.isEmpty ? 0 : pages.length - 1;
  }

  static double _textHeight(
    String text,
    double width,
    double fontSize,
    double linePx,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    final lines = painter.computeLineMetrics().length.clamp(1, 40);
    return lines * linePx + 10;
  }
}
