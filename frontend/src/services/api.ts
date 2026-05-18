// All API calls and auth token management live here.
// The frontend has zero knowledge of Supabase internals.

const API_URL = (import.meta.env.VITE_API_URL as string) || 'http://localhost:8000';

// ── Types ─────────────────────────────────────────────────────
export interface Profile {
  id: string;
  full_name: string;
  role: 'analyst' | 'pm';
}

export interface AuthSession {
  access_token: string;
  refresh_token: string;
  user_id: string;
  email: string;
  profile: Profile;
}

export interface Recording {
  id: string;
  analyst_id: string;
  type: 'freeform' | 'prompted';
  prompt_id: string | null;
  transcript: string;
  duration_secs: number | null;
  word_count: number | null;
  audio_path: string | null;
  created_at: string;
  profiles?: { full_name: string };
  prompts?: { title: string } | null;
}

export interface Prompt {
  id: string;
  created_by: string;
  title: string;
  description: string | null;
  status: 'active' | 'closed';
  deadline: string | null;
  created_at: string;
}

export interface PromptResponsesResult {
  prompt: Prompt;
  recordings: (Recording & { profiles: { full_name: string } })[];
  summary: string | null;
}

export interface RAGResult {
  query: string;
  answer: string;
  sources: {
    analyst_name: string;
    transcript: string;
    similarity: number;
    created_at: string;
    type: string;
  }[];
}

export interface MeetingNote {
  id: string;
  analyst_id: string;
  client_name: string;
  meeting_date: string;
  transcript: string;
  audio_path: string | null;
  mom: string | null;
  status: 'draft' | 'confirmed';
  created_at: string;
  updated_at: string;
  profiles?: { full_name: string };
}

// ── Session storage ───────────────────────────────────────────
const TOKEN_KEY = 'ms_access_token';
const REFRESH_KEY = 'ms_refresh_token';
const USER_KEY = 'ms_user';

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setSession(auth: AuthSession) {
  localStorage.setItem(TOKEN_KEY, auth.access_token);
  localStorage.setItem(REFRESH_KEY, auth.refresh_token);
  localStorage.setItem(USER_KEY, JSON.stringify({
    user_id: auth.user_id,
    email: auth.email,
    profile: auth.profile,
  }));
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
  localStorage.removeItem(USER_KEY);
}

export function getStoredUser(): { user_id: string; email: string; profile: Profile } | null {
  const raw = localStorage.getItem(USER_KEY);
  return raw ? JSON.parse(raw) : null;
}

// ── Core fetch wrapper ────────────────────────────────────────
export async function apiCall<T = unknown>(endpoint: string, options: RequestInit = {}): Promise<T> {
  const token = getToken();

  const res = await fetch(`${API_URL}${endpoint}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers as Record<string, string> || {}),
    },
  });

  if (res.status === 401) {
    // Try to refresh
    const refreshed = await tryRefresh();
    if (refreshed) {
      // Retry original request with new token
      return apiCall<T>(endpoint, options);
    }
    clearSession();
    window.location.href = '/login';
    throw new Error('Session expired');
  }

  if (!res.ok) {
    const body = await res.text();
    let detail = body;
    try { detail = JSON.parse(body).detail ?? body; } catch { /* */ }
    throw new Error(detail);
  }

  return res.json() as Promise<T>;
}

async function tryRefresh(): Promise<boolean> {
  const refresh = localStorage.getItem(REFRESH_KEY);
  if (!refresh) return false;
  try {
    const res = await fetch(`${API_URL}/api/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refresh }),
    });
    if (!res.ok) return false;
    const data = await res.json();
    localStorage.setItem(TOKEN_KEY, data.access_token);
    localStorage.setItem(REFRESH_KEY, data.refresh_token);
    return true;
  } catch {
    return false;
  }
}

// ── Auth API ──────────────────────────────────────────────────
export async function login(email: string, password: string): Promise<AuthSession> {
  const res = await fetch(`${API_URL}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({ detail: 'Login failed' }));
    throw new Error(body.detail ?? 'Login failed');
  }
  return res.json();
}

export async function signup(email: string, password: string, full_name: string, role: 'analyst' | 'pm' = 'analyst'): Promise<AuthSession> {
  const res = await fetch(`${API_URL}/api/auth/signup`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, full_name, role }),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({ detail: 'Signup failed' }));
    throw new Error(body.detail ?? 'Signup failed');
  }
  return res.json();
}

export async function uploadAudio(blob: Blob): Promise<{ audio_path: string }> {
  const token = getToken();
  if (!token) throw new Error('Not authenticated');
  const form = new FormData();
  form.append('audio', blob, 'recording.webm');
  const res = await fetch(`${API_URL}/api/recordings/upload-audio`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: form,
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({ detail: 'Upload failed' }));
    throw new Error(body.detail || 'Audio upload failed');
  }
  return res.json();
}

export async function saveRecording(data: {
  type: 'freeform' | 'prompted';
  prompt_id?: string;
  transcript: string;
  duration_secs?: number;
  word_count?: number;
  audio_path?: string;
}): Promise<Recording> {
  return apiCall<Recording>('/api/recordings', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function getAudioUrl(recordingId: string): Promise<{ url: string }> {
  return apiCall<{ url: string }>(`/api/recordings/${recordingId}/audio`);
}

export async function listRecordings(): Promise<Recording[]> {
  return apiCall<Recording[]>('/api/recordings');
}

// ── Prompts API ───────────────────────────────────────────────
export async function listPrompts(): Promise<Prompt[]> {
  return apiCall<Prompt[]>('/api/prompts');
}

export async function createPrompt(data: {
  title: string;
  description?: string;
  deadline?: string;
}): Promise<Prompt> {
  return apiCall<Prompt>('/api/prompts', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

export async function updatePromptStatus(id: string, status: 'active' | 'closed'): Promise<Prompt> {
  return apiCall<Prompt>(`/api/prompts/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ status }),
  });
}

export async function getPromptResponses(promptId: string): Promise<PromptResponsesResult> {
  return apiCall<PromptResponsesResult>(`/api/prompts/${promptId}/responses`);
}

// ── RAG API ───────────────────────────────────────────────────
export async function ragQuery(data: {
  query: string;
  date_from?: string;
  date_to?: string;
}): Promise<RAGResult> {
  return apiCall<RAGResult>('/api/rag/query', {
    method: 'POST',
    body: JSON.stringify(data),
  });
}

// ── Speech token ──────────────────────────────────────────────
export async function getSpeechToken(): Promise<{ token: string; region: string }> {
  return apiCall<{ token: string; region: string }>('/api/get-speech-token');
}
