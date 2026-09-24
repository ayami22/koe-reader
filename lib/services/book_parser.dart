import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/chapter.dart';
import 'epub_parser.dart';

class HtmlBlock {
  final String? text;
  final Uint8List? image;

  const HtmlBlock.text(this.text) : image = null;
  const HtmlBlock.image(this.image) : text = null;

  bool get isImage => image != null && image!.isNotEmpty;
}

class BookParser {
  Future<List<Chapter>> parseEpub(String filePath) async {
    return parseEpubBytes(await File(filePath).readAsBytes());
  }

  Future<List<Chapter>> parseEpubBytes(List<int> bytes) async {
    return parseEpubDocument(bytes).chapters;
  }

  EpubParseResult parseEpubDocument(List<int> bytes) {
    return EpubParser(this).parse(bytes);
  }

  Future<List<Chapter>> parseTxt(String filePath) async {
    return parseTxtContent(await _readTextFile(filePath));
  }

  Future<String> _readTextFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return decodeBytes(bytes);
  }

  String decodeBytes(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  List<Chapter> parseTxtContent(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final paragraphs = normalized.split(RegExp(r'\n\s*\n'));
    final chapters = <Chapter>[];

    var chapterBuffer = StringBuffer();
    var chapterTitle = 'はじめに';

    void flush() {
      if (chapterBuffer.isEmpty) return;
      final text = chapterBuffer.toString().trim();
      if (text.isEmpty) return;
      chapters.add(Chapter(
        index: chapters.length,
        title: chapterTitle,
        content: text,
        sentences: splitSentences(text),
      ));
      chapterBuffer.clear();
    }

    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isEmpty) continue;

      if (isChapterHeading(trimmed)) {
        flush();
        chapterTitle = trimmed.replaceAll('\n', ' ');
      } else {
        if (chapterBuffer.isNotEmpty) chapterBuffer.write('\n');
        chapterBuffer.write(trimmed);
      }
    }
    flush();

    if (chapters.isEmpty) {
      chapters.add(Chapter(
        index: 0,
        title: '本文',
        content: normalized,
        sentences: splitSentences(normalized),
      ));
    }
    return chapters;
  }

  Future<List<Chapter>> parsePdf(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final extracted = _extractPdfText(bytes);
    if (extracted.trim().isEmpty) {
      return [
        Chapter(
          index: 0,
          title: 'PDF',
          content: 'このPDFから本文を抽出できませんでした。TXTまたはEPUBをご利用ください。',
          sentences: splitSentences('このPDFから本文を抽出できませんでした。TXTまたはEPUBをご利用ください。'),
        ),
      ];
    }
    return parseTxtContent(extracted);
  }

  String _extractPdfText(List<int> bytes) {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final buffer = StringBuffer();
    final streamPattern = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
    for (final match in streamPattern.allMatches(raw)) {
      final chunk = match.group(1) ?? '';
      final textObjects = RegExp(r'\((?:\\.|[^\\)])*\)\s*Tj').allMatches(chunk);
      for (final t in textObjects) {
        var s = t.group(0)!;
        s = s.replaceAll(RegExp(r'\s*Tj$'), '');
        if (s.startsWith('(') && s.endsWith(')')) {
          s = s.substring(1, s.length - 1);
        }
        s = s
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\r', '')
            .replaceAll(r'\t', ' ')
            .replaceAll(r'\(', '(')
            .replaceAll(r'\)', ')');
        buffer.write(s);
      }
    }
    return buffer.toString();
  }

  List<HtmlBlock> parseHtmlDocument(
    String html, {
    Uint8List? Function(String src)? resolveImage,
  }) {
    var cleaned = html
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<head[^>]*>[\s\S]*?</head>', caseSensitive: false),
          '',
        );

    final blocks = <HtmlBlock>[];
    final tokenRe = RegExp(
      r'<img\b[^>]*>|<svg\b[\s\S]*?</svg>|<br\s*/?>|</p>|</div>|</h[1-6]>|</li>|</tr>|</blockquote>',
      caseSensitive: false,
    );
    var cursor = 0;
    final textBuf = StringBuffer();

    void flushText() {
      final text = decodeEntities(textBuf.toString())
          .replaceAll(RegExp(r'[ \t]+\n'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
      textBuf.clear();
      if (text.isEmpty) return;
      blocks.add(HtmlBlock.text(text));
    }

    void appendHtmlChunk(String chunk) {
      var text = chunk
          .replaceAll(RegExp(r'<rt\b[^>]*>[\s\S]*?</rt>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<rp\b[^>]*>[\s\S]*?</rp>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<[^>]+>'), '');
      textBuf.write(text);
    }

    for (final match in tokenRe.allMatches(cleaned)) {
      appendHtmlChunk(cleaned.substring(cursor, match.start));
      final token = match.group(0)!;
      final lower = token.toLowerCase();
      if (lower.startsWith('<img')) {
        flushText();
        final src = _imgSrc(token);
        final image = src == null ? null : resolveImage?.call(src);
        if (image != null) {
          blocks.add(HtmlBlock.image(image));
        }
      } else if (lower.startsWith('<svg')) {
        flushText();
      } else {
        textBuf.write('\n');
      }
      cursor = match.end;
    }
    appendHtmlChunk(cleaned.substring(cursor));
    flushText();
    return blocks;
  }

  Chapter chapterFromBlocks({
    required int index,
    required String title,
    required List<HtmlBlock> blocks,
  }) {
    final sentences = <Sentence>[];
    final content = StringBuffer();
    for (final block in blocks) {
      if (block.isImage) {
        sentences.add(Sentence(
          index: sentences.length,
          text: '',
          startOffset: 0,
          endOffset: 0,
          imageBytes: block.image,
        ));
        continue;
      }
      final text = block.text ?? '';
      if (content.isNotEmpty) content.write('\n');
      content.write(text);
      for (final sentence in splitSentences(text)) {
        sentences.add(Sentence(
          index: sentences.length,
          text: sentence.text,
          startOffset: sentence.startOffset,
          endOffset: sentence.endOffset,
        ));
      }
    }
    if (sentences.isEmpty) {
      sentences.addAll(splitSentences(content.toString()));
    }
    return Chapter(
      index: index,
      title: title,
      content: content.toString(),
      sentences: sentences,
    );
  }

  String? _imgSrc(String tag) {
    final match = RegExp(
          r'''(?:src|xlink:href)\s*=\s*["']([^"']+)["']''',
          caseSensitive: false,
        ).firstMatch(tag) ??
        RegExp(
          r'src\s*=\s*([^\s>]+)',
          caseSensitive: false,
        ).firstMatch(tag);
    return match?.group(1);
  }

  List<Sentence> splitSentences(String text) {
    final sentences = <Sentence>[];
    final pattern = RegExp(
      r'[^。！？!?…\n]+(?:[。！？!?]|…{1,3})?[」』】]*',
    );
    var index = 0;
    for (final match in pattern.allMatches(text)) {
      final s = match.group(0)?.trim();
      if (s == null || s.isEmpty) continue;
      sentences.add(Sentence(
        index: index,
        text: s,
        startOffset: match.start,
        endOffset: match.end,
      ));
      index++;
    }
    return sentences;
  }

  bool isChapterHeading(String text) {
    final line = text.split('\n').first.trim();
    if (line.length > 40) return false;
    return RegExp(
      r'^(第[一二三四五六七八九十百千0-9０-９]+\s*[章節話回編巻].*|'
      r'第\s*\d+\s*[章節話回編].*|'
      r'Chapter\s+\d+.*|'
      r'プロローグ.*|エピローグ.*|序章.*|終章.*|はじめに|あとがき)$',
    ).hasMatch(line);
  }

  String decodeEntities(String text) {
    var out = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'");
    out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
    out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
    return out;
  }

  String stripHtml(String html) {
    var text = html
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    text = decodeEntities(text);
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}
