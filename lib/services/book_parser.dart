import 'dart:convert';
import 'dart:io';
import 'package:epubx/epubx.dart';
import '../models/chapter.dart';

class BookParser {
  Future<List<Chapter>> parseEpub(String filePath) async {
    return parseEpubBytes(await File(filePath).readAsBytes());
  }

  Future<List<Chapter>> parseEpubBytes(List<int> bytes) async {
    final book = await EpubReader.readBook(bytes);
    final chapters = <Chapter>[];
    _collectChapters(book.Chapters ?? [], chapters);
    if (chapters.isEmpty) {
      chapters.add(Chapter(
        index: 0,
        title: book.Title ?? '本文',
        content: '',
        sentences: const [],
      ));
    }
    return chapters;
  }

  void _collectChapters(List<EpubChapter> source, List<Chapter> out) {
    for (final epubChapter in source) {
      final plainText = stripHtml(epubChapter.HtmlContent ?? '');
      if (plainText.isNotEmpty) {
        out.add(Chapter(
          index: out.length,
          title: (epubChapter.Title?.trim().isNotEmpty ?? false)
              ? epubChapter.Title!.trim()
              : '第${out.length + 1}章',
          content: plainText,
          sentences: splitSentences(plainText),
        ));
      }
      final nested = epubChapter.SubChapters;
      if (nested != null && nested.isNotEmpty) {
        _collectChapters(nested, out);
      }
    }
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
      return utf8.decode(bytes.sublist(3));
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
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"');
    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
    return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}
