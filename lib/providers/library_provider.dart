import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import '../services/book_parser.dart';
import '../services/library_store.dart';

class LibraryProvider extends ChangeNotifier {
  final LibraryStore _store;
  final BookParser _parser;
  final List<Book> _books = [];
  bool _isLoading = false;
  bool _initialized = false;
  String? _lastError;

  LibraryProvider({LibraryStore? store, BookParser? parser})
      : _store = store ?? LibraryStore(),
        _parser = parser ?? BookParser();

  List<Book> get books => List.unmodifiable(_books);
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  String? get lastError => _lastError;

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
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final format = detectFormat(file.extension ?? '');
    if (format == null) return null;

    final bytes = await _readPickedBytes(file);
    if (bytes == null || bytes.isEmpty) {
      _lastError = 'ファイルを読み込めませんでした';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final id = const Uuid().v4();
      final storedPath = await _persistBytes(id, file.extension ?? format.name, bytes);
      var title = extractTitle(file.name);
      String? author;
      Uint8List? cover;
      if (format == BookFormat.epub) {
        try {
          final parsed = _parser.parseEpubDocument(bytes);
          if (parsed.title.trim().isNotEmpty) title = parsed.title.trim();
          author = parsed.author;
          cover = parsed.cover;
        } catch (_) {}
      }
      final book = Book(
        id: id,
        title: title,
        author: author,
        filePath: storedPath,
        format: format,
        coverImage: cover,
      );
      _books.insert(0, book);
      await _store.saveBooks(_books);
      if (cover != null) await _store.saveCover(id, cover);
      notifyListeners();
      return book;
    } catch (e) {
      _lastError = '取り込みに失敗しました: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> _readPickedBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes;
    }
    final path = file.path;
    if (path == null) return null;
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<String> _persistBytes(String id, String extension, Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(dir.path, 'koe_reader', 'books'));
    await booksDir.create(recursive: true);
    final ext = extension.toLowerCase().replaceAll('.', '');
    final dest = File(p.join(booksDir.path, '$id.$ext'));
    await dest.writeAsBytes(bytes, flush: true);
    return dest.path;
  }

  Future<void> removeBook(String bookId) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index == -1) return;
    final book = _books.removeAt(index);
    if (!book.isSample) {
      try {
        final file = File(book.filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      await _store.deleteCover(bookId);
    }
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
    switch (extension.toLowerCase().replaceAll('.', '')) {
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
