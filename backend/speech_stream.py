"""WebSocket proxy: client streams PCM audio, server runs Azure continuous recognition."""

from __future__ import annotations

import asyncio
import json
import os
from typing import Optional

import azure.cognitiveservices.speech as speechsdk
from fastapi import WebSocket, WebSocketDisconnect

AZURE_SPEECH_KEY = os.getenv("AZURE_SPEECH_KEY", "")
AZURE_SPEECH_REGION = os.getenv("AZURE_SPEECH_REGION", "eastus")

SAMPLE_RATE = 16000
BITS_PER_SAMPLE = 16
CHANNELS = 1


async def handle_speech_stream(websocket: WebSocket, auth_client, token: str) -> None:
    """
    Protocol:
      - Connect: GET /api/speech/stream?token=<jwt>
      - Server -> client JSON: ready | partial | final | error
      - Client -> server: binary PCM16 LE 16kHz mono chunks
      - Client -> server text JSON: {"action": "stop"} to end session
    """
    await websocket.accept()

    if not AZURE_SPEECH_KEY or not AZURE_SPEECH_REGION:
        await websocket.send_json(
            {"event": "error", "message": "Azure Speech is not configured on the server."}
        )
        await websocket.close(code=1011)
        return

    try:
        auth_client.auth.get_user(token)
    except Exception:
        await websocket.send_json(
            {"event": "error", "message": "Invalid or expired token."}
        )
        await websocket.close(code=1008)
        return

    loop = asyncio.get_running_loop()
    outbound: asyncio.Queue[dict] = asyncio.Queue()

    def emit(event: str, **payload: object) -> None:
        asyncio.run_coroutine_threadsafe(
            outbound.put({"event": event, **payload}),
            loop,
        )

    stream_format = speechsdk.audio.AudioStreamFormat(
        samples_per_second=SAMPLE_RATE,
        bits_per_sample=BITS_PER_SAMPLE,
        channels=CHANNELS,
    )
    push_stream = speechsdk.audio.PushAudioInputStream(stream_format)
    audio_config = speechsdk.audio.AudioConfig(stream=push_stream)

    speech_config = speechsdk.SpeechConfig(
        subscription=AZURE_SPEECH_KEY,
        region=AZURE_SPEECH_REGION,
    )
    speech_config.speech_recognition_language = "en-US"

    recognizer = speechsdk.SpeechRecognizer(
        speech_config=speech_config,
        audio_config=audio_config,
    )

    def on_recognizing(evt: speechsdk.SpeechRecognitionEventArgs) -> None:
        if evt.result.reason == speechsdk.ResultReason.RecognizingSpeech:
            text = (evt.result.text or "").strip()
            if text:
                emit("partial", text=text)

    def on_recognized(evt: speechsdk.SpeechRecognitionEventArgs) -> None:
        if evt.result.reason == speechsdk.ResultReason.RecognizedSpeech:
            text = (evt.result.text or "").strip()
            if text:
                emit("final", text=text)

    def on_canceled(evt: speechsdk.SpeechRecognitionCanceledEventArgs) -> None:
        details = evt.result.cancellation_details
        message = details.error_details or str(details.reason)
        emit("error", message=message)

    recognizer.recognizing.connect(on_recognizing)
    recognizer.recognized.connect(on_recognized)
    recognizer.canceled.connect(on_canceled)

    forwarder: Optional[asyncio.Task] = None

    async def forward_events() -> None:
        while True:
            msg = await outbound.get()
            await websocket.send_json(msg)

    try:
        recognizer.start_continuous_recognition_async().get()
        forwarder = asyncio.create_task(forward_events())
        await websocket.send_json({"event": "ready"})

        while True:
            message = await websocket.receive()
            if message.get("type") == "websocket.disconnect":
                break
            chunk = message.get("bytes")
            if chunk:
                push_stream.write(chunk)
                continue
            text = message.get("text")
            if text:
                try:
                    data = json.loads(text)
                except json.JSONDecodeError:
                    continue
                if data.get("action") == "stop":
                    break
    except WebSocketDisconnect:
        pass
    finally:
        if forwarder is not None:
            forwarder.cancel()
            try:
                await forwarder
            except asyncio.CancelledError:
                pass
        try:
            push_stream.close()
        except Exception:
            pass
        try:
            recognizer.stop_continuous_recognition_async().get()
        except Exception:
            pass
        try:
            await websocket.close()
        except Exception:
            pass
