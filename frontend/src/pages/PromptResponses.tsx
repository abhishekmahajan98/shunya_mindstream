import { useState, useEffect, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import ReactMarkdown from 'react-markdown';
import { getPromptResponses, type PromptResponsesResult } from '../services/api';

function fmt(d: string) {
  return new Date(d).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: true });
}

export default function PromptResponses() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [data, setData] = useState<PromptResponsesResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!id) return;
    setLoading(true); setError(null);
    try { setData(await getPromptResponses(id)); }
    catch (e) { setError(e instanceof Error ? e.message : 'Failed to load'); }
    finally { setLoading(false); }
  }, [id]);

  useEffect(() => { load(); }, [load]);

  if (loading) return (
    <div className="auth-loading"><div className="auth-loading-spinner"/></div>
  );
  if (error) return (
    <div className="auth-page"><div className="auth-card"><div className="error-banner">{error}</div><button className="btn" onClick={() => navigate('/pm')}>Back</button></div></div>
  );
  if (!data) return null;

  const { prompt, recordings, summary } = data;

  return (
    <div className="app">
      <div className="orb orb-1"/><div className="orb orb-2"/>

      <header className="app-header">
        <div className="header-brand">
          <button className="btn" onClick={() => navigate('/pm')} style={{fontSize:12,marginRight:8}}>← Back</button>
          <div className="header-logo">🌊</div>
          <span className="header-name">Prompt Responses</span>
        </div>
        <span className={`pc-status ${prompt.status}`} style={{textTransform:'capitalize'}}>{prompt.status}</span>
      </header>

      <main className="app-main">
        {/* Prompt detail */}
        <div className="prompt-detail-card">
          <h1 className="prompt-detail-title">{prompt.title}</h1>
          {prompt.description && <p className="prompt-detail-desc">{prompt.description}</p>}
          <div style={{display:'flex',gap:16,marginTop:12,flexWrap:'wrap'}}>
            <span className="ri-meta">{recordings.length} response{recordings.length !== 1 ? 's' : ''}</span>
            {prompt.deadline && <span className="ri-meta">Deadline: {fmt(prompt.deadline)}</span>}
          </div>
        </div>

        {/* AI Summary */}
        {summary && (
          <div className="summary-card">
            <div className="summary-header">
              <span className="summary-badge">✦ Gemini Synthesis</span>
              <button className="btn" style={{fontSize:11}} onClick={load}>Refresh</button>
            </div>
            <div className="summary-body markdown-body">
              <ReactMarkdown>{summary}</ReactMarkdown>
            </div>
          </div>
        )}

        {/* Analyst responses */}
        <section className="dash-section">
          <div className="dash-section-header" style={{marginBottom:16}}>
            <h2 className="dash-section-title">Analyst Responses</h2>
            <span className="log-count">{recordings.length}</span>
          </div>

          {recordings.length === 0 ? (
            <div className="empty-state">No analyst responses yet.</div>
          ) : (
            <div className="recordings-list">
              {recordings.map(r => (
                <div key={r.id} className="recording-item">
                  <div className="ri-left">
                    <div style={{display:'flex',alignItems:'center',gap:8,marginBottom:6}}>
                      <div className="analyst-avatar">{r.profiles?.full_name?.[0] ?? '?'}</div>
                      <strong style={{fontSize:14,color:'var(--text)'}}>{r.profiles?.full_name ?? 'Unknown'}</strong>
                    </div>
                    <p className="ri-transcript">{r.transcript}</p>
                    <span className="ri-meta">{fmt(r.created_at)}{r.duration_secs ? ` · ${r.duration_secs}s` : ''}{r.word_count ? ` · ${r.word_count}w` : ''}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      </main>
    </div>
  );
}
