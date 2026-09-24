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

  Sentence({
    required this.index,
    required this.text,
    required this.startOffset,
    required this.endOffset,
    List<FuriganaSegment>? furiganaSegments,
  }) : furiganaSegments = furiganaSegments ?? [];
}

class FuriganaSegment {
  final String text;
  final String? furigana;

  const FuriganaSegment({required this.text, this.furigana});

  bool get hasFurigana => furigana != null && furigana!.isNotEmpty;
}
