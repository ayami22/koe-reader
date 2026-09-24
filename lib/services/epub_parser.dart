import 'dart:typed_data';
import '../models/chapter.dart';
import 'book_parser.dart';
import 'zip_archive.dart';

class EpubParseResult {
  final String title;
  final String? author;
  final Uint8List? cover;
  final List<Chapter> chapters;

  const EpubParseResult({
    required this.title,
    this.author,
    this.cover,
    required this.chapters,
  });
}

class EpubParser {
  EpubParser(this._bookParser);

  final BookParser _bookParser;

  EpubParseResult parse(List<int> bytes) {
    final files = ZipArchive.extract(bytes);
    if (files.isEmpty) {
      throw const FormatException('EPUB archive is empty');
    }

    final opfPath = _opfPath(files);
    final opf = _decode(files[opfPath]);
    if (opf == null) {
      throw const FormatException('EPUB is missing OPF');
    }

    final baseDir = _dirOf(opfPath);
    final manifest = _parseManifest(opf, baseDir);
    final spineIds = _parseSpine(opf);
    final meta = _parseMetadata(opf);
    final tocTitles = _parseTocTitles(files, manifest, baseDir, opf);

    final chapters = <Chapter>[];
    final seenHtml = <String>{};

    for (final id in spineIds) {
      final item = manifest[id];
      if (item == null) continue;
      if (_isImageName(item.href) || item.mediaType.startsWith('image/')) {
        final bytes = files[item.href];
        if (bytes != null && _looksLikeImage(bytes)) {
          chapters.add(Chapter(
            index: chapters.length,
            title: tocTitles[item.href] ??
                tocTitles[_basename(item.href)] ??
                '挿絵',
            content: '',
            sentences: [
              Sentence(
                index: 0,
                text: '',
                startOffset: 0,
                endOffset: 0,
                imageBytes: bytes,
              ),
            ],
          ));
        }
        continue;
      }
      if (!_isHtml(item.mediaType, item.href)) continue;
      if (!seenHtml.add(item.href)) continue;
      final html = _decode(files[item.href]);
      if (html == null) continue;
      final blocks = _bookParser.parseHtmlDocument(
        html,
        resolveImage: (src) => _resolveImage(files, item.href, src),
      );
      if (blocks.isEmpty) continue;
      final title = tocTitles[item.href] ??
          tocTitles[_basename(item.href)] ??
          _headingTitle(html) ??
          '第${chapters.length + 1}章';
      chapters.add(_bookParser.chapterFromBlocks(
        index: chapters.length,
        title: title,
        blocks: blocks,
      ));
    }

    if (chapters.isEmpty) {
      for (final file in files.entries) {
        if (!_isHtml('', file.key)) continue;
        final html = _decode(file.value);
        if (html == null) continue;
        final blocks = _bookParser.parseHtmlDocument(
          html,
          resolveImage: (src) => _resolveImage(files, file.key, src),
        );
        if (blocks.isEmpty) continue;
        chapters.add(_bookParser.chapterFromBlocks(
          index: chapters.length,
          title: _headingTitle(html) ?? _basename(file.key),
          blocks: blocks,
        ));
      }
    }

    return EpubParseResult(
      title: meta.title ?? 'EPUB',
      author: meta.author,
      cover: _cover(files, manifest, meta.coverId),
      chapters: chapters,
    );
  }

  String _opfPath(Map<String, Uint8List> files) {
    final container = _decode(_lookup(files, 'META-INF/container.xml'));
    if (container != null) {
      final match = RegExp(
        r'full-path\s*=\s*"([^"]+)"',
        caseSensitive: false,
      ).firstMatch(container);
      if (match != null) {
        final path = _norm(match.group(1)!);
        if (files.containsKey(path)) return path;
      }
    }
    for (final name in files.keys) {
      if (name.toLowerCase().endsWith('.opf')) return name;
    }
    throw const FormatException('EPUB is missing container.xml / OPF');
  }

  Map<String, _ManifestItem> _parseManifest(String opf, String baseDir) {
    final out = <String, _ManifestItem>{};
    final itemRe = RegExp(r'<item\b([^>]*)/?>', caseSensitive: false);
    for (final match in itemRe.allMatches(opf)) {
      final attrs = match.group(1) ?? '';
      final id = _attr(attrs, 'id');
      final href = _attr(attrs, 'href');
      if (id == null || href == null) continue;
      out[id] = _ManifestItem(
        id: id,
        href: _resolve(baseDir, Uri.decodeFull(href)),
        mediaType: _attr(attrs, 'media-type') ?? '',
        properties: _attr(attrs, 'properties') ?? '',
      );
    }
    return out;
  }

  List<String> _parseSpine(String opf) {
    final spine = RegExp(
      r'<spine\b[^>]*>([\s\S]*?)</spine>',
      caseSensitive: false,
    ).firstMatch(opf)?.group(1);
    if (spine == null) return const [];
    return RegExp(r'idref\s*=\s*"([^"]+)"', caseSensitive: false)
        .allMatches(spine)
        .map((m) => m.group(1)!)
        .toList();
  }

  _Meta _parseMetadata(String opf) {
    String? first(String tag) {
      final match = RegExp(
        '<(?:[\\w.-]+:)?$tag\\b[^>]*>([^<]+)</(?:[\\w.-]+:)?$tag>',
        caseSensitive: false,
      ).firstMatch(opf);
      final text = match?.group(1)?.trim();
      if (text == null || text.isEmpty) return null;
      return _bookParser.decodeEntities(text);
    }

    final coverMeta = RegExp(
      r'<meta\b[^>]*name\s*=\s*"cover"[^>]*content\s*=\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(opf);
    final coverMetaAlt = RegExp(
      r'<meta\b[^>]*content\s*=\s*"([^"]+)"[^>]*name\s*=\s*"cover"',
      caseSensitive: false,
    ).firstMatch(opf);

    return _Meta(
      title: first('title'),
      author: first('creator'),
      coverId: coverMeta?.group(1) ?? coverMetaAlt?.group(1),
    );
  }

  Map<String, String> _parseTocTitles(
    Map<String, Uint8List> files,
    Map<String, _ManifestItem> manifest,
    String baseDir,
    String opf,
  ) {
    final titles = <String, String>{};
    final ncxItem = manifest.values.where((i) {
      return i.mediaType.contains('ncx') || i.href.toLowerCase().endsWith('.ncx');
    }).firstOrNull;
    if (ncxItem != null) {
      final ncx = _decode(files[ncxItem.href]);
      if (ncx != null) {
        final points = RegExp(
          r'<navPoint\b[\s\S]*?</navPoint>',
          caseSensitive: false,
        );
        for (final block in points.allMatches(ncx)) {
          final chunk = block.group(0)!;
          final text = RegExp(
            r'<text\b[^>]*>([^<]*)</text>',
            caseSensitive: false,
          ).firstMatch(chunk)?.group(1);
          final src = RegExp(
            r'<content\b[^>]*src\s*=\s*"([^"]+)"',
            caseSensitive: false,
          ).firstMatch(chunk)?.group(1);
          if (text == null || src == null) continue;
          final href = _resolve(baseDir, src.split('#').first);
          titles[href] = _bookParser.decodeEntities(text.trim());
          titles[_basename(href)] = titles[href]!;
        }
      }
    }

    for (final item in manifest.values) {
      if (!item.properties.contains('nav') &&
          !item.href.toLowerCase().endsWith('nav.xhtml')) {
        continue;
      }
      final nav = _decode(files[item.href]);
      if (nav == null) continue;
      final links = RegExp(
        r'<a\b[^>]*href\s*=\s*"([^"]+)"[^>]*>([\s\S]*?)</a>',
        caseSensitive: false,
      );
      for (final link in links.allMatches(nav)) {
        final href = _resolve(
          _dirOf(item.href),
          link.group(1)!.split('#').first,
        );
        final label = _bookParser
            .stripHtml(link.group(2) ?? '')
            .replaceAll('\n', ' ')
            .trim();
        if (label.isEmpty) continue;
        titles[href] = label;
        titles[_basename(href)] = label;
      }
    }
    return titles;
  }

  Uint8List? _cover(
    Map<String, Uint8List> files,
    Map<String, _ManifestItem> manifest,
    String? coverId,
  ) {
    if (coverId != null && manifest.containsKey(coverId)) {
      final bytes = files[manifest[coverId]!.href];
      if (bytes != null && _looksLikeImage(bytes)) return bytes;
    }
    for (final item in manifest.values) {
      if (item.properties.contains('cover-image')) {
        final bytes = files[item.href];
        if (bytes != null && _looksLikeImage(bytes)) return bytes;
      }
    }
    for (final entry in files.entries) {
      final name = entry.key.toLowerCase();
      if ((name.contains('cover') || name.contains('jacket')) &&
          _isImageName(name) &&
          _looksLikeImage(entry.value)) {
        return entry.value;
      }
    }
    return null;
  }

  Uint8List? _resolveImage(
    Map<String, Uint8List> files,
    String htmlPath,
    String src,
  ) {
    if (src.isEmpty || src.startsWith('data:')) return null;
    final cleaned = src.split('?').first.split('#').first.trim();
    final decoded = Uri.decodeFull(cleaned);
    final candidates = <String>{
      _norm(decoded),
      _resolve(_dirOf(htmlPath), decoded),
      _basename(decoded),
    };
    for (final key in files.keys) {
      if (candidates.contains(key) ||
          candidates.contains(_basename(key)) ||
          key.endsWith('/$decoded') ||
          key.endsWith('/${_basename(decoded)}')) {
        final bytes = files[key];
        if (bytes != null && _looksLikeImage(bytes)) return bytes;
      }
    }
    return null;
  }

  String? _headingTitle(String html) {
    final match = RegExp(
      r'<h[1-3][^>]*>([\s\S]*?)</h[1-3]>',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;
    final title = _bookParser.stripHtml(match.group(1)!).replaceAll('\n', ' ').trim();
    if (title.isEmpty || title.length > 60) return null;
    return title;
  }

  Uint8List? _lookup(Map<String, Uint8List> files, String path) {
    final want = _norm(path).toLowerCase();
    for (final entry in files.entries) {
      if (entry.key.toLowerCase() == want) return entry.value;
    }
    return null;
  }

  String? _decode(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    return _bookParser.decodeBytes(bytes);
  }

  bool _isHtml(String mediaType, String href) {
    final type = mediaType.toLowerCase();
    final name = href.toLowerCase();
    return type.contains('html') ||
        (type.contains('xml') && name.contains('html')) ||
        name.endsWith('.html') ||
        name.endsWith('.htm') ||
        name.endsWith('.xhtml');
  }

  bool _isImageName(String name) {
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp') ||
        name.endsWith('.bmp');
  }

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 8) return false;
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    if (bytes[0] == 0x89 && bytes[1] == 0x50) return true;
    if (bytes[0] == 0x47 && bytes[1] == 0x49) return true;
    if (bytes[0] == 0x52 && bytes[1] == 0x49) return true;
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
    return false;
  }

  String? _attr(String attrs, String name) {
    return RegExp(
          '$name\\s*=\\s*"([^"]*)"',
          caseSensitive: false,
        ).firstMatch(attrs)?.group(1) ??
        RegExp(
          "$name\\s*=\\s*'([^']*)'",
          caseSensitive: false,
        ).firstMatch(attrs)?.group(1);
  }

  String _resolve(String baseDir, String href) {
    final cleaned = _norm(href.split('#').first);
    if (cleaned.isEmpty) return baseDir;
    if (cleaned.startsWith('/')) return _norm(cleaned);
    if (baseDir.isEmpty) return cleaned;
    final parts = [...baseDir.split('/'), ...cleaned.split('/')];
    final out = <String>[];
    for (final part in parts) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (out.isNotEmpty) out.removeLast();
      } else {
        out.add(part);
      }
    }
    return out.join('/');
  }

  String _dirOf(String path) {
    final i = path.lastIndexOf('/');
    return i == -1 ? '' : path.substring(0, i);
  }

  String _basename(String path) {
    final i = path.replaceAll('\\', '/').lastIndexOf('/');
    return i == -1 ? path : path.substring(i + 1);
  }

  String _norm(String name) =>
      name.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
}

class _ManifestItem {
  final String id;
  final String href;
  final String mediaType;
  final String properties;

  const _ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    required this.properties,
  });
}

class _Meta {
  final String? title;
  final String? author;
  final String? coverId;

  const _Meta({this.title, this.author, this.coverId});
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
