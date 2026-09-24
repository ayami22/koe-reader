import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/book_parser.dart';
import '../services/furigana_service.dart';

class ReaderProvider extends ChangeNotifier {
  final BookParser _parser = BookParser();
  final FuriganaService _furiganaService = FuriganaService();

  Book? _currentBook;
  List<Chapter> _chapters = [];
  int _currentChapterIndex = 0;
  int _currentSentenceIndex = 0;
  bool _isLoading = false;

  Book? get currentBook => _currentBook;
  List<Chapter> get chapters => _chapters;
  int get currentChapterIndex => _currentChapterIndex;
  int get currentSentenceIndex => _currentSentenceIndex;
  Chapter? get currentChapter =>
      _chapters.isNotEmpty ? _chapters[_currentChapterIndex] : null;
  bool get isLoading => _isLoading;
  FuriganaService get furiganaService => _furiganaService;

  Future<void> openBook(Book book) async {
    _isLoading = true;
    _currentBook = book;
    notifyListeners();

    try {
      switch (book.format) {
        case BookFormat.epub:
          _chapters = await _parser.parseEpub(book.filePath);
          break;
        case BookFormat.txt:
          _chapters = await _parser.parseTxt(book.filePath);
          break;
        case BookFormat.pdf:
          // PDF support will be added with pdfrx integration
          _chapters = [];
          break;
      }

      _currentChapterIndex = book.lastChapterIndex.clamp(0, _chapters.length - 1);
      _currentSentenceIndex = 0;
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

  void nextSentence() {
    final chapter = currentChapter;
    if (chapter == null) return;

    if (_currentSentenceIndex < chapter.sentences.length - 1) {
      _currentSentenceIndex++;
      notifyListeners();
    } else if (_currentChapterIndex < _chapters.length - 1) {
      _currentChapterIndex++;
      _currentSentenceIndex = 0;
      notifyListeners();
    }
  }

  void previousSentence() {
    if (_currentSentenceIndex > 0) {
      _currentSentenceIndex--;
      notifyListeners();
    } else if (_currentChapterIndex > 0) {
      _currentChapterIndex--;
      final chapter = currentChapter;
      if (chapter != null && chapter.sentences.isNotEmpty) {
        _currentSentenceIndex = chapter.sentences.length - 1;
      }
      notifyListeners();
    }
  }

  void closeBook() {
    _currentBook = null;
    _chapters = [];
    _currentChapterIndex = 0;
    _currentSentenceIndex = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _furiganaService.dispose();
    super.dispose();
  }
}
