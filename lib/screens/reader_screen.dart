import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../providers/reader_provider.dart';
import '../providers/tts_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/sentence_view.dart';
import '../widgets/tts_controls.dart';
import '../widgets/chapter_drawer.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;
  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showControls = true;
  bool _autoPlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReaderProvider>().openBook(widget.book);
      _connectTts();
    });
  }

  Future<void> _connectTts() async {
    final settings = context.read<SettingsProvider>();
    final tts = context.read<TtsProvider>();
    await tts.connect(settings.cosyVoiceUrl);
    tts.setOnSentenceFinished(_onSentenceFinished);
  }

  void _onSentenceFinished() {
    if (!_autoPlay) return;
    final reader = context.read<ReaderProvider>();
    final tts = context.read<TtsProvider>();
    final chapter = reader.currentChapter;
    if (chapter == null) return;

    final nextIndex = reader.currentSentenceIndex + 1;
    if (nextIndex < chapter.sentences.length) {
      reader.nextSentence();
      tts.speakSentence(chapter.sentences[nextIndex], nextIndex);
      _scrollToSentence(nextIndex);
    } else if (reader.currentChapterIndex < reader.chapters.length - 1) {
      reader.goToChapter(reader.currentChapterIndex + 1);
      final newChapter = reader.currentChapter;
      if (newChapter != null && newChapter.sentences.isNotEmpty) {
        tts.speakSentence(newChapter.sentences[0], 0);
        _scrollToSentence(0);
      }
    } else {
      _autoPlay = false;
      setState(() {});
    }
  }

  void _scrollToSentence(int index) {
    final itemHeight = 60.0;
    final targetOffset = index * itemHeight;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleAutoPlay() {
    final reader = context.read<ReaderProvider>();
    final tts = context.read<TtsProvider>();
    final chapter = reader.currentChapter;
    if (chapter == null || chapter.sentences.isEmpty) return;

    setState(() {
      _autoPlay = !_autoPlay;
    });

    if (_autoPlay) {
      final index = reader.currentSentenceIndex;
      tts.speakSentence(chapter.sentences[index], index);
    } else {
      tts.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderProvider>();
    final tts = context.watch<TtsProvider>();
    final settings = context.watch<SettingsProvider>();
    final chapter = reader.currentChapter;

    return Scaffold(
      endDrawer: const ChapterDrawer(),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: SafeArea(
          child: Stack(
            children: [
              if (reader.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (chapter == null)
                const Center(child: Text('本を読み込めませんでした'))
              else
                Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        itemCount: chapter.sentences.length,
                        itemBuilder: (context, index) {
                          final sentence = chapter.sentences[index];
                          final isActive = tts.playingSentenceIndex == index;
                          return SentenceView(
                            sentence: sentence,
                            isActive: isActive,
                            showFurigana: settings.showFurigana,
                            fontSize: settings.fontSize,
                            lineHeight: settings.lineHeight,
                            onTap: () {
                              reader.goToSentence(index);
                              tts.speakSentence(sentence, index);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              if (_showControls) ...[
                _buildTopBar(context, reader, chapter),
                _buildBottomBar(context, tts),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ReaderProvider reader, Chapter? chapter) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withAlpha(0),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                chapter?.title ?? widget.book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, TtsProvider tts) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: TtsControls(
        isPlaying: _autoPlay,
        isConnected: tts.isConnected,
        isSynthesizing: tts.isSynthesizing,
        onPlayPause: _toggleAutoPlay,
        onPrevious: () {
          context.read<ReaderProvider>().previousSentence();
        },
        onNext: () {
          context.read<ReaderProvider>().nextSentence();
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
