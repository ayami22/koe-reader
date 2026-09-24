# KoeReader

Flutter Japanese reader. TTS: FastAPI at tts_server/. Repo: ayami22/koe-reader.

## Autonomous

- Never ask questions. Conventional + simpler wins.
- After 3 failed attempts: log in docs/blocked.md, next task.
- After each TODO item: tests if applicable, commit, push main.
- Before compacting: write docs/mission.md (done / next / blocked).
- Do not rm -rf, force-push, or reset --hard.

## Commands

```
set PATH=D:\flutter_sdk\flutter\bin;%PATH%
cd D:\KoeReader\koe_reader
flutter analyze
flutter test
```

TTS: `cd D:\KoeReader\koe_reader\tts_server && python -m uvicorn app:app --host 127.0.0.1 --port 50000`

## Decisions

- TTS: CosyVoice if importable, else edge-tts (ja-JP Neural).
- Furigana: bundled JSON longest-match, not MeCab.
- Persistence: JSON library store in app documents, shared_preferences for settings.
- Sample book in assets so the app is demoable without a file picker.
