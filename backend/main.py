import os
import requests as req_lib
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

import google.genai as genai
from google.genai import types as genai_types
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from supabase import Client, create_client

load_dotenv()

# ── Config ────────────────────────────────────────────────────
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SECRET_KEY", "")   # publishable key in env
AZURE_SPEECH_KEY = os.getenv("AZURE_SPEECH_KEY", "")
AZURE_SPEECH_REGION = os.getenv("AZURE_SPEECH_REGION", "eastus")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
ALLOWED_ORIGINS = [o.strip() for o in os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:5173,http://localhost:5174,http://localhost:5175"
).split(",")]

# ── Clients ───────────────────────────────────────────────────
# Auth-only global client — used solely for auth.sign_up / sign_in / get_user
auth_client = create_client(SUPABASE_URL, SUPABASE_KEY)
gemini_client = genai.Client(api_key=GEMINI_API_KEY)

# ── App ───────────────────────────────────────────────────────
app = FastAPI(title="Shunya Mindstream API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex="https?://.*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Per-request Supabase client ───────────────────────────────
def get_user_db(token: str) -> Client:
    """
    Returns a Supabase client with the user's JWT attached so that
    PostgREST evaluates RLS policies as that authenticated user.
    Uses the publishable key — JWT is what controls row-level access.
    """
    client = create_client(SUPABASE_URL, SUPABASE_KEY)
    client.postgrest.auth(token)
    return client

# ── Auth dependency ───────────────────────────────────────────
security = HTTPBearer()

@dataclass
class AuthResult:
    user: object   # supabase User
    token: str

    @property
    def id(self) -> str:
        return self.user.id  # type: ignore[attr-defined]

def get_current_user(creds: HTTPAuthorizationCredentials = Depends(security)) -> AuthResult:
    token = creds.credentials
    try:
        resp = auth_client.auth.get_user(token)
        return AuthResult(user=resp.user, token=token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token.")

def require_pm(auth: AuthResult = Depends(get_current_user)) -> AuthResult:
    udb = get_user_db(auth.token)
    resp = udb.table("profiles").select("role").eq("id", auth.id).single().execute()
    if not resp.data or resp.data.get("role") != "pm":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="PM access required.")
    return auth

# ── Embedding ─────────────────────────────────────────────────
def embed(text: str, task: str = "retrieval_document") -> list[float]:
    """768-dim embedding via gemini-embedding-001 (Matryoshka truncated)."""
    result = gemini_client.models.embed_content(
        model="gemini-embedding-001",
        contents=text,
        config=genai_types.EmbedContentConfig(task_type=task, output_dimensionality=768),
    )
    return result.embeddings[0].values

# ── Pydantic models ───────────────────────────────────────────
class SignupRequest(BaseModel):
    email: str
    password: str
    full_name: str
    role: str = "analyst"  # 'analyst' | 'pm'

class LoginRequest(BaseModel):
    email: str
    password: str

class SaveRecordingRequest(BaseModel):
    type: str                         # 'freeform' | 'prompted'
    prompt_id: Optional[str] = None
    transcript: str
    duration_secs: Optional[int] = None
    word_count: Optional[int] = None
    audio_path: Optional[str] = None  # set after audio upload

class CreatePromptRequest(BaseModel):
    title: str
    description: Optional[str] = None
    deadline: Optional[datetime] = None

class RAGQueryRequest(BaseModel):
    query: str
    date_from: Optional[datetime] = None
    date_to: Optional[datetime] = None

class GenerateMoMRequest(BaseModel):
    transcript: str
    client_name: str
    meeting_date: str   # ISO date string YYYY-MM-DD
    analyst_name: str

class SaveMeetingRequest(BaseModel):
    client_name: str
    meeting_date: str
    transcript: str
    audio_path: Optional[str] = None
    mom: str
    status: str = "confirmed"  # 'draft' | 'confirmed'

# ── Auth endpoints ────────────────────────────────────────────
@app.post("/api/auth/signup")
async def signup(body: SignupRequest):
    role = body.role if body.role in ("analyst", "pm") else "analyst"
    try:
        result = auth_client.auth.sign_up({
            "email": body.email,
            "password": body.password,
            "options": {
                "data": {
                    "full_name": body.full_name,
                    "role": role,          # trigger reads this to set the correct role
                }
            },
        })
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not result.session:
        return {"message": "Check your email to confirm your account."}

    # Trigger handle_new_user already created the profile with the correct role.
    # Just read it back to return to the client.
    udb = get_user_db(result.session.access_token)
    profile_resp = udb.table("profiles").select("*").eq("id", result.user.id).single().execute()
    profile = profile_resp.data or {"id": result.user.id, "full_name": body.full_name, "role": role}

    return {
        "access_token": result.session.access_token,
        "refresh_token": result.session.refresh_token,
        "user_id": result.user.id,
        "email": result.user.email,
        "profile": profile,
    }


@app.post("/api/auth/login")
async def login(body: LoginRequest):
    try:
        result = auth_client.auth.sign_in_with_password({
            "email": body.email,
            "password": body.password,
        })
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid email or password.")

    udb = get_user_db(result.session.access_token)
    profile_resp = udb.table("profiles").select("*").eq("id", result.user.id).single().execute()
    profile = profile_resp.data or {}

    return {
        "access_token": result.session.access_token,
        "refresh_token": result.session.refresh_token,
        "user_id": result.user.id,
        "email": result.user.email,
        "profile": profile,
    }


@app.post("/api/auth/refresh")
async def refresh_token(body: dict):
    refresh = body.get("refresh_token")
    if not refresh:
        raise HTTPException(status_code=400, detail="refresh_token required.")
    try:
        result = auth_client.auth.refresh_session(refresh)
    except Exception:
        raise HTTPException(status_code=401, detail="Could not refresh token.")
    return {
        "access_token": result.session.access_token,
        "refresh_token": result.session.refresh_token,
    }


@app.get("/api/auth/me")
async def me(auth: AuthResult = Depends(get_current_user)):
    udb = get_user_db(auth.token)
    profile_resp = udb.table("profiles").select("*").eq("id", auth.id).single().execute()
    return {"user_id": auth.id, "email": auth.user.email, "profile": profile_resp.data or {}}


# ── Azure Speech token ────────────────────────────────────────
@app.get("/api/get-speech-token")
async def get_speech_token(auth: AuthResult = Depends(get_current_user)):
    if not AZURE_SPEECH_KEY or not AZURE_SPEECH_REGION:
        raise HTTPException(status_code=500, detail="Azure Speech not configured.")

    url = f"https://{AZURE_SPEECH_REGION}.api.cognitive.microsoft.com/sts/v1.0/issueToken"
    headers = {
        "Ocp-Apim-Subscription-Key": AZURE_SPEECH_KEY,
        "Content-type": "application/x-www-form-urlencoded",
    }
    try:
        resp = req_lib.post(url, headers=headers, timeout=5)
        resp.raise_for_status()
        return {"token": resp.text, "region": AZURE_SPEECH_REGION}
    except req_lib.exceptions.RequestException as e:
        print(f"[Azure] token fetch error: {e}")
        raise HTTPException(status_code=502, detail="Failed to reach Azure STS.")


# ── Recordings ────────────────────────────────────────────────
@app.post("/api/recordings")
async def save_recording(body: SaveRecordingRequest, auth: AuthResult = Depends(get_current_user)):
    if body.type == "prompted" and not body.prompt_id:
        raise HTTPException(status_code=400, detail="prompt_id required for prompted recordings.")

    try:
        embedding = embed(body.transcript, task="retrieval_document")
    except Exception as e:
        print(f"[Gemini] embedding error: {e}")
        embedding = None

    record = {
        "analyst_id": auth.id,
        "type": body.type,
        "prompt_id": body.prompt_id,
        "transcript": body.transcript,
        "embedding": embedding,
        "duration_secs": body.duration_secs,
        "word_count": body.word_count,
        "audio_path": body.audio_path,
    }

    udb = get_user_db(auth.token)
    result = udb.table("recordings").insert(record).execute()
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to save recording.")
    return result.data[0]


@app.get("/api/recordings")
async def list_recordings(auth: AuthResult = Depends(get_current_user)):
    udb = get_user_db(auth.token)
    result = udb.table("recordings").select("*, profiles(full_name), prompts(title)").order("created_at", desc=True).execute()
    return result.data or []


@app.post("/api/recordings/upload-audio")
async def upload_audio(
    audio: UploadFile = File(...),
    auth: AuthResult = Depends(get_current_user),
):
    """Upload a raw audio file to Supabase Storage; returns the storage path."""
    import uuid
    recording_id = str(uuid.uuid4())
    path = f"{auth.id}/{recording_id}.webm"
    audio_bytes = await audio.read()
    content_type = audio.content_type or "audio/webm"

    upload_url = f"{SUPABASE_URL}/storage/v1/object/recordings/{path}"
    headers = {
        "Authorization": f"Bearer {auth.token}",
        "apikey": SUPABASE_KEY,
        "Content-Type": content_type,
    }
    resp = req_lib.post(upload_url, data=audio_bytes, headers=headers)
    if not resp.ok:
        raise HTTPException(status_code=500, detail=f"Audio upload failed: {resp.text}")

    return {"audio_path": f"recordings/{path}"}


@app.get("/api/recordings/{recording_id}/audio")
async def get_audio_url(
    recording_id: str,
    auth: AuthResult = Depends(get_current_user),
):
    """Generate a short-lived signed URL for playback of a stored recording."""
    udb = get_user_db(auth.token)
    rec = udb.table("recordings").select("audio_path").eq("id", recording_id).single().execute()
    if not rec.data or not rec.data.get("audio_path"):
        raise HTTPException(status_code=404, detail="No audio stored for this recording.")

    # Strip the 'recordings/' bucket prefix to get the object path
    object_path = rec.data["audio_path"].removeprefix("recordings/")
    sign_url = f"{SUPABASE_URL}/storage/v1/object/sign/recordings/{object_path}"
    headers = {"Authorization": f"Bearer {auth.token}", "apikey": SUPABASE_KEY}
    resp = req_lib.post(sign_url, json={"expiresIn": 3600}, headers=headers)
    if not resp.ok:
        raise HTTPException(status_code=500, detail="Could not generate signed URL.")

    signed_path = resp.json().get("signedURL", "")
    return {"url": f"{SUPABASE_URL}/storage/v1{signed_path}"}


# ── Prompts ───────────────────────────────────────────────────
@app.get("/api/prompts")
async def list_prompts(auth: AuthResult = Depends(get_current_user)):
    udb = get_user_db(auth.token)
    result = udb.table("prompts").select("*").order("created_at", desc=True).execute()
    return result.data or []


@app.post("/api/prompts")
async def create_prompt(body: CreatePromptRequest, auth: AuthResult = Depends(require_pm)):
    record = {
        "created_by": auth.id,
        "title": body.title,
        "description": body.description,
        "deadline": body.deadline.isoformat() if body.deadline else None,
    }
    udb = get_user_db(auth.token)
    result = udb.table("prompts").insert(record).execute()
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create prompt.")
    return result.data[0]


@app.patch("/api/prompts/{prompt_id}")
async def update_prompt(prompt_id: str, body: dict, auth: AuthResult = Depends(require_pm)):
    allowed = {"status", "title", "description", "deadline"}
    update = {k: v for k, v in body.items() if k in allowed}
    udb = get_user_db(auth.token)
    result = udb.table("prompts").update(update).eq("id", prompt_id).execute()
    return result.data[0] if result.data else {}


@app.get("/api/prompts/{prompt_id}/responses")
async def prompt_responses(prompt_id: str, auth: AuthResult = Depends(require_pm)):
    udb = get_user_db(auth.token)

    recordings_resp = (
        udb.table("recordings")
        .select("*, profiles(full_name)")
        .eq("prompt_id", prompt_id)
        .order("created_at", desc=True)
        .execute()
    )
    recordings = recordings_resp.data or []

    prompt_resp = udb.table("prompts").select("*").eq("id", prompt_id).single().execute()
    prompt = prompt_resp.data or {}

    summary = None
    if recordings:
        context = "\n\n".join(
            f"Analyst: {r.get('profiles', {}).get('full_name', 'Unknown')}\nTranscript: {r['transcript']}"
            for r in recordings
        )
        synthesis_prompt = f"""You are a senior analyst at a long/only equity fund.
The portfolio manager issued the following prompt to their analyst team:

PROMPT: {prompt.get('title', '')}
{prompt.get('description', '') or ''}

Below are the analyst responses:

{context}

Write a concise synthesis (3–5 paragraphs) that:
1. States the overall sentiment (bullish / bearish / mixed) and why
2. Highlights key themes and areas of consensus
3. Notes any diverging views, attributing them to specific analysts by name
4. Flags any actionable insights for the PM

Be direct and professional — this is for internal investment decision-making."""
        try:
            response = gemini_client.models.generate_content(
                model="gemini-2.0-flash", contents=synthesis_prompt
            )
            summary = response.text
        except Exception as e:
            print(f"[Gemini] synthesis error: {e}")
            summary = "Summary unavailable."

    return {"prompt": prompt, "recordings": recordings, "summary": summary}


# ── RAG Query ─────────────────────────────────────────────────
@app.post("/api/rag/query")
async def rag_query(body: RAGQueryRequest, auth: AuthResult = Depends(require_pm)):
    try:
        query_embedding = embed(body.query, task="retrieval_query")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Embedding failed: {e}")

    udb = get_user_db(auth.token)
    rpc_params = {
        "query_embedding": query_embedding,
        "match_threshold": 0.45,
        "match_count": 25,
        "filter_from": body.date_from.isoformat() if body.date_from else None,
        "filter_to": body.date_to.isoformat() if body.date_to else None,
        "filter_prompt_id": None,
    }
    search_resp = udb.rpc("match_recordings", rpc_params).execute()
    matches = search_resp.data or []

    if not matches:
        return {"query": body.query, "answer": "No relevant analyst recordings found for this query.", "sources": []}

    # Enrich with analyst names using the same user-scoped client
    analyst_ids = list({m["analyst_id"] for m in matches})
    profiles_resp = udb.table("profiles").select("id, full_name").in_("id", analyst_ids).execute()
    profile_map = {p["id"]: p["full_name"] for p in (profiles_resp.data or [])}

    context_blocks = [
        f"[{profile_map.get(m['analyst_id'], 'Unknown')}, {m.get('created_at', '')[:10]}, relevance={m['similarity']:.0%}]\n{m['transcript']}"
        for m in matches
    ]

    synthesis_prompt = f"""You are a senior research analyst at a long/only equity fund helping the portfolio manager understand analyst views.

PM's question: "{body.query}"
{"Date range: " + (body.date_from.strftime('%Y-%m-%d') if body.date_from else 'any') + " → " + (body.date_to.strftime('%Y-%m-%d') if body.date_to else 'present') if body.date_from or body.date_to else ""}

Most relevant analyst recordings (by semantic relevance):

{chr(10).join("---" + chr(10) + b for b in context_blocks)}

Provide a well-structured, attributed answer that:
1. Directly answers the question with analyst evidence
2. Attributes specific insights by name (e.g. "Alex noted that…")
3. Highlights consensus vs. outlier views
4. Draws investment-relevant conclusions

Be precise and professional."""

    try:
        response = gemini_client.models.generate_content(
            model="gemini-2.0-flash", contents=synthesis_prompt
        )
        answer = response.text
    except Exception as e:
        print(f"[Gemini] RAG error: {e}")
        answer = "Synthesis unavailable."

    sources = [
        {
            "analyst_name": profile_map.get(m["analyst_id"], "Unknown"),
            "transcript": m["transcript"],
            "similarity": round(m["similarity"], 3),
            "created_at": m["created_at"],
            "type": m["type"],
        }
        for m in matches[:10]
    ]

    return {"query": body.query, "answer": answer, "sources": sources}


# ── Meeting Notes ─────────────────────────────────────────────
@app.post("/api/meetings/generate-mom")
async def generate_mom(body: GenerateMoMRequest, auth: AuthResult = Depends(get_current_user)):
    """Generate a Minutes of Meeting document from the voice note transcript."""
    prompt = f"""You are a senior analyst at a long/only equity fund.
The following is a voice note recorded after a client meeting.

Analyst: {body.analyst_name}
Client: {body.client_name}
Meeting Date: {body.meeting_date}

VOICE NOTE TRANSCRIPT:
{body.transcript}

Generate professional **Minutes of Meeting** in markdown format with these sections:

## Meeting Details
- **Client:** {body.client_name}
- **Date:** {body.meeting_date}
- **Analyst:** {body.analyst_name}

## Key Discussion Points
[Bullet summary of main topics discussed]

## Client Views & Sentiment
[What the client said, their outlook, concerns, opportunities they mentioned]

## Action Items
[Specific follow-ups, tasks, or next steps]

## Investment Implications
[Any market themes, stock ideas, or portfolio considerations that emerged]

Be concise, professional, and accurate to what was said. Do not fabricate anything not in the transcript."""

    try:
        response = gemini_client.models.generate_content(
            model="gemini-2.0-flash", contents=prompt
        )
        return {"mom": response.text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"MoM generation failed: {e}")


@app.post("/api/meetings")
async def save_meeting(body: SaveMeetingRequest, auth: AuthResult = Depends(get_current_user)):
    udb = get_user_db(auth.token)
    record = {
        "analyst_id": auth.id,
        "client_name": body.client_name,
        "meeting_date": body.meeting_date,
        "transcript": body.transcript,
        "audio_path": body.audio_path,
        "mom": body.mom,
        "status": body.status if body.status in ("draft", "confirmed") else "confirmed",
    }
    result = udb.table("meeting_notes").insert(record).execute()
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to save meeting note.")
    return result.data[0]


@app.get("/api/meetings")
async def list_meetings(auth: AuthResult = Depends(get_current_user)):
    udb = get_user_db(auth.token)
    result = (
        udb.table("meeting_notes")
        .select("*, profiles(full_name)")
        .order("meeting_date", desc=True)
        .execute()
    )
    return result.data or []


@app.get("/api/meetings/{meeting_id}")
async def get_meeting(meeting_id: str, auth: AuthResult = Depends(get_current_user)):
    udb = get_user_db(auth.token)
    result = udb.table("meeting_notes").select("*").eq("id", meeting_id).single().execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Meeting note not found.")
    return result.data


@app.patch("/api/meetings/{meeting_id}")
async def update_meeting(meeting_id: str, body: dict, auth: AuthResult = Depends(get_current_user)):
    allowed = {"mom", "status", "client_name", "meeting_date"}
    update = {k: v for k, v in body.items() if k in allowed}
    update["updated_at"] = datetime.utcnow().isoformat()
    udb = get_user_db(auth.token)
    result = udb.table("meeting_notes").update(update).eq("id", meeting_id).execute()
    return result.data[0] if result.data else {}


@app.get("/")
async def root():
    return {"message": "Shunya Mindstream API v2"}
