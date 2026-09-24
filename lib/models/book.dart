import 'dart:typed_data';

enum BookFormat { epub, pdf, txt, asset }

class Book {
  final String id;
  final String title;
  final String? author;
  final String filePath;
  final BookFormat format;
  final Uint8List? coverImage;
  final DateTime addedAt;
  final bool isSample;
  double readingProgress;
  int lastChapterIndex;
  int lastPosition;

  Book({
    required this.id,
    required this.title,
    this.author,
    required this.filePath,
    required this.format,
    this.coverImage,
    DateTime? addedAt,
    this.isSample = false,
    this.readingProgress = 0.0,
    this.lastChapterIndex = 0,
    this.lastPosition = 0,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'filePath': filePath,
        'format': format.name,
        'addedAt': addedAt.toIso8601String(),
        'isSample': isSample,
        'readingProgress': readingProgress,
        'lastChapterIndex': lastChapterIndex,
        'lastPosition': lastPosition,
      };

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'] as String,
        title: map['title'] as String,
        author: map['author'] as String?,
        filePath: map['filePath'] as String,
        format: BookFormat.values.byName(map['format'] as String),
        addedAt: DateTime.parse(map['addedAt'] as String),
        isSample: map['isSample'] as bool? ?? false,
        readingProgress: (map['readingProgress'] as num?)?.toDouble() ?? 0.0,
        lastChapterIndex: map['lastChapterIndex'] as int? ?? 0,
        lastPosition: map['lastPosition'] as int? ?? 0,
      );
}
