import { useState, useEffect, useCallback, useRef } from 'react';
import { saveRecording, uploadAudio, listRecordings, getAudioUrl, listPrompts } from '../services/api';
import type { Recording, Prompt } from '../services/api';
import { useSpeech } from '../hooks/useSpeech';
import { useAudioVisualizer } from '../hooks/useAudioVisualizer';
import { useMediaRecorder } from '../hooks/useMediaRecorder';
import { useTheme } from '../contexts/ThemeContext';
import { useAuth } from '../contexts/AuthContext';
import { Button, Card, Tooltip, Segmented } from 'antd';
import {
  SunOutlined,
  MoonOutlined,
  LogoutOutlined,
  DeleteOutlined,
  SaveOutlined,
  EyeOutlined,
  EyeInvisibleOutlined,
  AudioOutlined,
  EditOutlined,
  HistoryOutlined,
  LeftOutlined,
  RightOutlined,
  PlayCircleOutlined,
  PauseCircleOutlined,
  ArrowLeftOutlined,
  BulbOutlined,
  CheckOutlined
} from '@ant-design/icons';
/* ── Mindstream Aura — Elegant Concentric Breathing Rings ─── */
function MindstreamAura({ analyserRef, isActive, isLoading }: {
  analyserRef: React.RefObject<AnalyserNode | null>;
  isActive: boolean;
  isLoading: boolean;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rafRef    = useRef<number>(0);
  const frameRef  = useRef(0);
  const ampRef    = useRef(0);
  const { themeMode } = useTheme();

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const dpr = window.devicePixelRatio || 1;
    const resize = () => {
      canvas.width = canvas.offsetWidth * dpr;
      canvas.height = canvas.offsetHeight * dpr;
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);

    const draw = () => {
      frameRef.current++;
      const f = frameRef.current;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;

      const W = canvas.width, H = canvas.height;
      ctx.clearRect(0, 0, W, H);
      const cx = W / 2, cy = H / 2;
      const t = f * 0.015;
      const isLgt = themeMode === 'light';

      /* ── Fetch & Smooth Audio Amplitude ── */
      let rawAmp = 0;
      if (isActive && analyserRef.current) {
        const td = new Uint8Array(analyserRef.current.fftSize);
        analyserRef.current.getByteTimeDomainData(td);
        let ss = 0;
        for (let i = 0; i < td.length; i++) {
          const v = (td[i] - 128) / 128;
          ss += v * v;
        }
        rawAmp = Math.min(1, Math.sqrt(ss / td.length) * 7.5);
      }
      ampRef.current += (rawAmp - ampRef.current) * 0.15;
      const amp = ampRef.current;

      /* ── Meditative Breathing Scale ── */
      // Slow, deep breath cycle (approx 5.5s)
      const breatheCycle = isLoading ? t * 2.2 : t * 0.4;
      const breathe = 1.0 + 0.04 * Math.sin(breatheCycle);

      // Max radius restricted to 32% of smallest canvas dimension to guarantee NO clipping
      const maxAllowedR = Math.min(W, H) * 0.32;
      const baseR = maxAllowedR * breathe;

      /* ── Draw 3 Concentric Floating Aura Rings ── */
      const numRings = 3;
      for (let rIdx = 0; rIdx < numRings; rIdx++) {
        ctx.beginPath();

        const ringPhaseOffset = rIdx * (Math.PI * 2 / numRings);
        const ringScale = 0.65 + 0.35 * (rIdx / (numRings - 1 || 1));
        const currentR = baseR * ringScale * (1.0 + amp * 0.15);

        const numPoints = 120;
        for (let i = 0; i <= numPoints; i++) {
          const angle = (i / numPoints) * Math.PI * 2;

          // Undulate perimeter: gentle drift at rest, vibrating ripples when speaking
          const restingWave = 0.015 * Math.sin(angle * 4 - t * 0.8 + ringPhaseOffset);
          const voiceWave = isActive
            ? (0.02 + amp * 0.08) * Math.sin(angle * (8 + rIdx * 2) + t * 4.5)
            : 0;
          
          const totalRadius = currentR * (1.0 + restingWave + voiceWave);

          // Center shifts slightly to give a floating/hovering organic 3D illusion
          const shiftX = Math.cos(t * 0.5 + ringPhaseOffset) * 6 * dpr * (1.0 - ringScale);
          const shiftY = Math.sin(t * 0.4 + ringPhaseOffset) * 6 * dpr * (1.0 - ringScale);

          const x = cx + shiftX + Math.cos(angle) * totalRadius;
          const y = cy + shiftY + Math.sin(angle) * totalRadius;

          if (i === 0) {
            ctx.moveTo(x, y);
          } else {
            ctx.lineTo(x, y);
          }
        }
        ctx.closePath();

        // Stylize: Soft cream/beige at rest, transitioning to soothing sage teal when active/loading
        let hue, sat, lit, alpha;
        if (isActive) {
          hue = 172; // teal
          sat = isLgt ? 45 : 35 + rIdx * 5;
          lit = isLgt ? 40 : 55 + rIdx * 5;
          alpha = (isLgt ? 0.22 + amp * 0.25 : 0.15 + (1 - ringScale) * 0.18 + amp * 0.25) * (0.8 + 0.2 * Math.sin(t + rIdx));
        } else if (isLoading) {
          hue = 172; // teal
          sat = isLgt ? 35 : 25;
          lit = isLgt ? 45 : 60;
          alpha = isLgt ? 0.22 + 0.05 * Math.sin(t * 3) : 0.15 + 0.05 * Math.sin(t * 3);
        } else {
          hue = 34; // warm sand / taupe
          sat = isLgt ? 25 : 15;
          lit = isLgt ? 42 - rIdx * 4 : 65 - rIdx * 5;
          alpha = isLgt ? 0.18 + (1 - ringScale) * 0.16 : 0.08 + (1 - ringScale) * 0.12;
        }

        ctx.strokeStyle = `hsla(${hue}, ${sat}%, ${lit}%, ${alpha})`;
        ctx.lineWidth = (1.5 + (1 - ringScale) * 1.5 + amp * 1.5) * dpr;
        
        // Add a gentle blur to active/outer rings for a dreamlike glow
        ctx.shadowColor = `hsla(${hue}, ${sat}%, ${lit}%, ${alpha * 0.5})`;
        ctx.shadowBlur = isActive ? 12 * dpr : 4 * dpr;

        ctx.stroke();
        
        // Reset shadow for next rings/elements
        ctx.shadowBlur = 0;
      }

      /* ── Draw Subtle Centered Glowing Nucleus ── */
      const nucleusR = baseR * 0.22 * (1.0 + amp * 0.1);
      const glowGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, nucleusR * 2.5);
      
      let startColor, endColor;
      if (isActive) {
        startColor = isLgt
          ? `rgba(76, 140, 127, ${0.15 + amp * 0.15})`
          : `rgba(106, 173, 160, ${0.08 + amp * 0.12})`;
        endColor = isLgt ? `rgba(76, 140, 127, 0)` : `rgba(106, 173, 160, 0)`;
      } else if (isLoading) {
        startColor = isLgt ? `rgba(76, 140, 127, 0.08)` : `rgba(106, 173, 160, 0.05)`;
        endColor = isLgt ? `rgba(76, 140, 127, 0)` : `rgba(106, 173, 160, 0)`;
      } else {
        startColor = isLgt ? `rgba(120, 110, 100, 0.08)` : `rgba(180, 165, 148, 0.04)`;
        endColor = isLgt ? `rgba(120, 110, 100, 0)` : `rgba(180, 165, 148, 0)`;
      }
      
      glowGrad.addColorStop(0, startColor);
      glowGrad.addColorStop(1, endColor);
      
      ctx.beginPath();
      ctx.arc(cx, cy, nucleusR * 2.5, 0, Math.PI * 2);
      ctx.fillStyle = glowGrad;
      ctx.fill();

      rafRef.current = requestAnimationFrame(draw);
    };

    rafRef.current = requestAnimationFrame(draw);
    return () => { cancelAnimationFrame(rafRef.current); ro.disconnect(); };
  }, [isActive, isLoading, analyserRef, themeMode]);

  return <canvas ref={canvasRef} className="orb-canvas" />;
}


/* ── Fading word-window caption ─────────────────────────────── */
const MAX_W = 7;
const FADE  = [0.10, 0.18, 0.30, 0.45, 0.62, 0.82, 1.0];

function CaptionWords({ text }: { text: string }) {
  const words = text.trim().split(/\s+/).filter(Boolean);
  const start = Math.max(0, words.length - MAX_W);
  const visible = words.slice(start);
  return (
    <span className="caption-words">
      {visible.map((word, li) => {
        const gi = start + li;
        const fromEnd = words.length - 1 - gi;
        const opacity = FADE[Math.max(0, FADE.length - 1 - fromEnd)];
        return (
          <span key={gi} style={{ opacity, transition: 'opacity 0.55s ease' }}>
            {word}{' '}
          </span>
        );
      })}
    </span>
  );
}

/* ── Helpers ─────────────────────────────────────────────────── */
const fmtTime = (s: number) =>
  `${Math.floor(s / 60).toString().padStart(2, '0')}:${(s % 60).toString().padStart(2, '0')}`;
const wc = (t: string) => (t.trim() ? t.trim().split(/\s+/).length : 0);

/* ── ArchiveRecordingCard ────────────────────────────────────── */
function ArchiveRecordingCard({ recording }: { recording: Recording }) {
  const [playing, setPlaying] = useState(false);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  const togglePlay = async () => {
    if (!recording.audio_path) return;

    try {
      if (playing) {
        audioRef.current?.pause();
        setPlaying(false);
      } else {
        if (!audioUrl) {
          const { url } = await getAudioUrl(recording.id);
          setAudioUrl(url);
          
          setTimeout(() => {
            audioRef.current?.play();
            setPlaying(true);
          }, 50);
        } else {
          audioRef.current?.play();
          setPlaying(true);
        }
      }
    } catch (err) {
      console.error('Audio playback failed:', err);
    }
  };

  const formattedTime = new Date(recording.created_at).toLocaleTimeString('default', {
    hour: 'numeric',
    minute: '2-digit'
  });

  const formattedDate = new Date(recording.created_at).toLocaleDateString('default', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  });

  return (
    <Card className="archive-rec-card" bordered={false}>
      <div className="archive-rec-header">
        <div className="archive-rec-meta">
          <span className="archive-rec-time">{formattedTime}</span>
          <span className="archive-rec-date">{formattedDate}</span>
        </div>

        <div className="archive-rec-actions">
          <div className="stat-chips" style={{ marginRight: 8 }}>
            {recording.audio_path ? (
              <span className="stat-chip stat-chip-green">voice</span>
            ) : (
              <span className="stat-chip stat-chip-blue">text</span>
            )}
          </div>

          {recording.audio_path && (
            <Button
              type="text"
              shape="circle"
              icon={playing ? <PauseCircleOutlined style={{ fontSize: 20, color: 'var(--violet)' }} /> : <PlayCircleOutlined style={{ fontSize: 20, color: 'var(--text)' }} />}
              onClick={togglePlay}
              className="action-icon-btn"
            />
          )}
        </div>
      </div>

      {recording.prompts && (
        <div className="archive-rec-prompt-banner">
          <span className="arpb-indicator">Response to Prompt:</span>
          <span className="arpb-title">{recording.prompts.title}</span>
        </div>
      )}

      <div className="archive-rec-body">
        <p className="archive-rec-text">{recording.transcript}</p>
      </div>

      {recording.audio_path && audioUrl && (
        <audio
          ref={audioRef}
          src={audioUrl}
          onEnded={() => setPlaying(false)}
          onPause={() => setPlaying(false)}
          style={{ display: 'none' }}
        />
      )}
    </Card>
  );
}

/* ── AnalystHome ─────────────────────────────────────────────── */
export default function AnalystHome() {
  const { themeMode, toggleTheme } = useTheme();
  const { logout } = useAuth();
  
  const { isListening, finalTranscript, interimText,
          startListening, stopListening, clearTranscript } = useSpeech();
  const { analyserRef, start: vizStart, stop: vizStop } = useAudioVisualizer();
  const { audioBlob, start: mediaStart, stop: mediaStop, reset: mediaReset } = useMediaRecorder();

  const [viewMode,     setViewMode]    = useState<'stream' | 'archive' | 'prompts'>('stream');
  const [recordings,   setRecordings]  = useState<Recording[]>([]);
  const [recordingsLoading, setRecordingsLoading] = useState(false);
  const [currentDate,  setCurrentDate] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  
  const [prompts,      setPrompts]     = useState<Prompt[]>([]);
  const [selectedPrompt, setSelectedPrompt] = useState<Prompt | null>(null);
  const [promptsLoading, setPromptsLoading] = useState(false);
  
  const [inputMode,    setInputMode]   = useState<'voice' | 'text'>('voice');
  const [typedText,    setTypedText]   = useState('');
  const [hasSubmittedText, setHasSubmittedText] = useState(false);
  const [isLoading,    setIsLoading]   = useState(false);
  const [duration,     setDuration]    = useState(0);
  const [saving,       setSaving]      = useState(false);
  const [saveStatus,   setSaveStatus]  = useState<'idle'|'uploading'|'saving'|'done'>('idle');
  const [saveError,    setSaveError]   = useState<string | null>(null);
  const [expanded,     setExpanded]    = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const transcriptToUse = inputMode === 'voice' ? finalTranscript : typedText;

  // Load previous notes (recordings) on demand
  const fetchRecordings = useCallback(async () => {
    setRecordingsLoading(true);
    try {
      const data = await listRecordings();
      setRecordings(data.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()));
    } catch (err) {
      console.error('Failed to load past recordings:', err);
    } finally {
      setRecordingsLoading(false);
    }
  }, []);

  const fetchPrompts = useCallback(async () => {
    try {
      setPromptsLoading(true);
      const allPrompts = await listPrompts();
      const active = allPrompts.filter(p => p.status === 'active');
      setPrompts(active);
    } catch (err) {
      console.error('Failed to load prompts:', err);
    } finally {
      setPromptsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchPrompts();
  }, [fetchPrompts]);

  useEffect(() => {
    if (viewMode === 'archive') {
      fetchRecordings();
    }
  }, [viewMode, fetchRecordings]);

  // Custom calendar date helper derivations
  const year = currentDate.getFullYear();
  const month = currentDate.getMonth();
  const numDays = new Date(year, month + 1, 0).getDate();
  let startOffset = new Date(year, month, 1).getDay();
  startOffset = startOffset === 0 ? 6 : startOffset - 1; // Align to Monday index start

  const handlePrevMonth = () => {
    setCurrentDate(new Date(year, month - 1, 1));
  };

  const handleNextMonth = () => {
    setCurrentDate(new Date(year, month + 1, 1));
  };

  const getRecordingsForDay = (day: number) => {
    return recordings.filter(r => {
      const rDate = new Date(r.created_at);
      return rDate.getFullYear() === year &&
             rDate.getMonth() === month &&
             rDate.getDate() === day;
    });
  };

  /* Clear loading as soon as we're actually listening */
  useEffect(() => { if (isListening) setIsLoading(false); }, [isListening]);

  /* Timer */
  useEffect(() => {
    if (isListening) {
      setDuration(0);
      timerRef.current = setInterval(() => setDuration(d => d + 1), 1000);
    } else {
      if (timerRef.current) clearInterval(timerRef.current);
    }
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
  }, [isListening]);

  const handleToggle = useCallback(async () => {
    if (isListening) {
      stopListening(); vizStop(); mediaStop();
    } else {
      setIsLoading(true);  // immediate feedback on tap
      setSaveStatus('idle'); setSaveError(null); setExpanded(false);
      mediaReset(); clearTranscript();
      try {
        await vizStart(); await mediaStart(); startListening();
      } catch {
        setIsLoading(false);
      }
    }
  }, [isListening, startListening, stopListening, vizStart, vizStop, mediaStart, mediaStop, mediaReset, clearTranscript]);

  const handleSave = async () => {
    if (!transcriptToUse.trim()) return;
    setSaving(true); setSaveError(null);
    let audio_path: string | undefined;
    if (inputMode === 'voice' && audioBlob) {
      setSaveStatus('uploading');
      try { const up = await uploadAudio(audioBlob); audio_path = up.audio_path; } catch { /* non-fatal */ }
    }
    setSaveStatus('saving');
    try {
      await saveRecording({
        type: selectedPrompt ? 'prompted' : 'freeform',
        prompt_id: selectedPrompt ? selectedPrompt.id : undefined,
        transcript: transcriptToUse,
        duration_secs: inputMode === 'voice' ? duration : 0,
        word_count: wc(transcriptToUse),
        audio_path
      });
      setSaveStatus('done');
      setTimeout(() => {
        if (inputMode === 'voice') {
          clearTranscript();
          mediaReset();
        } else {
          setTypedText('');
          setHasSubmittedText(false);
        }
        setSaveStatus('idle');
        setExpanded(false);
        setSelectedPrompt(null);
      }, 1800);
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Save failed');
      setSaveStatus('idle');
    } finally { setSaving(false); }
  };

  const hasTranscript = inputMode === 'voice'
    ? !isListening && !!(finalTranscript || interimText)
    : hasSubmittedText;
  const isDone        = saveStatus === 'done';



  return (
    <div className="home-root">
      <div className="orb orb-1" /><div className="orb orb-2" /><div className="orb orb-3" />

      {/* Aesthetic Top Navigation Bar */}
      <header className="app-header-bar">
        <div className="app-header-left" style={{ gap: 8 }}>
          {viewMode !== 'stream' ? (
            <Tooltip title="Back to Stream" placement="bottom">
              <Button
                type="text"
                shape="circle"
                icon={<ArrowLeftOutlined style={{ fontSize: 18, color: 'var(--text)' }} />}
                onClick={() => setViewMode('stream')}
                className="action-icon-btn"
              />
            </Tooltip>
          ) : (
            <>
              <Tooltip title="View Archives" placement="bottom">
                <Button
                  type="text"
                  shape="circle"
                  icon={<HistoryOutlined style={{ fontSize: 18, color: 'var(--text)' }} />}
                  onClick={() => setViewMode('archive')}
                  className="action-icon-btn"
                />
              </Tooltip>
              {prompts.length > 0 && (
                <Tooltip title="PM Prompts" placement="bottom">
                  <Button
                    type="text"
                    shape="circle"
                    icon={<BulbOutlined style={{ fontSize: 18, color: selectedPrompt ? 'var(--violet)' : 'var(--text)' }} />}
                    onClick={() => { fetchPrompts(); setViewMode('prompts'); }}
                    className="action-icon-btn"
                    style={selectedPrompt ? { boxShadow: '0 0 8px var(--violet-glow)' } : {}}
                  />
                </Tooltip>
              )}
            </>
          )}
          <span className="brand-logo">Mindstream</span>
        </div>
        
        <div className="app-header-center">
          {viewMode === 'stream' ? (
            /* Stream sub-toggle (Voice / Text) */
            <Segmented
              value={inputMode}
              onChange={(val) => {
                clearTranscript();
                mediaReset();
                setTypedText('');
                setHasSubmittedText(false);
                setSaveStatus('idle');
                setExpanded(false);
                setInputMode(val as 'voice' | 'text');
              }}
              options={[
                { value: 'voice', icon: <AudioOutlined style={{ fontSize: 16 }} /> },
                { value: 'text', icon: <EditOutlined style={{ fontSize: 16 }} /> }
              ]}
              className="input-mode-segmented"
              size="middle"
            />
          ) : null}
        </div>
        
        <div className="app-header-right">
          <Tooltip title={themeMode === 'dark' ? 'Light Mode' : 'Dark Mode'} placement="bottom">
            <Button
              type="text"
              shape="circle"
              icon={themeMode === 'dark' ? <SunOutlined style={{ fontSize: 17, color: 'var(--text)' }} /> : <MoonOutlined style={{ fontSize: 17, color: 'var(--text)' }} />}
              onClick={toggleTheme}
              className="action-icon-btn"
            />
          </Tooltip>
          
          <Tooltip title="Log out" placement="bottom">
            <Button
              type="text"
              shape="circle"
              icon={<LogoutOutlined style={{ fontSize: 17, color: 'var(--text)' }} />}
              onClick={logout}
              className="action-icon-btn"
            />
          </Tooltip>
        </div>
      </header>

      {/* ── MAIN WORKSPACE ── */}
      <main className="home-center">

        {viewMode === 'prompts' ? (
          /* Prompts Selection Page */
          <div className="archive-container">
            <div className="archive-header">
              <div className="archive-title-area">
                <h2 className="archive-headline">Prompts</h2>
                <span className="archive-count">
                  {promptsLoading ? 'Loading…' : `${prompts.length} active prompt${prompts.length !== 1 ? 's' : ''} from PM`}
                </span>
              </div>
            </div>
            {promptsLoading ? (
              <div style={{ textAlign: 'center', padding: '40px 0' }}>
                <span className="orb-status">Loading prompts…</span>
              </div>
            ) : prompts.length === 0 ? (
              <div className="archive-no-data">
                No active prompts right now.
              </div>
            ) : (
              <div className="entries-list">
                {prompts.map(p => {
                  const isSelected = selectedPrompt?.id === p.id;
                  return (
                    <div
                      key={p.id}
                      className={`prompt-item${isSelected ? ' selected' : ''}`}
                      onClick={() => {
                        setSelectedPrompt(isSelected ? null : p);
                        setViewMode('stream');
                      }}
                    >
                      <div className="pi-left">
                        <span className="pi-dot" />
                        <div className="pi-body">
                          <span className="pi-title">{p.title}</span>
                          {p.description && <span className="pi-desc">{p.description}</span>}
                        </div>
                      </div>
                      {isSelected && (
                        <CheckOutlined style={{ fontSize: 14, color: 'var(--violet)', flexShrink: 0 }} />
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        ) : viewMode === 'archive' ? (
          /* Archive View / History Workspace */
          <div className="archive-container">
            <div className="archive-header">
              <div className="archive-title-area">
                <h2 className="archive-headline">Your Archives</h2>
                <span className="archive-count">
                  {recordingsLoading ? 'Loading stream entries...' : `${recordings.length} total entries recorded`}
                </span>
              </div>
            </div>

            {recordingsLoading ? (
              <div style={{ textAlign: 'center', padding: '60px 0' }}>
                <span className="orb-status">Retrieving archives…</span>
              </div>
            ) : (
              /* Integrated Calendar + List Feed */
              <div className="calendar-view-wrap">
                <Card className="calendar-card" bordered={false}>
                  <div className="calendar-top">
                    <Button 
                      type="text" 
                      shape="circle" 
                      icon={<LeftOutlined />} 
                      onClick={handlePrevMonth}
                      className="calendar-nav-btn"
                    />
                    <span className="calendar-month-name">
                      {currentDate.toLocaleString('default', { month: 'long', year: 'numeric' })}
                    </span>
                    <Button 
                      type="text" 
                      shape="circle" 
                      icon={<RightOutlined />} 
                      onClick={handleNextMonth}
                      className="calendar-nav-btn"
                    />
                  </div>

                  <div className="calendar-grid">
                    {/* Weekday headers */}
                    {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map(wd => (
                      <div key={wd} className="calendar-weekday">{wd}</div>
                    ))}

                    {/* Empty weekday offsets */}
                    {Array.from({ length: startOffset }).map((_, i) => (
                      <div key={`empty-${i}`} className="calendar-cell empty-cell" />
                    ))}

                    {/* Active days in month */}
                    {Array.from({ length: numDays }).map((_, i) => {
                      const dayNum = i + 1;
                      const dayRecs = getRecordingsForDay(dayNum);
                      const isSelected = selectedDate &&
                        selectedDate.getDate() === dayNum &&
                        selectedDate.getMonth() === month &&
                        selectedDate.getFullYear() === year;
                      
                      return (
                        <div
                          key={`day-${dayNum}`}
                          className={`calendar-cell${isSelected ? ' selected-day' : ''}${dayRecs.length > 0 ? ' has-recordings' : ''}`}
                          onClick={() => {
                            if (isSelected) {
                              setSelectedDate(null);
                            } else {
                              setSelectedDate(new Date(year, month, dayNum));
                            }
                          }}
                        >
                          {dayNum}
                        </div>
                      );
                    })}
                  </div>
                </Card>

                {/* Unified Past Entries Feed */}
                <div className="day-entries-container">
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
                    <h3 className="day-entries-title" style={{ margin: 0 }}>
                      {selectedDate 
                        ? `Entries on ${selectedDate.toLocaleDateString('default', { month: 'short', day: 'numeric', year: 'numeric' })}`
                        : 'All Past Entries'
                      }
                    </h3>
                    {selectedDate && (
                      <Button
                        type="link"
                        size="small"
                        onClick={() => setSelectedDate(null)}
                        style={{ padding: 0, height: 'auto', fontSize: 12, color: 'var(--violet)', fontWeight: 600 }}
                      >
                        Show all
                      </Button>
                    )}
                  </div>
                  
                  {(() => {
                    const filteredRecs = selectedDate
                      ? recordings.filter(r => {
                          const rDate = new Date(r.created_at);
                          return rDate.getFullYear() === selectedDate.getFullYear() &&
                                 rDate.getMonth() === selectedDate.getMonth() &&
                                 rDate.getDate() === selectedDate.getDate();
                        })
                      : recordings;

                    if (filteredRecs.length === 0) {
                      return (
                        <div className="archive-no-data">
                          {selectedDate 
                            ? 'No entries recorded on this day.'
                            : 'Your mindstream is empty. Speak or write in Stream mode to begin!'
                          }
                        </div>
                      );
                    }

                    return (
                      <div className="entries-list">
                        {filteredRecs.map(rec => (
                          <ArchiveRecordingCard key={rec.id} recording={rec} />
                        ))}
                      </div>
                    );
                  })()}
                </div>
              </div>
            )}
          </div>
        ) : (
          /* Stream Mode Capture */
          <>
            {inputMode === 'text' ? (
              /* Text Mode Frosted Writing Card */
              !hasSubmittedText ? (
                <div className="text-mode-wrapper">
                  <Card className="text-writing-card" bordered={false}>
                    <textarea
                      className="text-writing-textarea"
                      placeholder="Write your mindstream down..."
                      value={typedText}
                      onChange={(e) => setTypedText(e.target.value)}
                      autoFocus
                    />
                    <div className="text-card-footer">
                      <span className="text-word-counter">
                        {wc(typedText)} words
                      </span>
                      <Button
                        type="primary"
                        disabled={!typedText.trim()}
                        onClick={() => setHasSubmittedText(true)}
                        className="text-process-btn"
                      >
                        Done Writing
                      </Button>
                    </div>
                  </Card>
                </div>
              ) : null
            ) : (
              /* Voice Mode Orb Trigger */
              <button
                className={`orb-trigger${isListening ? ' recording' : ''}${isLoading ? ' loading' : ''}`}
                onClick={handleToggle}
                disabled={isLoading}
                aria-label={isListening ? 'Stop recording' : isLoading ? 'Starting session' : 'Start recording'}
              >
                <MindstreamAura analyserRef={analyserRef} isActive={isListening} isLoading={isLoading} />
                
                <div className="orb-overlay">
                  {isLoading ? (
                    <span className="orb-status">Starting…</span>
                  ) : isListening ? (
                    <span className="orb-stop-text">Tap to stop</span>
                  ) : !hasTranscript ? (
                    <span className="orb-status-hint">Tap to speak</span>
                  ) : null}
                </div>
              </button>
            )}

            {/* ── SUBTITLE / SUMMARY ZONE ── */}
            <div className="subtitle-zone">
              {/* Minimal selected prompt context chip — only when idle */}
              {selectedPrompt && !isListening && !hasTranscript && (
                <div className="selected-prompt-chip">
                  <span className="spc-dot" />
                  <span className="spc-text">{selectedPrompt.title}</span>
                  <button
                    className="spc-clear"
                    onClick={() => setSelectedPrompt(null)}
                    aria-label="Clear prompt"
                  >×</button>
                </div>
              )}

              {inputMode === 'voice' && isListening && (
                <p className="live-caption">
                  {(finalTranscript || interimText)
                    ? <CaptionWords text={(finalTranscript + (interimText ? ' ' + interimText : '')).trim()} />
                    : null
                  }
                </p>
              )}
              {hasTranscript && (
                <Card className="stopped-summary-card" bordered={false}>
                  {/* Stats chips */}
                  <div className="stat-chips">
                    <span className="stat-chip">{wc(transcriptToUse)}w</span>
                    {inputMode === 'voice' && <span className="stat-chip">{fmtTime(duration)}</span>}
                    {inputMode === 'voice' && audioBlob && <span className="stat-chip stat-chip-green">audio</span>}
                  </div>

                  {/* Collapsed / expanded transcript */}
                  <Button
                    type="link"
                    className="transcript-toggle-btn"
                    onClick={() => setExpanded(e => !e)}
                    icon={expanded ? <EyeInvisibleOutlined /> : <EyeOutlined />}
                  >
                    {expanded ? 'Hide text' : 'View text'}
                  </Button>

                  {expanded && (
                    <div className="transcript-expanded">{transcriptToUse}</div>
                  )}

                  {/* Save / Discard */}
                  {!isDone && (
                    <div className="action-row">
                      <Button
                        onClick={() => {
                          if (inputMode === 'voice') {
                            clearTranscript();
                            mediaReset();
                          } else {
                            setTypedText('');
                            setHasSubmittedText(false);
                          }
                          setSaveStatus('idle');
                          setExpanded(false);
                        }}
                        disabled={saving}
                        icon={<DeleteOutlined />}
                        className="discard-btn"
                      >
                        Discard
                      </Button>
                      <Button
                        type="primary"
                        onClick={handleSave}
                        loading={saving}
                        icon={<SaveOutlined />}
                        className="save-btn"
                      >
                        {saveStatus === 'uploading' ? 'Uploading…' : saveStatus === 'saving' ? 'Saving…' : 'Save'}
                      </Button>
                    </div>
                  )}
                  {isDone && <p className="save-done">Saved</p>}
                  {saveError && <p className="save-error">{saveError}</p>}
                </Card>
              )}
            </div>
          </>
        )}
      </main>
    </div>
  );
}
