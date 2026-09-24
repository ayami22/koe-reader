# KoeReader (声リーダー)

Flutter Japanese novel reader: EPUB / TXT / PDF, furigana, sentence highlight, and real-time TTS.

Repository: https://github.com/ayami22/koe-reader

## Run

### 1. TTS server

```powershell
cd D:\KoeReader\koe_reader\tts_server
python -m pip install -r requirements.txt
python -m uvicorn app:app --host 127.0.0.1 --port 50000
```

Default engine is Edge neural Japanese voices (Nanami, Keita, …). If the `cosyvoice` package is installed, the health endpoint reports `engine: cosyvoice`. Custom WAV uploads are stored under `tts_server/clones/`.

### 2. App

Flutter SDK on this machine: `D:\flutter_sdk\flutter\bin` (add it to PATH).

```powershell
cd D:\KoeReader\koe_reader
flutter pub get
flutter run -d windows
```

First launch includes the sample book **桜の午後**. Import EPUB / TXT / PDF from the FAB. Open **設定** to connect TTS (`http://127.0.0.1:50000`) and toggle furigana.

## Layout

```
lib/
  models/      Book, Chapter, VoiceProfile
  services/    parser, furigana, TTS client, JSON library store
  providers/   library, reader, tts, settings
  screens/     home, reader, settings, voices
  widgets/     sentence highlight, playback bar, TOC
assets/
  books/sample.txt
  dict/furigana.json
tts_server/    FastAPI + edge-tts
```

## Android APK

GitHub Actions builds a release APK on every push to `main` (and on **Actions → CI → Run workflow**).

1. Open https://github.com/ayami22/koe-reader/actions
2. Open the latest **CI** run
3. Download artifact **koe-reader-apk** (`app-release.apk`)
4. Install on the phone (allow unknown sources)

TTS on a phone is not `127.0.0.1`. On the PC:

```powershell
cd D:\KoeReader\koe_reader\tts_server
python -m uvicorn app:app --host 0.0.0.0 --port 50000
```

Then in the app **設定**, set the URL to `http://<PC-LAN-IP>:50000`.

## Tests

```powershell
flutter analyze
flutter test
```

## License

MIT
