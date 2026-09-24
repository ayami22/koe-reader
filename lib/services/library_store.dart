import 'dart:convert';
import 'dart:io';
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

  Future<List<Book>> loadBooks() async {
    final data = await _read();
    final list = data['books'] as List<dynamic>? ?? [];
    return list
        .map((e) => Book.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
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
