import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import '../services/library_store.dart';

class LibraryProvider extends ChangeNotifier {
  final LibraryStore _store;
  final List<Book> _books = [];
  bool _isLoading = false;
  bool _initialized = false;

  LibraryProvider({LibraryStore? store}) : _store = store ?? LibraryStore();

  List<Book> get books => List.unmodifiable(_books);
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    _isLoading = true;
    notifyListeners();
    try {
      _books
        ..clear()
        ..addAll(await _store.loadBooks());
      if (_books.isEmpty) {
        _books.add(_sampleBook());
        await _store.saveBooks(_books);
      }
    } catch (_) {
      if (_books.isEmpty) _books.add(_sampleBook());
    } finally {
      _initialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Book _sampleBook() => Book(
        id: 'sample-sakura',
        title: '桜の午後（サンプル）',
        author: 'KoeReader',
        filePath: 'assets/books/sample.txt',
        format: BookFormat.asset,
        isSample: true,
      );

  Future<Book?> importBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'txt', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.path == null) return null;

    final format = detectFormat(file.extension ?? '');
    if (format == null) return null;

    _isLoading = true;
    notifyListeners();
    try {
      final book = Book(
        id: const Uuid().v4(),
        title: extractTitle(file.name),
        filePath: file.path!,
        format: format,
      );
      _books.insert(0, book);
      await _store.saveBooks(_books);
      notifyListeners();
      return book;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeBook(String bookId) async {
    _books.removeWhere((b) => b.id == bookId);
    await _store.saveBooks(_books);
    notifyListeners();
  }

  Future<void> updateProgress(
    String bookId,
    double progress,
    int chapterIndex,
    int position,
  ) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index == -1) return;
    _books[index].readingProgress = progress;
    _books[index].lastChapterIndex = chapterIndex;
    _books[index].lastPosition = position;
    await _store.saveBooks(_books);
    notifyListeners();
  }

  BookFormat? detectFormat(String extension) {
    switch (extension.toLowerCase()) {
      case 'epub':
        return BookFormat.epub;
      case 'pdf':
        return BookFormat.pdf;
      case 'txt':
        return BookFormat.txt;
      default:
        return null;
    }
  }

  String extractTitle(String fileName) {
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }
}
