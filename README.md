# KoeReader (声リーダー)

A cross-platform Japanese novel reader with real-time TTS, furigana annotation, and custom voice support.

## Features

- **Multi-format support**: EPUB, PDF, TXT
- **Real-time TTS**: Powered by CosyVoice with streaming synthesis (~150ms latency)
- **Custom voice cloning**: Upload a short audio sample to create your own character voice
- **Furigana annotation**: Automatic reading aids for kanji using MeCab + JmdictFurigana
- **Sentence-level highlighting**: Follow along as text is read aloud
- **Cross-platform**: Android, iOS, Windows, macOS, Linux, Web

## Architecture

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models (Book, Chapter, VoiceProfile)
├── services/                 # Business logic
│   ├── book_parser.dart      # EPUB/TXT parsing
│   ├── cosyvoice_service.dart # CosyVoice TTS API client
│   └── furigana_service.dart # Furigana annotation engine
├── providers/                # State management (Provider)
│   ├── library_provider.dart
│   ├── reader_provider.dart
│   ├── tts_provider.dart
│   └── settings_provider.dart
├── screens/                  # Page-level UI
│   ├── home_screen.dart
│   ├── reader_screen.dart
│   └── settings_screen.dart
└── widgets/                  # Reusable UI components
    ├── sentence_view.dart
    ├── tts_controls.dart
    └── chapter_drawer.dart
```

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.24.0
- [CosyVoice](https://github.com/FunAudioLLM/CosyVoice) server running locally or remotely

## Getting Started

### 1. Install Flutter

```bash
# Windows (via Scoop)
scoop install flutter

# macOS (via Homebrew)
brew install flutter

# Or download from https://docs.flutter.dev/get-started/install
```

### 2. Clone and setup

```bash
git clone https://github.com/<your-username>/koe-reader.git
cd koe-reader
flutter pub get
```

### 3. Start CosyVoice server

```bash
# Clone CosyVoice
git clone https://github.com/FunAudioLLM/CosyVoice.git
cd CosyVoice

# Install and run (see CosyVoice docs for details)
pip install -r requirements.txt
python webui.py
```

### 4. Run the app

```bash
# Android
flutter run

# Windows desktop
flutter run -d windows

# Web
flutter run -d chrome
```

## Configuration

Open the settings screen to configure:

- **CosyVoice server URL**: Default `http://localhost:50000`
- **TTS speed**: 0.5x - 2.0x
- **Furigana display**: Toggle on/off
- **Font size and line height**
- **Theme**: Light / Dark / System

## Tech Stack

| Component | Technology |
|---|---|
| Framework | Flutter / Dart |
| State management | Provider |
| TTS engine | CosyVoice (streaming API) |
| EPUB parsing | epubx |
| PDF rendering | pdfrx |
| Audio playback | just_audio |
| Japanese processing | MeCab + JmdictFurigana |
| Local storage | shared_preferences, sqflite |

## Roadmap

- [ ] PDF rendering with sentence extraction
- [ ] MeCab integration for accurate sentence-level furigana
- [ ] Voice profile management UI
- [ ] VOICEVOX engine support (alternative TTS)
- [ ] Bookmarks and reading history
- [ ] Word lookup / dictionary integration
- [ ] Export highlights and vocabulary list
- [ ] Cloud sync for reading progress

## License

MIT License - see [LICENSE](LICENSE) for details.
