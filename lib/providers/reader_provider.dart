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
      _error = '読み込みに失敗しました: $e';
      _chapters = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  bool previousSentence() {
    if (_currentSentenceIndex > 0) {
      _currentSentenceIndex--;
      notifyListeners();
      return true;
    }
    if (_currentChapterIndex > 0) {
      _currentChapterIndex--;
      final chapter = currentChapter;
      if (chapter != null && chapter.sentences.isNotEmpty) {
        _currentSentenceIndex = chapter.sentences.length - 1;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Sentence? get currentSentence {
    final chapter = currentChapter;
    if (chapter == null || chapter.sentences.isEmpty) return null;
    if (_currentSentenceIndex >= chapter.sentences.length) return null;
    return chapter.sentences[_currentSentenceIndex];
  }

  void closeBook() {
    _currentBook = null;
    _chapters = [];
    _currentChapterIndex = 0;
    _currentSentenceIndex = 0;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    furiganaService.dispose();
    super.dispose();
  }
}
