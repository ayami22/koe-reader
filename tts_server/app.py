from __future__ import annotations

import io
import os
import uuid
from pathlib import Path
from typing import Any

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field

ROOT = Path(__file__).resolve().parent
CLONES = ROOT / "clones"
CLONES.mkdir(exist_ok=True)

app = FastAPI(title="KoeReader TTS", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

ENGINE = "edge"
try:
    import cosyvoice  # type: ignore  # noqa: F401

    ENGINE = "cosyvoice"
except Exception:
    ENGINE = "edge"

DEFAULT_SPEAKERS = [
    {"id": "ja-JP-NanamiNeural", "name": "Nanami", "engine": "edge", "locale": "ja-JP"},
    {"id": "ja-JP-KeitaNeural", "name": "Keita", "engine": "edge", "locale": "ja-JP"},
    {"id": "ja-JP-AoiNeural", "name": "Aoi", "engine": "edge", "locale": "ja-JP"},
    {"id": "ja-JP-DaichiNeural", "name": "Daichi", "engine": "edge", "locale": "ja-JP"},
    {"id": "ja-JP-MayuNeural", "name": "Mayu", "engine": "edge", "locale": "ja-JP"},
    {"id": "ja-JP-NaokiNeural", "name": "Naoki", "engine": "edge", "locale": "ja-JP"},
    {"id": "ja-JP-ShioriNeural", "name": "Shiori", "engine": "edge", "locale": "ja-JP"},
]


class TtsRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000)
    speaker_id: str = "ja-JP-NanamiNeural"
    speed: float = 1.0
    reference_audio: str | None = None


def _clone_speakers() -> list[dict[str, Any]]:
    speakers: list[dict[str, Any]] = []
    files = sorted(set(CLONES.glob("*.wav")) | set(CLONES.glob("*.mp3")))
    for path in files:
        speakers.append(
            {
                "id": f"clone:{path.stem}",
                "name": path.stem,
                "engine": ENGINE,
                "locale": "ja-JP",
            }
        )
    return speakers


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok", "engine": ENGINE}


@app.get("/api/speakers")
def speakers() -> dict[str, Any]:
    return {"speakers": DEFAULT_SPEAKERS + _clone_speakers(), "engine": ENGINE}


async def _edge_tts(text: str, speaker_id: str, speed: float) -> bytes:
    try:
        import edge_tts
    except ImportError as exc:
        raise HTTPException(status_code=500, detail="edge-tts is not installed") from exc

    rate = f"{int((speed - 1.0) * 100):+d}%"
    communicate = edge_tts.Communicate(text, speaker_id, rate=rate)
    buf = io.BytesIO()
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            buf.write(chunk["data"])
    data = buf.getvalue()
    if not data:
        raise HTTPException(status_code=502, detail="empty audio from edge-tts")
    return data


@app.post("/api/tts")
async def tts(req: TtsRequest) -> Response:
    text = req.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="empty text")

    speaker = req.speaker_id
    if speaker.startswith("clone:"):
        speaker = "ja-JP-NanamiNeural"

    audio = await _edge_tts(text, speaker, req.speed)
    return Response(content=audio, media_type="audio/mpeg")


@app.post("/api/tts/stream")
async def tts_stream(req: TtsRequest) -> Response:
    return await tts(req)


@app.post("/api/clone")
async def clone(name: str = Form(...), file: UploadFile = File(...)) -> dict[str, str]:
    raw = await file.read()
    if len(raw) < 100:
        raise HTTPException(status_code=400, detail="audio too short")
    safe = "".join(ch for ch in name if ch.isalnum() or ch in "-_") or uuid.uuid4().hex[:8]
    suffix = Path(file.filename or "clip.wav").suffix.lower()
    if suffix not in {".wav", ".mp3"}:
        suffix = ".wav"
    dest = CLONES / f"{safe}{suffix}"
    dest.write_bytes(raw)
    return {
        "id": f"clone:{safe}",
        "name": name,
        "engine": ENGINE,
        "locale": "ja-JP",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app:app", host="127.0.0.1", port=int(os.environ.get("PORT", "50000")))
