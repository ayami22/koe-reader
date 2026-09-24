# TTS server

KoeReader speech backend. Default engine is Microsoft Edge neural TTS (Japanese). CosyVoice is used if that package is importable.

```bash
cd D:\KoeReader\koe_reader\tts_server
python -m pip install -r requirements.txt
python -m uvicorn app:app --host 127.0.0.1 --port 50000
```

Endpoints:

- `GET /api/health`
- `GET /api/speakers`
- `POST /api/tts` JSON `{text, speaker_id, speed}` → audio/mpeg
- `POST /api/clone` multipart `name` + `file`

Clone voices are stored under `clones/` and listed in `/api/speakers`. Synthesis still uses Nanami as the speaking voice until CosyVoice is installed; the clone id is kept so the app can switch later.
