import 'package:flutter_test/flutter_test.dart';
import 'package:koe_reader/services/furigana_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FuriganaService service;

  setUp(() {
    service = FuriganaService();
  });

  tearDown(() {
    service.dispose();
  });

  test('returns plain segment when dictionary is not loaded', () {
    final result = service.annotate('こんにちは世界');
    expect(result.length, 1);
    expect(result.first.text, 'こんにちは世界');
    expect(result.first.hasFurigana, false);
  });

  test('annotates kanji from map dictionary', () {
    service.loadDictionary('{"世界":"せかい","今日":"きょう"}');
    expect(service.isLoaded, isTrue);
    final result = service.annotate('今日は世界です');
    expect(result.any((s) => s.text == '今日' && s.furigana == 'きょう'), isTrue);
    expect(result.any((s) => s.text == '世界' && s.furigana == 'せかい'), isTrue);
  });

  test('loads bundled asset dictionary', () async {
    await service.loadFromAsset();
    expect(service.isLoaded, isTrue);
    expect(service.entryCount, greaterThan(10));
    final result = service.annotate('猫が公園にいました');
    expect(result.any((s) => s.text == '猫' && s.hasFurigana), isTrue);
    expect(result.any((s) => s.text == '公園' && s.hasFurigana), isTrue);
  });

  test('Jmdict list format is accepted', () {
    service.loadDictionary(
      '[{"text":"漢字","reading":"かんじ","furigana":[{"ruby":"漢","rt":"かん"}]}]',
    );
    final result = service.annotate('漢字');
    expect(result.single.furigana, 'かんじ');
  });
}
