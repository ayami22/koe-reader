import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../models/voice_profile.dart';

class LibraryStore {
  File? _file;

  Future<File> _dbFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'koe_reader', 'library.json'));
    await file.parent.create(recursive: true);
    if (!await file.exists()) {
      await file.writeAsString(jsonEncode({'books': [], 'voices': []}));
    }
    _file = file;
    return file;
  }

  Future<Map<String, dynamic>> _read() async {
    final file = await _dbFile();
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {'books': [], 'voices': []};
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final file = await _dbFile();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<File> _coverFile(String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'koe_reader', 'covers', '$bookId.img'));
    await file.parent.create(recursive: true);
    return file;
  }

  Future<void> saveCover(String bookId, Uint8List bytes) async {
    final file = await _coverFile(bookId);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<Uint8List?> loadCover(String bookId) async {
    try {
      final file = await _coverFile(bookId);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteCover(String bookId) async {
    try {
      final file = await _coverFile(bookId);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<List<Book>> loadBooks() async {
    final data = await _read();
    final list = data['books'] as List<dynamic>? ?? [];
    final books = list
        .map((e) => Book.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    for (var i = 0; i < books.length; i++) {
      final cover = await loadCover(books[i].id);
      if (cover == null) continue;
      books[i] = Book(
        id: books[i].id,
        title: books[i].title,
        author: books[i].author,
        filePath: books[i].filePath,
        format: books[i].format,
        coverImage: cover,
        addedAt: books[i].addedAt,
        isSample: books[i].isSample,
        readingProgress: books[i].readingProgress,
        lastChapterIndex: books[i].lastChapterIndex,
        lastPosition: books[i].lastPosition,
      );
    }
    return books;
  }

  Future<void> saveBooks(List<Book> books) async {
    final data = await _read();
    data['books'] = books.map((b) => b.toMap()).toList();
    await _write(data);
  }

  Future<List<VoiceProfile>> loadVoices() async {
    final data = await _read();
    final list = data['voices'] as List<dynamic>? ?? [];
    return list
        .map((e) => VoiceProfile.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveVoices(List<VoiceProfile> voices) async {
    final data = await _read();
    data['voices'] = voices.map((v) => v.toMap()).toList();
    await _write(data);
  }
}
