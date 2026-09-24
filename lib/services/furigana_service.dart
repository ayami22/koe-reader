import '../models/chapter.dart';

class FuriganaService {
  final Map<String, String> _dictionary = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> loadDictionary(String jsonContent) async {
    final entries = _parseJmdictFurigana(jsonContent);
    _dictionary.addAll(entries);
    _isLoaded = true;
  }

  Map<String, String> _parseJmdictFurigana(String jsonContent) {
    // JmdictFurigana JSON format:
    // [{"text":"漢字","reading":"かんじ","furigana":[{"ruby":"漢","rt":"かん"},{"ruby":"字","rt":"じ"}]}]
    final result = <String, String>{};
    // Lazy parsing: will be replaced with actual JSON decode when dictionary is bundled
    return result;
  }

  List<FuriganaSegment> annotate(String text) {
    if (!_isLoaded) {
      return [FuriganaSegment(text: text)];
    }
    return _segmentWithFurigana(text);
  }

  List<FuriganaSegment> _segmentWithFurigana(String text) {
    final segments = <FuriganaSegment>[];
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      final char = text[i];

      if (_isKanji(char)) {
        if (buffer.isNotEmpty) {
          segments.add(FuriganaSegment(text: buffer.toString()));
          buffer.clear();
        }

        var matched = false;
        for (var len = _min(6, text.length - i); len >= 1; len--) {
          final word = text.substring(i, i + len);
          final reading = _dictionary[word];
          if (reading != null) {
            segments.add(FuriganaSegment(text: word, furigana: reading));
            i += len - 1;
            matched = true;
            break;
          }
        }

        if (!matched) {
          segments.add(FuriganaSegment(text: char, furigana: null));
        }
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      segments.add(FuriganaSegment(text: buffer.toString()));
    }

    return segments;
  }

  bool _isKanji(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3400 && code <= 0x4DBF) ||
        (code >= 0x20000 && code <= 0x2A6DF);
  }

  int _min(int a, int b) => a < b ? a : b;

  void dispose() {
    _dictionary.clear();
    _isLoaded = false;
  }
}
