import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';

class LibraryProvider extends ChangeNotifier {
  final List<Book> _books = [];
  bool _isLoading = false;

  List<Book> get books => List.unmodifiable(_books);
  bool get isLoading => _isLoading;

  Future<Book?> importBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'txt', 'pdf'],
    );

    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.path == null) return null;

    _isLoading = true;
    notifyListeners();

    try {
      final format = _detectFormat(file.extension ?? '');
      if (format == null) return null;

      final book = Book(
        id: const Uuid().v4(),
        title: _extractTitle(file.name),
        filePath: file.path!,
        format: format,
      );

      _books.insert(0, book);
      notifyListeners();
      return book;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void removeBook(String bookId) {
    _books.removeWhere((b) => b.id == bookId);
    notifyListeners();
  }

  void updateProgress(String bookId, double progress, int chapterIndex, int position) {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index == -1) return;
    _books[index].readingProgress = progress;
    _books[index].lastChapterIndex = chapterIndex;
    _books[index].lastPosition = position;
    notifyListeners();
  }

  BookFormat? _detectFormat(String extension) {
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

  String _extractTitle(String fileName) {
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }
}
