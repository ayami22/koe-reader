# KoeReader PRD

Japanese novel reader for learning: import EPUB/PDF/TXT, read with optional furigana, play TTS sentence-by-sentence with highlight, and pick a voice (preset or cloned).

## Product

- **Name:** KoeReader (声リーダー)
- **Platforms:** Windows first (this machine), then Android. Flutter.
- **Repo:** https://github.com/ayami22/koe-reader
- **Local:** D:\KoeReader\koe_reader

## User stories

1. Import a Japanese EPUB or TXT and see chapters + sentences.
2. Toggle furigana over kanji when the book has none.
3. Tap play: TTS reads the current sentence, highlight follows, auto-advances.
4. Change speed, pause, skip sentence/chapter.
5. Pick a voice; optionally clone from a short WAV.
6. Progress, theme, font size persist.

## Architecture

```
Flutter app  --HTTP-->  tts_server (FastAPI)
                         ├─ CosyVoice if available
                         └─ edge-tts fallback (always works, no GPU)
```

TTS is the Python service at `D:\KoeReader\koe_reader\tts_server`. Default URL `http://127.0.0.1:50000`.

Furigana: bundled JmdictFurigana JSON + longest-match lookup. No MeCab on Windows for v1.

PDF: extract text via `syncfusion_flutter_pdf` or similar Dart-only extractor. If too heavy, skip PDF in v1 and keep EPUB/TXT.

## Non-goals (v1)

- Legado / web novel scrapers
- Cloud accounts / DRM
- iOS signing
- Training TTS models in-app

## Success (v1 done)

- `flutter analyze` clean
- `flutter test` all pass
- Windows: import TXT, read, highlight, TTS via local server
- Furigana toggle works on kanji text
- Voice list + clone endpoint exist
- README documents run steps
