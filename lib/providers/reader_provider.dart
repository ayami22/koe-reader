import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/book_parser.dart';
import '../services/furigana_service.dart';

class ReaderProvider extends ChangeNotifier {
  final BookParser _parser = BookParser();
  final FuriganaService furiganaService;

  Book? _currentBook;
  List<Chapter> _chapters = [];
  int _currentChapterIndex = 0;
  int _currentSentenceIndex = 0;
  bool _isLoading = false;
  String? _error;
  String _query = '';

  ReaderProvider({FuriganaService? furiganaService})
      : furiganaService = furiganaService ?? FuriganaService();

  Book? get currentBook => _currentBook;
  List<Chapter> get chapters => _chapters;
  int get currentChapterIndex => _currentChapterIndex;
  int get currentSentenceIndex => _currentSentenceIndex;
  Chapter? get currentChapter =>
      _chapters.isNotEmpty ? _chapters[_currentChapterIndex] : null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get query => _query;

  double get progress {
    if (_chapters.isEmpty) return 0;
    var total = 0;
    var done = 0;
    for (var i = 0; i < _chapters.length; i++) {
      final n = _chapters[i].sentences.length;
      total += n;
      if (i < _currentChapterIndex) done += n;
    }
    done += _currentSentenceIndex;
    if (total == 0) return 0;
    return (done / total).clamp(0.0, 1.0);
  }

  String get progressLabel {
    final chapter = currentChapter;
    if (chapter == null || chapter.sentences.isEmpty) return '';
    final page = _currentSentenceIndex + 1;
    return '${_currentChapterIndex + 1}/${_chapters.length}  ·  $page/${chapter.sentences.length}';
  }

  Future<void> ensureFuriganaLoaded() async {
    if (furiganaService.isLoaded) return;
    try {
      await furiganaService.loadFromAsset();
    } catch (_) {
      furiganaService.loadDictionary('{}');
    }
  }

  Future<void> openBook(Book book) async {
    _isLoading = true;
    _error = null;
    _currentBook = book;
    _query = '';
    notifyListeners();

    try {
      await ensureFuriganaLoaded();
      List<Chapter> parsed;
      switch (book.format) {
        case BookFormat.epub:
          parsed = await _parser.parseEpub(book.filePath);
          break;
        case BookFormat.txt:
          parsed = await _parser.parseTxt(book.filePath);
          break;
        case BookFormat.pdf:
          parsed = await _parser.parsePdf(book.filePath);
          break;
        case BookFormat.asset:
          final content = await rootBundle.loadString(book.filePath);
          parsed = _parser.parseTxtContent(content);
          break;
      }

      _chapters = parsed
          .map(
            (c) => Chapter(
              index: c.index,
              title: c.title,
              content: c.content,
              sentences: furiganaService.annotateChapter(c.sentences),
            ),
          )
          .toList();

      if (_chapters.isEmpty) {
        _error = '本文が見つかりませんでした';
      } else {
        _currentChapterIndex =
            book.lastChapterIndex.clamp(0, _chapters.length - 1);
        final sentences = currentChapter?.sentences ?? [];
        _currentSentenceIndex = sentences.isEmpty
            ? 0
            : book.lastPosition.clamp(0, sentences.length - 1);
      }
    } catch (e) {
      _error = _friendlyError(e);
      _chapters = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('end of central directory') ||
        text.contains('FormatException')) {
      return 'このEPUBを開けませんでした。ファイルが壊れているか、途中で切れています。';
    }
    return '読み込みに失敗しました: $e';
  }

  void goToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    _currentChapterIndex = index;
    _currentSentenceIndex = 0;
    notifyListeners();
  }

  void goToSentence(int index) {
    final chapter = currentChapter;
    if (chapter == null) return;
    if (index < 0 || index >= chapter.sentences.length) return;
    _currentSentenceIndex = index;
    notifyListeners();
  }

  bool nextSentence() {
    final chapter = currentChapter;
    if (chapter == null) return false;
    var next = _currentSentenceIndex + 1;
    while (next < chapter.sentences.length &&
        !chapter.sentences[next].isSpeakable) {
      next++;
    }
    if (next < chapter.sentences.length) {
      _currentSentenceIndex = next;
      notifyListeners();
      return true;
    }
    if (_currentChapterIndex < _chapters.length - 1) {
      _currentChapterIndex++;
      _currentSentenceIndex = _firstSpeakableIndex(currentChapter) ?? 0;
      notifyListeners();
      return currentSentence?.isSpeakable ?? false;
    }
    return false;
  }

  bool previousSentence() {
    var prev = _currentSentenceIndex - 1;
    final chapter = currentChapter;
    while (chapter != null &&
        prev >= 0 &&
        !chapter.sentences[prev].isSpeakable) {
      prev--;
    }
    if (prev >= 0) {
      _currentSentenceIndex = prev;
      notifyListeners();
      return true;
    }
    if (_currentChapterIndex > 0) {
      _currentChapterIndex--;
      final previous = currentChapter;
      _currentSentenceIndex = _lastSpeakableIndex(previous) ?? 0;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool nextPage() {
    final chapter = currentChapter;
    if (chapter == null) return false;
    if (_currentSentenceIndex < chapter.sentences.length - 1) {
      _currentSentenceIndex++;
      notifyListeners();
      return true;
    }
    if (_currentChapterIndex < _chapters.length - 1) {
      _currentChapterIndex++;
      _currentSentenceIndex = 0;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool previousPage() {
    if (_currentSentenceIndex > 0) {
      _currentSentenceIndex--;
      notifyListeners();
      return true;
    }
    if (_currentChapterIndex > 0) {
      _currentChapterIndex--;
      final chapter = currentChapter;
      _currentSentenceIndex =
          (chapter == null || chapter.sentences.isEmpty)
              ? 0
              : chapter.sentences.length - 1;
      notifyListeners();
      return true;
    }
    return false;
  }

  int? _firstSpeakableIndex(Chapter? chapter) {
    if (chapter == null) return null;
    for (var i = 0; i < chapter.sentences.length; i++) {
      if (chapter.sentences[i].isSpeakable) return i;
    }
    return null;
  }

  int? _lastSpeakableIndex(Chapter? chapter) {
    if (chapter == null) return null;
    for (var i = chapter.sentences.length - 1; i >= 0; i--) {
      if (chapter.sentences[i].isSpeakable) return i;
    }
    return null;
  }

  Sentence? get currentSentence {
    final chapter = currentChapter;
    if (chapter == null || chapter.sentences.isEmpty) return null;
    if (_currentSentenceIndex >= chapter.sentences.length) return null;
    return chapter.sentences[_currentSentenceIndex];
  }

  List<SearchHit> search(String query) {
    _query = query;
    notifyListeners();
    if (query.trim().isEmpty) return const [];
    final needle = query.trim();
    final hits = <SearchHit>[];
    for (final chapter in _chapters) {
      for (final sentence in chapter.sentences) {
        if (!sentence.isSpeakable) continue;
        if (sentence.text.contains(needle)) {
          hits.add(SearchHit(
            chapterIndex: chapter.index,
            sentenceIndex: sentence.index,
            preview: sentence.text,
            chapterTitle: chapter.title,
          ));
          if (hits.length >= 80) return hits;
        }
      }
    }
    return hits;
  }

  void jumpTo(int chapterIndex, int sentenceIndex) {
    goToChapter(chapterIndex);
    goToSentence(sentenceIndex);
  }

  void closeBook() {
    _currentBook = null;
    _chapters = [];
    _currentChapterIndex = 0;
    _currentSentenceIndex = 0;
    _error = null;
    _query = '';
    notifyListeners();
  }

  @override
  void dispose() {
    furiganaService.dispose();
    super.dispose();
  }
}

class SearchHit {
  final int chapterIndex;
  final int sentenceIndex;
  final String preview;
  final String chapterTitle;

  const SearchHit({
    required this.chapterIndex,
    required this.sentenceIndex,
    required this.preview,
    required this.chapterTitle,
  });
}
