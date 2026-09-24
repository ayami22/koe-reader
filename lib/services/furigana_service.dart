import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/chapter.dart';

class FuriganaService {
  final Map<String, String> _dictionary = {};
  int _maxKeyLength = 1;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  int get entryCount => _dictionary.length;

  Future<void> loadFromAsset([String assetPath = 'assets/dict/furigana.json']) async {
    final jsonContent = await rootBundle.loadString(assetPath);
    loadDictionary(jsonContent);
  }

  void loadDictionary(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    if (decoded is Map) {
      decoded.forEach((key, value) {
        final word = key.toString();
        final reading = value.toString();
        if (word.isEmpty || reading.isEmpty) return;
        _dictionary[word] = reading;
        if (word.length > _maxKeyLength) _maxKeyLength = word.length;
      });
    } else if (decoded is List) {
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final word = (entry['text'] ?? '').toString();
        final reading = (entry['reading'] ?? '').toString();
        if (word.isEmpty || reading.isEmpty) continue;
        _dictionary[word] = reading;
        if (word.length > _maxKeyLength) _maxKeyLength = word.length;
      }
    }
    _isLoaded = _dictionary.isNotEmpty;
  }

  List<Sentence> annotateChapter(List<Sentence> sentences) {
    return sentences
        .map(
          (s) => Sentence(
            index: s.index,
            text: s.text,
            startOffset: s.startOffset,
            endOffset: s.endOffset,
            furiganaSegments: s.isIllustration ? const [] : annotate(s.text),
            imageBytes: s.imageBytes,
          ),
        )
        .toList();
  }

  List<FuriganaSegment> annotate(String text) {
    if (!_isLoaded || text.isEmpty) {
      return [FuriganaSegment(text: text)];
    }
    return _segmentWithFurigana(text);
  }

  List<FuriganaSegment> _segmentWithFurigana(String text) {
    final segments = <FuriganaSegment>[];
    final buffer = StringBuffer();
    final units = text.runes.toList();
    var i = 0;

    while (i < units.length) {
      final char = String.fromCharCode(units[i]);
      if (_isKanji(units[i])) {
        if (buffer.isNotEmpty) {
          segments.add(FuriganaSegment(text: buffer.toString()));
          buffer.clear();
        }
        var matched = false;
        final maxLen = _min(_maxKeyLength, units.length - i);
        for (var len = maxLen; len >= 1; len--) {
          final word = String.fromCharCodes(units.sublist(i, i + len));
          final reading = _dictionary[word];
          if (reading != null) {
            segments.add(FuriganaSegment(text: word, furigana: reading));
            i += len;
            matched = true;
            break;
          }
        }
        if (!matched) {
          segments.add(FuriganaSegment(text: char));
          i++;
        }
      } else {
        buffer.write(char);
        i++;
      }
    }

    if (buffer.isNotEmpty) {
      segments.add(FuriganaSegment(text: buffer.toString()));
    }
    return _mergePlain(segments);
  }

  List<FuriganaSegment> _mergePlain(List<FuriganaSegment> input) {
    if (input.length < 2) return input;
    final out = <FuriganaSegment>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isEmpty) return;
      out.add(FuriganaSegment(text: buf.toString()));
      buf.clear();
    }

    for (final seg in input) {
      if (seg.hasFurigana) {
        flush();
        out.add(seg);
      } else {
        buf.write(seg.text);
      }
    }
    flush();
    return out;
  }

  bool _isKanji(int code) {
    return (code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3400 && code <= 0x4DBF) ||
        (code >= 0xF900 && code <= 0xFAFF);
  }

  int _min(int a, int b) => a < b ? a : b;

  void dispose() {
    _dictionary.clear();
    _isLoaded = false;
  }
}
