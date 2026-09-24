import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koe_reader/models/chapter.dart';
import 'package:koe_reader/services/page_paginator.dart';
import 'package:koe_reader/widgets/sentence_view.dart';

void main() {
  test('paginates sentences into multiple pages', () {
    final sentences = List.generate(
      20,
      (i) => Sentence(
        index: i,
        text: 'これはページ分割のテストです。長い文章を繰り返します。' * 4,
        startOffset: 0,
        endOffset: 10,
      ),
    );
    final pages = PagePaginator.paginate(
      sentences: sentences,
      size: const Size(320, 480),
      fontSize: 18,
      lineHeight: 1.8,
      showFurigana: true,
    );
    expect(pages.length, greaterThan(1));
    expect(pages.first.startIndex, 0);
    expect(pages.last.endIndex, 20);
    expect(
      PagePaginator.pageIndexForSentence(pages, pages.last.startIndex),
      pages.length - 1,
    );
  });

  testWidgets('ruby shares a line with surrounding kana', (tester) async {
    final sentence = Sentence(
      index: 0,
      text: '今日は世界です',
      startOffset: 0,
      endOffset: 6,
      furiganaSegments: const [
        FuriganaSegment(text: '今日', furigana: 'きょう'),
        FuriganaSegment(text: 'は'),
        FuriganaSegment(text: '世界', furigana: 'せかい'),
        FuriganaSegment(text: 'です'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SentenceView(
            sentence: sentence,
            showFurigana: true,
            fontSize: 20,
            lineHeight: 1.8,
          ),
        ),
      ),
    );
    expect(find.text('きょう'), findsOneWidget);
    expect(find.text('今日'), findsOneWidget);
    expect(find.textContaining('は'), findsWidgets);
  });
}
