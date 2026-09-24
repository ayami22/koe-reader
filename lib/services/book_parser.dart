import 'dart:io';
import 'package:epubx/epubx.dart';
import '../models/book.dart';
import '../models/chapter.dart';

class BookParser {
  Future<List<Chapter>> parseEpub(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final book = await EpubReader.readBook(bytes);
    final chapters = <Chapter>[];

    final htmlChapters = book.Chapters ?? [];
    for (var i = 0; i < htmlChapters.length; i++) {
      final epubChapter = htmlChapters[i];
      final plainText = _stripHtml(epubChapter.HtmlContent ?? '');
      final sentences = _splitSentences(plainText);

      chapters.add(Chapter(
        index: i,
        title: epubChapter.Title ?? '第${i + 1}章',
        content: plainText,
        sentences: sentences,
      ));
    }
    return chapters;
  }

  Future<List<Chapter>> parseTxt(String filePath) async {
    final content = await File(filePath).readAsString();
    final paragraphs = content.split(RegExp(r'\n\s*\n'));
    final chapters = <Chapter>[];

    var chapterBuffer = StringBuffer();
    var chapterIndex = 0;
    var chapterTitle = 'はじめに';

    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isEmpty) continue;

      if (_isChapterHeading(trimmed)) {
        if (chapterBuffer.isNotEmpty) {
          final text = chapterBuffer.toString();
          chapters.add(Chapter(
            index: chapterIndex,
            title: chapterTitle,
            content: text,
            sentences: _splitSentences(text),
          ));
          chapterIndex++;
          chapterBuffer.clear();
        }
        chapterTitle = trimmed;
      } else {
        if (chapterBuffer.isNotEmpty) chapterBuffer.write('\n');
        chapterBuffer.write(trimmed);
      }
    }

    if (chapterBuffer.isNotEmpty) {
      final text = chapterBuffer.toString();
      chapters.add(Chapter(
        index: chapterIndex,
        title: chapterTitle,
        content: text,
        sentences: _splitSentences(text),
      ));
    }

    if (chapters.isEmpty) {
      chapters.add(Chapter(
        index: 0,
        title: '本文',
        content: content,
        sentences: _splitSentences(content),
      ));
    }

    return chapters;
  }

  List<Sentence> _splitSentences(String text) {
    final sentences = <Sentence>[];
    final pattern = RegExp(r'[^。！？\n]+[。！？]?');
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

  bool _isChapterHeading(String text) {
    if (text.length > 50) return false;
    return RegExp(r'^(第[一二三四五六七八九十百千\d]+[章節話回編]|Chapter\s+\d+|プロローグ|エピローグ|序章|終章)')
        .hasMatch(text);
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<p[^>]*>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
