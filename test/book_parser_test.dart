import 'package:flutter_test/flutter_test.dart';
import 'package:koe_reader/services/book_parser.dart';

void main() {
  late BookParser parser;

  setUp(() {
    parser = BookParser();
  });

  test('splits Japanese sentences on 。！？', () {
    final sentences = parser.splitSentences('今日はいい天気です。猫が鳴きました！本当ですか？');
    expect(sentences.map((s) => s.text).toList(), [
      '今日はいい天気です。',
      '猫が鳴きました！',
      '本当ですか？',
    ]);
  });

  test('detects chapter headings', () {
    expect(parser.isChapterHeading('第1章 はじまり'), isTrue);
    expect(parser.isChapterHeading('プロローグ'), isTrue);
    expect(parser.isChapterHeading('今日はいい天気です。'), isFalse);
  });

  test('parseTxtContent splits chapters', () {
    const text = '第1章 はじまり\n\nこんにちは。世界。\n\n第2章 つづき\n\nさようなら。';
    final chapters = parser.parseTxtContent(text);
    expect(chapters.length, 2);
    expect(chapters[0].title, '第1章 はじまり');
    expect(chapters[1].title, '第2章 つづき');
    expect(chapters[0].sentences.length, 2);
  });

  test('stripHtml removes tags and keeps text', () {
    final text = parser.stripHtml('<p>今日は<br/>いい天気です。</p>');
    expect(text.contains('今日は'), isTrue);
    expect(text.contains('<p>'), isFalse);
  });

  test('decodeBytes handles utf8', () {
    final encoded = [0xE6, 0x97, 0xA5, 0xE6, 0x9C, 0xAC, 0xE8, 0xAA, 0x9E];
    expect(parser.decodeBytes(encoded), '日本語');
  });

  test('decodeBytes strips utf8 BOM', () {
    final encoded = [0xEF, 0xBB, 0xBF, 0xE6, 0x97, 0xA5];
    expect(parser.decodeBytes(encoded), '日');
  });
}
