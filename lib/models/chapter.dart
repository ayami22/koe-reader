import 'dart:typed_data';

class Chapter {
  final int index;
  final String title;
  final String content;
  final List<Sentence> sentences;

  Chapter({
    required this.index,
    required this.title,
    required this.content,
    List<Sentence>? sentences,
  }) : sentences = sentences ?? [];
}

class Sentence {
  final int index;
  final String text;
  final int startOffset;
  final int endOffset;
  final List<FuriganaSegment> furiganaSegments;
  final Uint8List? imageBytes;

  Sentence({
    required this.index,
    required this.text,
    required this.startOffset,
    required this.endOffset,
    List<FuriganaSegment>? furiganaSegments,
    this.imageBytes,
  }) : furiganaSegments = furiganaSegments ?? [];

  bool get isIllustration => imageBytes != null && imageBytes!.isNotEmpty;
  bool get isSpeakable => !isIllustration && text.trim().isNotEmpty;
}

class FuriganaSegment {
  final String text;
  final String? furigana;

  const FuriganaSegment({required this.text, this.furigana});

  bool get hasFurigana => furigana != null && furigana!.isNotEmpty;
}
