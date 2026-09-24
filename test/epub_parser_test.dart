import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koe_reader/services/book_parser.dart';

Uint8List _png1x1() => Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
      0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
      0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x05, 0xFE, 0xD4, 0xEF, 0x00, 0x00,
      0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);

Uint8List buildEpub({bool trailingJunk = false}) {
  final png = _png1x1();
  final archive = Archive();
  void add(String name, String text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add(
    'mimetype',
    'application/epub+zip',
  );
  add(
    'META-INF/container.xml',
    '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''',
  );
  add(
    'OEBPS/content.opf',
    '''<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>桜の午後</dc:title>
    <dc:creator>山田</dc:creator>
    <meta name="cover" content="cover"/>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="cover" href="images/cover.png" media-type="image/png" properties="cover-image"/>
    <item id="chap1" href="text/chap1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="chap1"/>
  </spine>
</package>''',
  );
  add(
    'OEBPS/toc.ncx',
    '''<?xml version="1.0"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="n1">
      <navLabel><text>第一章</text></navLabel>
      <content src="text/chap1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''',
  );
  add(
    'OEBPS/text/chap1.xhtml',
    '''<?xml version="1.0"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<body>
<p>今日はいい天気です。</p>
<img src="../images/cover.png"/>
<p>猫が鳴きました。</p>
</body>
</html>''',
  );
  archive.addFile(ArchiveFile('OEBPS/images/cover.png', png.length, png));
  var bytes = ZipEncoder().encode(archive)!;
  if (trailingJunk) {
    bytes = [...bytes, 0x00, 0xFF, 0x00, 0xFF];
  }
  return Uint8List.fromList(bytes);
}

void main() {
  late BookParser parser;

  setUp(() {
    parser = BookParser();
  });

  test('parses epub text, images, title and author', () {
    final result = parser.parseEpubDocument(buildEpub());
    expect(result.title, '桜の午後');
    expect(result.author, '山田');
    expect(result.cover, isNotNull);
    expect(result.chapters, isNotEmpty);
    expect(result.chapters.first.title, '第一章');
    final kinds = result.chapters.first.sentences.map((s) => s.isIllustration);
    expect(kinds.where((v) => v).length, 1);
    expect(
      result.chapters.first.sentences.any((s) => s.text.contains('今日はいい天気です')),
      isTrue,
    );
    expect(
      result.chapters.first.sentences.any((s) => s.text.contains('猫が鳴きました')),
      isTrue,
    );
  });

  test('parses epub with trailing zip junk', () {
    final result = parser.parseEpubDocument(buildEpub(trailingJunk: true));
    expect(result.chapters, isNotEmpty);
    expect(result.chapters.first.sentences.any((s) => s.isIllustration), isTrue);
  });

  test('parseHtmlDocument keeps image placeholders', () {
    final png = _png1x1();
    final blocks = parser.parseHtmlDocument(
      '<p>前</p><img src="a.png"/><p>後。</p>',
      resolveImage: (src) => src == 'a.png' ? png : null,
    );
    expect(blocks.length, 3);
    expect(blocks[0].text, contains('前'));
    expect(blocks[1].isImage, isTrue);
    expect(blocks[2].text, contains('後'));
  });
}
