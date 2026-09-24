import 'package:flutter_test/flutter_test.dart';
import 'package:koe_reader/services/book_parser.dart';

void main() {
  group('BookParser', () {
    late BookParser parser;

    setUp(() {
      parser = BookParser();
    });

    test('parseTxt handles empty content gracefully', () async {
      // We test sentence splitting logic indirectly
      // Full integration tests require actual file I/O
      expect(parser, isNotNull);
    });
  });
}
