import 'package:flutter_test/flutter_test.dart';
import 'package:koe_reader/providers/library_provider.dart';

void main() {
  late LibraryProvider library;

  setUp(() {
    library = LibraryProvider();
  });

  test('detectFormat maps extensions', () {
    expect(library.detectFormat('epub'), isNotNull);
    expect(library.detectFormat('PDF'), isNotNull);
    expect(library.detectFormat('txt'), isNotNull);
    expect(library.detectFormat('docx'), isNull);
  });

  test('extractTitle strips extension', () {
    expect(library.extractTitle('桜の午後.txt'), '桜の午後');
    expect(library.extractTitle('book.epub'), 'book');
  });
}
