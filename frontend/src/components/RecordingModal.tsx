import { useState, useEffect, useRef, useCallback } from 'react';
import { useSpeech } from '../hooks/useSpeech';
import { useAudioVisualizer } from '../hooks/useAudioVisualizer';
import { useMediaRecorder } from '../hooks/useMediaRecorder';
import { saveRecording, uploadAudio } from '../services/api';
import type { Prompt } from '../services/api';

/* ── Waveform (inline) ───────────────────────────────────────── */
function Waveform({ analyserRef, isActive }: { analyserRef: React.RefObject<AnalyserNode | null>; isActive: boolean }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const rafRef = useRef<number>(0);
  const frameRef = useRef(0);

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
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      const W = canvas.width, H = canvas.height;
      ctx.clearRect(0, 0, W, H);
      const N = 40, gap = 3 * dpr, barW = (W - gap * (N - 1)) / N;
      let heights: number[];
      if (isActive && analyserRef.current) {
        const data = new Uint8Array(analyserRef.current.frequencyBinCount);
        analyserRef.current.getByteFrequencyData(data);
        const step = Math.max(1, Math.floor(data.length / N));
        heights = Array.from({ length: N }, (_, i) => Math.max(0.03, data[i * step] / 255));
      } else {
        const t = frameRef.current * 0.045;
        heights = Array.from({ length: N }, (_, i) => 0.04 + 0.04 * Math.sin(t + i * 0.38));
      }
      heights.forEach((h, i) => {
        const x = i * (barW + gap), barH = Math.max(3 * dpr, h * H), y = (H - barH) / 2;
        ctx.fillStyle = `hsla(${isActive ? 260 - h * 80 : 250},${isActive ? 75 : 50}%,65%,${isActive ? 0.25 + h * 0.75 : 0.25})`;
        ctx.beginPath(); ctx.roundRect(x, y, barW, barH, 2 * dpr); ctx.fill();
      });
      rafRef.current = requestAnimationFrame(draw);
    };
    rafRef.current = requestAnimationFrame(draw);
    return () => { cancelAnimationFrame(rafRef.current); ro.disconnect(); };
  }, [isActive, analyserRef]);

  return <canvas ref={canvasRef} className="waveform-canvas" />;
}

/* ── Props ───────────────────────────────────────────────────── */
interface Props {
  recordingType: 'freeform' | 'prompted';
  prompt?: Prompt;
  onClose: () => void;
  onSaved?: () => void;
}

function wordCount(t: string) { return t.trim() ? t.trim().split(/\s+/).length : 0; }
function fmt(s: number) { return `${Math.floor(s / 60).toString().padStart(2, '0')}:${(s % 60).toString().padStart(2, '0')}`; }

/* ── RecordingModal ──────────────────────────────────────────── */
export default function RecordingModal({ recordingType, prompt, onClose, onSaved }: Props) {
  const { isListening, finalTranscript, interimText, entries, error, startListening, stopListening, clearTranscript } = useSpeech();
  const { analyserRef, start: vizStart, stop: vizStop } = useAudioVisualizer();
  const { audioBlob, start: mediaStart, stop: mediaStop, reset: mediaReset } = useMediaRecorder();

  const [duration, setDuration] = useState(0);
  const [saving, setSaving] = useState(false);
  const [saveStatus, setSaveStatus] = useState<'idle' | 'uploading' | 'saving' | 'done'>('idle');
  const [saveError, setSaveError] = useState<string | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const transcriptRef = useRef<HTMLDivElement>(null);

  /* Auto-start recording when modal opens */
  useEffect(() => {
    const autoStart = async () => {
      mediaReset();
      await vizStart();
      await mediaStart();
      startListening();
    };
    autoStart();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);


  useEffect(() => {
    if (transcriptRef.current) transcriptRef.current.scrollTop = transcriptRef.current.scrollHeight;
  }, [finalTranscript, interimText]);

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
      stopListening();
      vizStop();
      mediaStop(); // finalize audio blob
    } else {
      mediaReset();
      await vizStart();
      await mediaStart(); // start capturing audio
      startListening();   // start Azure transcription
    }
  }, [isListening, startListening, stopListening, vizStart, vizStop, mediaStart, mediaStop, mediaReset]);

  const handleSave = async () => {
    if (!finalTranscript.trim()) return;
    setSaving(true);
    setSaveError(null);

    let audio_path: string | undefined;

    // 1. Upload audio blob if we captured one
    if (audioBlob) {
      setSaveStatus('uploading');
      try {
        const uploaded = await uploadAudio(audioBlob);
        audio_path = uploaded.audio_path;
      } catch (e) {
        console.warn('[RecordingModal] audio upload failed, saving transcript only:', e);
        // Don't block save — transcript is the core value
      }
    }

    // 2. Save recording metadata + transcript
    setSaveStatus('saving');
    try {
      await saveRecording({
        type: recordingType,
        prompt_id: prompt?.id,
        transcript: finalTranscript,
        duration_secs: duration,
        word_count: wordCount(finalTranscript),
        audio_path,
      });
      setSaveStatus('done');
      onSaved?.();
      setTimeout(onClose, 1200);
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Save failed');
      setSaveStatus('idle');
    } finally {
      setSaving(false);
    }
  };

  const saveLabel = () => {
    if (saveStatus === 'uploading') return 'Uploading audio…';
    if (saveStatus === 'saving') return 'Saving…';
    if (saveStatus === 'done') return '✓ Saved!';
    return 'Save Recording';
  };

  return (
    <div className="modal-overlay" onClick={(e) => { if (e.target === e.currentTarget && !isListening) onClose(); }}>
      <div className="modal-panel">
        {/* Header */}
        <div className="modal-header">
          <div>
            <span className="modal-type-badge">{recordingType === 'freeform' ? 'Freeform' : 'Prompted'}</span>
            {prompt && <p className="modal-prompt-title">{prompt.title}</p>}
          </div>
          <button className="modal-close-btn" onClick={onClose} disabled={isListening} aria-label="Close">✕</button>
        </div>

        {/* Prompt description */}
        {prompt?.description && (
          <p className="modal-prompt-desc">{prompt.description}</p>
        )}

        {/* Error */}
        {(error || saveError) && (
          <div className="error-banner" role="alert" style={{ margin: '0 0 16px' }}>
            {error || saveError}
          </div>
        )}

        {/* Mic + waveform */}
        <div className="modal-record-zone">
          <div className="mic-wrap">
            {isListening && <><div className="ring"/><div className="ring"/><div className="ring"/></>}
            <button
              className={`mic-btn${isListening ? ' recording' : ''}`}
              onClick={handleToggle}
              aria-label={isListening ? 'Stop' : 'Start recording'}
            >
              {isListening
                ? <svg width="32" height="32" viewBox="0 0 24 24" fill="none"><rect x="5" y="5" width="14" height="14" rx="2.5" fill="white"/></svg>
                : <svg width="40" height="40" viewBox="0 0 24 24" fill="none"><rect x="9" y="2" width="6" height="12" rx="3" fill="white"/><path d="M5 10a7 7 0 0 0 14 0" stroke="white" strokeWidth="2" strokeLinecap="round"/><line x1="12" y1="17" x2="12" y2="21" stroke="white" strokeWidth="2" strokeLinecap="round"/><line x1="8" y1="21" x2="16" y2="21" stroke="white" strokeWidth="2" strokeLinecap="round"/></svg>
              }
            </button>
          </div>

          {isListening
            ? <div className="record-status-row"><div className="live-dot"/><span style={{color:'var(--text-2)',fontSize:13}}>Recording</span><span className="duration-badge">{fmt(duration)}</span></div>
            : finalTranscript
              ? <div style={{display:'flex',alignItems:'center',gap:8}}>
                  <span style={{fontSize:13,color:'var(--text-3)'}}>Stopped — {fmt(duration)}</span>
                  {audioBlob && <span style={{fontSize:11,color:'var(--success)',background:'rgba(74,222,128,0.1)',border:'1px solid rgba(74,222,128,0.2)',borderRadius:99,padding:'2px 8px'}}>🎵 Audio ready</span>}
                </div>
              : <p className="idle-hint">Starting…</p>

          }

          <Waveform analyserRef={analyserRef} isActive={isListening} />
        </div>

        {/* Transcript */}
        <div className="modal-transcript" ref={transcriptRef}>
          {!finalTranscript && !interimText
            ? <div className="tc-empty"><div className="tc-empty-icon">💬</div>{isListening ? 'Listening…' : 'Your transcript will appear here'}</div>
            : <p><span className="t-final">{finalTranscript}</span>{interimText && <><span> </span><span className="t-interim">{interimText}</span></>}{isListening && <span className="t-cursor"/>}</p>
          }
        </div>

        {/* Stats + actions */}
        <div className="modal-footer">
          <div className="modal-stats">
            <span>{wordCount(finalTranscript)} <span style={{color:'var(--text-3)'}}>words</span></span>
            <span>{entries.length} <span style={{color:'var(--text-3)'}}>sentences</span></span>
          </div>
          <div style={{display:'flex',gap:8}}>
            <button className="btn" onClick={() => { clearTranscript(); mediaReset(); }} disabled={!finalTranscript || isListening}>Clear</button>
            <button
              className="btn btn-copy"
              onClick={handleSave}
              disabled={!finalTranscript || isListening || saving || saveStatus === 'done'}
            >
              {saveLabel()}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
