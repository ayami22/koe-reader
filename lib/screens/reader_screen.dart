import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../providers/library_provider.dart';
import '../providers/reader_provider.dart';
import '../providers/tts_provider.dart';
import '../providers/settings_provider.dart';
import '../services/page_paginator.dart';
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
  PageController? _pageController;
  bool _showControls = true;
  bool _autoPlay = false;
  int _boundChapter = -1;
  int _pageCount = 0;
  List<ReaderPage> _pages = const [];
  Size? _pageSize;

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
      await _applyKeepAwake(settings.keepScreenOn);
      await reader.openBook(widget.book);
      await tts.connect(settings.cosyVoiceUrl);
      tts.setOnSentenceFinished(_onSentenceFinished);
      if (mounted) setState(() {});
    });
  }

  Future<void> _applyKeepAwake(bool on) async {
    try {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  void _rebuildPages(ReaderProvider reader, SettingsProvider settings) {
    final chapter = reader.currentChapter;
    final size = _pageSize;
    if (chapter == null || size == null) {
      _pages = const [];
      return;
    }
    _pages = PagePaginator.paginate(
      sentences: chapter.sentences,
      size: size,
      fontSize: settings.fontSize,
      lineHeight: settings.lineHeight,
      showFurigana: settings.showFurigana,
    );
    final pageIndex = PagePaginator.pageIndexForSentence(
      _pages,
      reader.currentSentenceIndex,
    );
    if (_pageController == null ||
        _boundChapter != reader.currentChapterIndex ||
        _pageCount != _pages.length) {
      final old = _pageController;
      _pageController = PageController(initialPage: pageIndex);
      _boundChapter = reader.currentChapterIndex;
      _pageCount = _pages.length;
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    } else if (_pageController!.hasClients) {
      final current = _pageController!.page?.round() ?? 0;
      if (current != pageIndex) {
        _pageController!.jumpToPage(pageIndex);
      }
    }
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
    _jumpToCurrentSentence(reader);
    final sentence = reader.currentSentence;
    if (sentence == null || !sentence.isSpeakable) {
      setState(() => _autoPlay = false);
      return;
    }
    tts.speakSentence(sentence, reader.currentSentenceIndex);
    final chapter = reader.currentChapter;
    if (chapter != null) {
      for (var i = reader.currentSentenceIndex + 1;
          i < chapter.sentences.length;
          i++) {
        if (chapter.sentences[i].isSpeakable) {
          tts.prefetch(chapter.sentences[i].text);
          break;
        }
      }
    }
  }

  void _jumpToCurrentSentence(ReaderProvider reader) {
    if (_pages.isEmpty || _pageController == null) return;
    final pageIndex = PagePaginator.pageIndexForSentence(
      _pages,
      reader.currentSentenceIndex,
    );
    if (_pageController!.hasClients) {
      final current = _pageController!.page?.round() ?? 0;
      if (current != pageIndex) {
        _pageController!.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _toggleAutoPlay() async {
    final reader = context.read<ReaderProvider>();
    final tts = context.read<TtsProvider>();
    var sentence = reader.currentSentence;
    if (sentence != null && !sentence.isSpeakable) {
      reader.nextSentence();
      sentence = reader.currentSentence;
      _jumpToCurrentSentence(reader);
    }
    if (sentence == null || !sentence.isSpeakable) return;

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
    _jumpToCurrentSentence(reader);
    if (!moved || !_autoPlay) return;
    final sentence = reader.currentSentence;
    if (sentence == null || !sentence.isSpeakable) return;
    tts.speakSentence(sentence, reader.currentSentenceIndex);
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _pages.length) return;
    final reader = context.read<ReaderProvider>();
    final start = _pages[index].startIndex;
    if (reader.currentSentenceIndex < _pages[index].startIndex ||
        reader.currentSentenceIndex >= _pages[index].endIndex) {
      reader.goToSentence(start);
      _persistProgress();
    }
  }

  Future<void> _openSearch() async {
    final reader = context.read<ReaderProvider>();
    final queryController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var hits = <SearchHit>[];
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: queryController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: '本文を検索',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setSheet(() => hits = reader.search(value));
                        },
                      ),
                    ),
                    Expanded(
                      child: hits.isEmpty
                          ? const Center(child: Text('該当なし'))
                          : ListView.builder(
                              itemCount: hits.length,
                              itemBuilder: (_, i) {
                                final hit = hits[i];
                                return ListTile(
                                  title: Text(
                                    hit.preview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(hit.chapterTitle),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    reader.jumpTo(
                                      hit.chapterIndex,
                                      hit.sentenceIndex,
                                    );
                                    _persistProgress();
                                    setState(() {});
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      _jumpToCurrentSentence(reader);
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    queryController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<ReaderProvider>();
    final tts = context.watch<TtsProvider>();
    final settings = context.watch<SettingsProvider>();
    final chapter = reader.currentChapter;

    return Scaffold(
      endDrawer: ChapterDrawer(
        onChapterSelected: () {
          _persistProgress();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        },
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: SafeArea(
          child: Stack(
            children: [
              ColorFiltered(
                colorFilter: ColorFilter.matrix(_dimMatrix(settings.brightness)),
                child: _buildBody(reader, tts, settings, chapter),
              ),
              if (_showControls) ...[
                _buildTopBar(context, chapter, reader),
                _buildBottomBar(context, tts, settings),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    ReaderProvider reader,
    TtsProvider tts,
    SettingsProvider settings,
    Chapter? chapter,
  ) {
    if (reader.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (reader.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(reader.error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (chapter == null || chapter.sentences.isEmpty) {
      return const Center(child: Text('本を読み込めませんでした'));
    }
    return Column(
      children: [
        LinearProgressIndicator(value: reader.progress),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final nextSize = Size(
                constraints.maxWidth - 48,
                constraints.maxHeight - 8,
              );
              final sizeChanged = _pageSize == null ||
                  (_pageSize!.width - nextSize.width).abs() > 1 ||
                  (_pageSize!.height - nextSize.height).abs() > 1;
              if (sizeChanged) {
                _pageSize = nextSize;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() {});
                });
              }
              _rebuildPages(reader, settings);
              if (_pages.isEmpty || _pageController == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, pageIndex) {
                  final page = _pages[pageIndex];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 8),
                    child: ListView(
                      children: page.sentences.map((sentence) {
                        final globalIndex = sentence.index;
                        final isActive =
                            tts.playingSentenceIndex == globalIndex ||
                                reader.currentSentenceIndex == globalIndex;
                        return SentenceView(
                          sentence: sentence,
                          isActive: isActive,
                          showFurigana: settings.showFurigana,
                          fontSize: settings.fontSize,
                          lineHeight: settings.lineHeight,
                          onTap: () {
                            reader.goToSentence(globalIndex);
                            _persistProgress();
                            if (sentence.isSpeakable) {
                              tts.speakSentence(sentence, globalIndex);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    Chapter? chapter,
    ReaderProvider reader,
  ) {
    final pageIndex = PagePaginator.pageIndexForSentence(
      _pages,
      reader.currentSentenceIndex,
    );
    final pageLabel = _pages.isEmpty
        ? reader.progressLabel
        : '${pageIndex + 1}/${_pages.length}  ·  ${reader.progressLabel}';
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Theme.of(context).colorScheme.surface.withAlpha(230),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter?.title ?? widget.book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (pageLabel.isNotEmpty)
                    Text(
                      pageLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _openSearch,
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

  Widget _buildBottomBar(
    BuildContext context,
    TtsProvider tts,
    SettingsProvider settings,
  ) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.brightness_6, size: 18),
                Expanded(
                  child: Slider(
                    value: settings.brightness,
                    min: 0.35,
                    max: 1.0,
                    onChanged: settings.setBrightness,
                  ),
                ),
              ],
            ),
          ),
          TtsControls(
            isPlaying: _autoPlay,
            isConnected: tts.isConnected,
            isSynthesizing: tts.isSynthesizing,
            error: tts.lastError,
            onPlayPause: _toggleAutoPlay,
            onPrevious: () => _skip(-1),
            onNext: () => _skip(1),
          ),
        ],
      ),
    );
  }

  List<double> _dimMatrix(double brightness) {
    final b = brightness.clamp(0.35, 1.0);
    return <double>[
      b, 0, 0, 0, 0,
      0, b, 0, 0, 0,
      0, 0, b, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  void dispose() {
    _pageController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}
