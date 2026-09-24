import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../providers/library_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final reader = context.read<ReaderProvider>();
      final settings = context.read<SettingsProvider>();
      final tts = context.read<TtsProvider>();
      tts.updateVoiceSettings(
        speakerId: settings.activeVoiceId,
        speed: settings.ttsSpeed,
      );
      await reader.openBook(widget.book);
      await tts.connect(settings.cosyVoiceUrl);
      tts.setOnSentenceFinished(_onSentenceFinished);
    });
  }

  void _persistProgress() {
    final reader = context.read<ReaderProvider>();
    context.read<LibraryProvider>().updateProgress(
          widget.book.id,
          reader.progress,
          reader.currentChapterIndex,
          reader.currentSentenceIndex,
        );
  }

  void _onSentenceFinished() {
    if (!_autoPlay || !mounted) return;
    final reader = context.read<ReaderProvider>();
    final tts = context.read<TtsProvider>();
    final moved = reader.nextSentence();
    _persistProgress();
    if (!moved) {
      setState(() => _autoPlay = false);
      return;
    }
    final sentence = reader.currentSentence;
    if (sentence == null) {
      setState(() => _autoPlay = false);
      return;
    }
    tts.speakSentence(sentence, reader.currentSentenceIndex);
    _scrollToSentence(reader.currentSentenceIndex);
    final chapter = reader.currentChapter;
    if (chapter != null &&
        reader.currentSentenceIndex + 1 < chapter.sentences.length) {
      tts.prefetch(chapter.sentences[reader.currentSentenceIndex + 1].text);
    }
  }

  void _scrollToSentence(int index) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      (index * 72.0).clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _toggleAutoPlay() async {
    final reader = context.read<ReaderProvider>();
    final tts = context.read<TtsProvider>();
    final sentence = reader.currentSentence;
    if (sentence == null) return;

    if (_autoPlay) {
      setState(() => _autoPlay = false);
      await tts.stop();
      return;
    }

    setState(() => _autoPlay = true);
    await tts.speakSentence(sentence, reader.currentSentenceIndex);
  }

  void _skip(int delta) {
    final reader = context.read<ReaderProvider>();
    final tts = context.read<TtsProvider>();
    final moved = delta < 0 ? reader.previousSentence() : reader.nextSentence();
    _persistProgress();
    if (!moved || !_autoPlay) return;
    final sentence = reader.currentSentence;
    if (sentence == null) return;
    tts.speakSentence(sentence, reader.currentSentenceIndex);
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
              else if (reader.error != null)
                Center(child: Text(reader.error!))
              else if (chapter == null)
                const Center(child: Text('本を読み込めませんでした'))
              else
                Column(
                  children: [
                    LinearProgressIndicator(value: reader.progress),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 56, 24, 96),
                        itemCount: chapter.sentences.length,
                        itemBuilder: (context, index) {
                          final sentence = chapter.sentences[index];
                          final isActive =
                              tts.playingSentenceIndex == index ||
                                  reader.currentSentenceIndex == index;
                          return SentenceView(
                            sentence: sentence,
                            isActive: isActive,
                            showFurigana: settings.showFurigana,
                            fontSize: settings.fontSize,
                            lineHeight: settings.lineHeight,
                            onTap: () {
                              reader.goToSentence(index);
                              _persistProgress();
                              tts.speakSentence(sentence, index);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              if (_showControls) ...[
                _buildTopBar(context, chapter),
                _buildBottomBar(context, tts),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Chapter? chapter) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Theme.of(context).colorScheme.surface.withAlpha(230),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _persistProgress();
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Text(
                chapter?.title ?? widget.book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.list),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
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
        error: tts.lastError,
        onPlayPause: _toggleAutoPlay,
        onPrevious: () => _skip(-1),
        onNext: () => _skip(1),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
