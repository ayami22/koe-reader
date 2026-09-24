import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koe_reader/services/zip_archive.dart';

void main() {
  Uint8List zipWith(Map<String, List<int>> files) {
    final archive = Archive();
    files.forEach((name, content) {
      archive.addFile(ArchiveFile(name, content.length, content));
    });
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  test('extracts a normal zip', () {
    final zip = zipWith({
      'hello.txt': [1, 2, 3, 4],
    });
    final files = ZipArchive.extract(zip);
    expect(files['hello.txt'], [1, 2, 3, 4]);
  });

  test('repairs trailing junk after EOCD', () {
    final zip = zipWith({
      'a.txt': [9, 8, 7],
    });
    final dirty = Uint8List.fromList([...zip, 0, 1, 2, 3, 4, 5, 6, 7]);
    final files = ZipArchive.extract(dirty);
    expect(files['a.txt'], [9, 8, 7]);
  });

  test('strips leading junk before local header', () {
    final zip = zipWith({
      'b.txt': [5, 5, 5],
    });
    final dirty = Uint8List.fromList([0x00, 0x11, 0x22, ...zip]);
    final files = ZipArchive.extract(dirty);
    expect(files['b.txt'], [5, 5, 5]);
  });
}
