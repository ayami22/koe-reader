import 'package:flutter_test/flutter_test.dart';
import 'package:koe_reader/services/furigana_service.dart';
import 'package:koe_reader/models/chapter.dart';

void main() {
  group('FuriganaService', () {
    late FuriganaService service;

    setUp(() {
      service = FuriganaService();
    });

    test('returns plain segment when dictionary is not loaded', () {
      final result = service.annotate('こんにちは世界');
      expect(result.length, 1);
      expect(result.first.text, 'こんにちは世界');
      expect(result.first.hasFurigana, false);
    });

    test('isLoaded is false by default', () {
      expect(service.isLoaded, false);
    });

    tearDown(() {
      service.dispose();
    });
  });

  group('Sentence', () {
    test('creates sentence with correct offsets', () {
      final sentence = Sentence(
        index: 0,
        text: '今日はいい天気です。',
        startOffset: 0,
        endOffset: 10,
      );
      expect(sentence.text, '今日はいい天気です。');
      expect(sentence.index, 0);
    });
  });

  group('FuriganaSegment', () {
    test('hasFurigana returns true when furigana is set', () {
      const seg = FuriganaSegment(text: '漢字', furigana: 'かんじ');
      expect(seg.hasFurigana, true);
    });

    test('hasFurigana returns false when furigana is null', () {
      const seg = FuriganaSegment(text: 'テスト');
      expect(seg.hasFurigana, false);
    });

    test('hasFurigana returns false when furigana is empty', () {
      const seg = FuriganaSegment(text: 'テスト', furigana: '');
      expect(seg.hasFurigana, false);
    });
  });
}
