"""
Coqui-to-Kokoro shim.
Translates Moltis's coqui TTS API calls → Kokoro-FastAPI OpenAI-compatible endpoint.

Coqui API (what Moltis sends):
  GET /api/tts?text=Hello&speaker_id=af_heart&language_id=en  → WAV audio
  GET /api/speakers                                            → speaker list
  GET /api/languages                                           → language list

Kokoro API (what we call):
  POST /v1/audio/speech  {"model":"kokoro","input":"...","voice":"af_heart","response_format":"wav"}
  GET  /v1/audio/voices  → voice list
"""
import os
import httpx
from fastapi import FastAPI, Query
from fastapi.responses import Response, JSONResponse

app = FastAPI(title="Kokoro-Coqui Shim")

KOKORO_URL = os.getenv("KOKORO_URL", "http://kokoro:8880")
DEFAULT_VOICE = os.getenv("DEFAULT_VOICE", "af_heart")


@app.get("/api/tts")
async def tts(
    text: str = Query(..., description="Text to synthesize"),
    speaker_id: str = Query(None, description="Voice name (Kokoro voice ID)"),
    language_id: str = Query("en"),
):
    voice = speaker_id or DEFAULT_VOICE
    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(
            f"{KOKORO_URL}/v1/audio/speech",
            json={
                "model": "kokoro",
                "input": text,
                "voice": voice,
                "response_format": "wav",
            },
        )
        resp.raise_for_status()
    return Response(content=resp.content, media_type="audio/wav")


@app.get("/api/speakers")
async def speakers():
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(f"{KOKORO_URL}/v1/audio/voices")
        resp.raise_for_status()
    voices = resp.json()
    # Coqui speaker format: list of {name, voice_id}
    return JSONResponse([{"name": v, "voice_id": v} for v in voices])


@app.get("/api/languages")
async def languages():
    return JSONResponse([{"id": "en", "name": "English"}])


@app.get("/health")
async def health():
    return {"status": "ok", "kokoro_url": KOKORO_URL}
