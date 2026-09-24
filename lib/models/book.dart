import 'dart:typed_data';

enum BookFormat { epub, pdf, txt }

class Book {
  final String id;
  final String title;
  final String? author;
  final String filePath;
  final BookFormat format;
  final Uint8List? coverImage;
  final DateTime addedAt;
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
        'coverImage': coverImage,
        'addedAt': addedAt.toIso8601String(),
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
        coverImage: map['coverImage'] as Uint8List?,
        addedAt: DateTime.parse(map['addedAt'] as String),
        readingProgress: (map['readingProgress'] as num).toDouble(),
        lastChapterIndex: map['lastChapterIndex'] as int? ?? 0,
        lastPosition: map['lastPosition'] as int? ?? 0,
      );
}
