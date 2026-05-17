import { useState, useEffect, useCallback, useRef } from 'react';
import { saveRecording, uploadAudio } from '../services/api';
import { useSpeech } from '../hooks/useSpeech';
import { useAudioVisualizer } from '../hooks/useAudioVisualizer';
import { useMediaRecorder } from '../hooks/useMediaRecorder';
function Waveform({ analyserRef, isActive }: { analyserRef: React.RefObject<AnalyserNode | null>; isActive: boolean }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rafRef    = useRef<number>(0);
  const frameRef  = useRef(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const dpr = window.devicePixelRatio || 1;
    const resize = () => { canvas.width = canvas.offsetWidth * dpr; canvas.height = canvas.offsetHeight * dpr; };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);

    const draw = () => {
      frameRef.current++;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      const W = canvas.width, H = canvas.height;
      ctx.clearRect(0, 0, W, H);

      const N = 60, gap = 2 * dpr, barW = (W - gap * (N - 1)) / N;
      const half = Math.ceil(N / 2);

      let heights: number[];

      if (isActive && analyserRef.current) {
        const data = new Uint8Array(analyserRef.current.frequencyBinCount);
        analyserRef.current.getByteFrequencyData(data);
        // Sample the first `half` bins (bass → mid), then mirror so bass is centered
        const step = Math.max(1, Math.floor((data.length * 0.6) / half));
        const half_h = Array.from({ length: half }, (_, i) =>
          Math.max(0.03, data[i * step] / 255)
        );
        // Left side = reversed (so bar 0 has high-freq, bar N/2 has bass)
        // Right side = normal (bar N/2 has bass, bar N has high-freq)
        heights = [...half_h].reverse().concat(half_h.slice(0, N - half));
      } else {
        const t = frameRef.current * 0.035;
        heights = Array.from({ length: N }, (_, i) =>
          0.03 + 0.05 * Math.abs(Math.sin(t + i * 0.28)) * Math.sin(t * 0.5 + i * 0.15)
        );
      }

      // Bell envelope: tallest at center, tapers to ~15% at edges
      heights = heights.map((h, i) => {
        const envelope = 0.15 + 0.85 * Math.sin((i / (N - 1)) * Math.PI);
        return h * envelope;
      });

      heights.forEach((h, i) => {
        const x     = i * (barW + gap);
        const barH  = Math.max(2 * dpr, h * H);
        const y     = (H - barH) / 2;
        // Active: teal (172°) brightens with amplitude
        // Idle:   warm sand (34°) very subtle
        const hue   = isActive ? 172 : 34;
        const sat   = isActive ? 38 : 22;
        const lit   = isActive ? 55 + h * 20 : 58;
        const alpha = isActive ? 0.12 + h * 0.88 : 0.08 + h * 0.32;
        ctx.fillStyle = `hsla(${hue},${sat}%,${lit}%,${alpha})`;
        ctx.beginPath(); ctx.roundRect(x, y, barW, barH, 2 * dpr); ctx.fill();
      });

      rafRef.current = requestAnimationFrame(draw);
    };

    rafRef.current = requestAnimationFrame(draw);
    return () => { cancelAnimationFrame(rafRef.current); ro.disconnect(); };
  }, [isActive, analyserRef]);

  return <canvas ref={canvasRef} className="hero-waveform" />;
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

/* ── AnalystHome ─────────────────────────────────────────────── */
export default function AnalystHome() {
  const { isListening, finalTranscript, interimText, entries, error: speechError,
          startListening, stopListening, clearTranscript } = useSpeech();
  const { analyserRef, start: vizStart, stop: vizStop } = useAudioVisualizer();
  const { audioBlob, start: mediaStart, stop: mediaStop, reset: mediaReset } = useMediaRecorder();

  const [isLoading,    setIsLoading]   = useState(false);
  const [duration,     setDuration]    = useState(0);
  const [saving,       setSaving]      = useState(false);
  const [saveStatus,   setSaveStatus]  = useState<'idle'|'uploading'|'saving'|'done'>('idle');
  const [saveError,    setSaveError]   = useState<string | null>(null);
  const [expanded,     setExpanded]    = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

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
    if (!finalTranscript.trim()) return;
    setSaving(true); setSaveError(null);
    let audio_path: string | undefined;
    if (audioBlob) {
      setSaveStatus('uploading');
      try { const up = await uploadAudio(audioBlob); audio_path = up.audio_path; } catch { /* non-fatal */ }
    }
    setSaveStatus('saving');
    try {
      await saveRecording({ type: 'freeform', transcript: finalTranscript,
        duration_secs: duration, word_count: wc(finalTranscript), audio_path });
      setSaveStatus('done');
      setTimeout(() => { clearTranscript(); mediaReset(); setSaveStatus('idle'); setExpanded(false); }, 1800);
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Save failed');
      setSaveStatus('idle');
    } finally { setSaving(false); }
  };

  const hasTranscript = !!(finalTranscript || interimText);
  const isDone        = saveStatus === 'done';



  return (
    <div className="home-root">
      <div className="orb orb-1" /><div className="orb orb-2" /><div className="orb orb-3" />

      {/* ── CENTER STAGE ── */}
      <main className="home-center">

        {/* Waveform — always the hero */}
        <div className="hero-wave-wrap">
          <Waveform analyserRef={analyserRef} isActive={isListening} />
        </div>

        {/* ── SUBTITLE ZONE ── */}
        <div className="subtitle-zone">
          {isListening && (
            <p className="live-caption">
              {(finalTranscript || interimText)
                ? <CaptionWords text={(finalTranscript + (interimText ? ' ' + interimText : '')).trim()} />
                : null
              }
            </p>
          )}
          {!isListening && hasTranscript && (
            <div className="stopped-summary">
              {/* Stats chips */}
              <div className="stat-chips">
                <span className="stat-chip">{wc(finalTranscript)}w</span>
                <span className="stat-chip">{fmtTime(duration)}</span>
                {audioBlob && <span className="stat-chip stat-chip-green">🎵 audio</span>}
              </div>

              {/* Collapsed / expanded transcript */}
              <button className="transcript-toggle" onClick={() => setExpanded(e => !e)}>
                {expanded ? 'Hide transcript ↑' : 'View transcript ↓'}
              </button>

              {expanded && (
                <div className="transcript-expanded">{finalTranscript}</div>
              )}

              {/* Save / Discard */}
              {!isDone && (
                <div className="action-row">
                  <button className="btn" onClick={() => { clearTranscript(); mediaReset(); setSaveStatus('idle'); setExpanded(false); }} disabled={saving}>
                    Discard
                  </button>
                  <button className="btn btn-copy" onClick={handleSave} disabled={saving}>
                    {saveStatus === 'uploading' ? 'Uploading…' : saveStatus === 'saving' ? 'Saving…' : 'Save'}
                  </button>
                </div>
              )}
              {isDone && <p className="save-done">✓ Saved</p>}
              {saveError && <p className="save-error">{saveError}</p>}
            </div>
          )}
        </div>
      </main>

      {/* ── FLOATING BOTTOM BUTTON ── */}
      <div className="home-fab-wrap">
        {isListening && (
          <span className="fab-timer">{fmtTime(duration)}</span>
        )}
        <button
          id="home-record-btn"
          className={`home-fab${isListening ? ' recording' : ''}${isLoading ? ' loading' : ''}`}
          onClick={handleToggle}
          disabled={isLoading}
          aria-label={isListening ? 'Stop' : isLoading ? 'Starting…' : 'Record'}
        >
          {isLoading
            ? <svg className="fab-spinner" width="24" height="24" viewBox="0 0 24 24" fill="none">
                <circle cx="12" cy="12" r="9" stroke="rgba(255,255,255,0.25)" strokeWidth="2.5"/>
                <path d="M12 3a9 9 0 0 1 9 9" stroke="white" strokeWidth="2.5" strokeLinecap="round"/>
              </svg>
            : isListening
              ? <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><rect x="5" y="5" width="14" height="14" rx="3" fill="white"/></svg>
              : <svg width="26" height="26" viewBox="0 0 24 24" fill="none">
                  <rect x="9" y="2" width="6" height="12" rx="3" fill="white"/>
                  <path d="M5 10a7 7 0 0 0 14 0" stroke="white" strokeWidth="2.2" strokeLinecap="round"/>
                  <line x1="12" y1="17" x2="12" y2="21" stroke="white" strokeWidth="2.2" strokeLinecap="round"/>
                  <line x1="8" y1="21" x2="16" y2="21" stroke="white" strokeWidth="2.2" strokeLinecap="round"/>
                </svg>
          }
          {isListening && (
            <>
              <div className="fab-ring fab-ring-1" />
              <div className="fab-ring fab-ring-2" />
            </>
          )}
        </button>
        {!isListening && !isLoading && !hasTranscript && (
          <span className="fab-label">Tap to record</span>
        )}
        {isLoading && (
          <span className="fab-label" style={{ color: 'var(--violet)', opacity: 0.8 }}>Starting…</span>
        )}
      </div>
    </div>
  );
}
