import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import ReactMarkdown from 'react-markdown';
import { useAuth } from '../contexts/AuthContext';
import { listPrompts, createPrompt, updatePromptStatus, ragQuery, type Prompt, type RAGResult } from '../services/api';

function fmt(d: string) {
  return new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

/* ── Create Prompt Modal ─────────────────────────────────────── */
function CreatePromptModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const [form, setForm] = useState({ title: '', description: '', deadline: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handle = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true); setError(null);
    try {
      await createPrompt({ title: form.title, description: form.description || undefined, deadline: form.deadline || undefined });
      onCreated(); onClose();
    } catch (err) { setError(err instanceof Error ? err.message : 'Failed'); }
    finally { setLoading(false); }
  };

  return (
    <div className="modal-overlay" onClick={e => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="modal-panel" style={{maxWidth:480}}>
        <div className="modal-header">
          <h3 style={{fontSize:16,fontWeight:600}}>New Prompt</h3>
          <button className="modal-close-btn" onClick={onClose}>✕</button>
        </div>
        {error && <div className="error-banner">{error}</div>}
        <form onSubmit={handle} className="auth-form" style={{gap:16}}>
          <div className="field-group">
            <label className="field-label">Topic / Question</label>
            <input className="field-input" placeholder="e.g. What's your view on energy sector rotation?" value={form.title} onChange={e => setForm(f=>({...f,title:e.target.value}))} required/>
          </div>
          <div className="field-group">
            <label className="field-label">Context (optional)</label>
            <textarea className="field-input" rows={3} placeholder="Additional context for analysts…" value={form.description} onChange={e => setForm(f=>({...f,description:e.target.value}))} style={{resize:'vertical'}}/>
          </div>
          <div className="field-group">
            <label className="field-label">Deadline (optional)</label>
            <input className="field-input" type="datetime-local" value={form.deadline} onChange={e => setForm(f=>({...f,deadline:e.target.value}))}/>
          </div>
          <div style={{display:'flex',gap:8,justifyContent:'flex-end'}}>
            <button type="button" className="btn" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-copy" disabled={loading}>{loading ? 'Creating…' : 'Create Prompt'}</button>
          </div>
        </form>
      </div>
    </div>
  );
}

/* ── RAG Panel ───────────────────────────────────────────────── */
function RAGPanel() {
  const [query, setQuery] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<RAGResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const run = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;
    setLoading(true); setResult(null); setError(null);
    try {
      const r = await ragQuery({ query, date_from: dateFrom || undefined, date_to: dateTo || undefined });
      setResult(r);
    } catch (err) { setError(err instanceof Error ? err.message : 'Query failed'); }
    finally { setLoading(false); }
  };

  return (
    <div className="rag-panel">
      <form onSubmit={run}>
        <div className="rag-input-row">
          <input
            className="field-input rag-query-input"
            placeholder="Ask anything about analyst views…"
            value={query}
            onChange={e => setQuery(e.target.value)}
            required
          />
          <button type="submit" className="btn btn-copy" disabled={loading} style={{whiteSpace:'nowrap'}}>
            {loading ? 'Searching…' : '🔍 Ask'}
          </button>
        </div>
        <div className="rag-filters">
          <div className="field-group" style={{flex:1}}>
            <label className="field-label">From</label>
            <input type="date" className="field-input" value={dateFrom} onChange={e => setDateFrom(e.target.value)}/>
          </div>
          <div className="field-group" style={{flex:1}}>
            <label className="field-label">To</label>
            <input type="date" className="field-input" value={dateTo} onChange={e => setDateTo(e.target.value)}/>
          </div>
        </div>
      </form>

      {error && <div className="error-banner" style={{marginTop:16}}>{error}</div>}

      {loading && (
        <div style={{textAlign:'center',padding:'32px 0',color:'var(--text-3)'}}>
          <div className="auth-loading-spinner" style={{margin:'0 auto 12px'}}/>
          Searching and synthesizing…
        </div>
      )}

      {result && (
        <div className="rag-result">
          <div className="rag-answer markdown-body">
            <ReactMarkdown>{result.answer}</ReactMarkdown>
          </div>
          {result.sources.length > 0 && (
            <details className="rag-sources">
              <summary>Sources ({result.sources.length} recordings)</summary>
              <div className="rag-sources-list">
                {result.sources.map((s, i) => (
                  <div key={i} className="rag-source-item">
                    <div className="rag-source-header">
                      <strong>{s.analyst_name}</strong>
                      <span className="ri-meta">{new Date(s.created_at).toLocaleDateString()} · {s.type} · {Math.round(s.similarity * 100)}% match</span>
                    </div>
                    <p className="rag-source-text">{s.transcript}</p>
                  </div>
                ))}
              </div>
            </details>
          )}
        </div>
      )}
    </div>
  );
}

/* ── PM Dashboard ────────────────────────────────────────────── */
export default function PMDashboard() {
  const { profile, logout } = useAuth();
  const navigate = useNavigate();
  const [prompts, setPrompts] = useState<Prompt[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [tab, setTab] = useState<'prompts' | 'rag'>('prompts');

  const load = useCallback(async () => {
    setLoading(true);
    try { const p = await listPrompts(); setPrompts(p); }
    catch (e) { console.error(e); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const toggleStatus = async (p: Prompt) => {
    await updatePromptStatus(p.id, p.status === 'active' ? 'closed' : 'active');
    load();
  };

  const active = prompts.filter(p => p.status === 'active');
  const closed = prompts.filter(p => p.status === 'closed');

  return (
    <div className="app">
      <div className="orb orb-1"/><div className="orb orb-2"/><div className="orb orb-3"/>

      <header className="app-header">
        <div className="header-brand">
          <div className="header-logo">🌊</div>
          <span className="header-name">Shunya <span>Mindstream</span></span>
        </div>
        <div style={{display:'flex',alignItems:'center',gap:12}}>
          <span className="header-badge" style={{background:'rgba(62,207,207,0.15)',color:'var(--cyan)',borderColor:'rgba(62,207,207,0.3)'}}>PM</span>
          <span style={{fontSize:13,color:'var(--text-2)'}}>{profile?.full_name}</span>
          <button className="btn" onClick={logout} style={{fontSize:12}}>Sign out</button>
        </div>
      </header>

      <main className="app-main">
        {/* Tabs */}
        <div className="pm-tabs">
          <button className={`pm-tab ${tab==='prompts'?'active':''}`} onClick={() => setTab('prompts')}>💬 Prompts</button>
          <button className={`pm-tab ${tab==='rag'?'active':''}`} onClick={() => setTab('rag')}>🔍 RAG Query</button>
        </div>

        {tab === 'prompts' && (
          <>
            <div className="dash-section-header" style={{marginBottom:16}}>
              <h2 className="dash-section-title">Active Prompts <span className="log-count">{active.length}</span></h2>
              <button className="btn btn-copy" onClick={() => setShowCreate(true)}>+ New Prompt</button>
            </div>

            {loading ? (
              <div style={{textAlign:'center',padding:'32px 0',color:'var(--text-3)'}}>Loading…</div>
            ) : active.length === 0 ? (
              <div className="empty-state">No active prompts. Create one to ask your analysts.</div>
            ) : (
              <div className="prompt-cards-grid">
                {active.map(p => (
                  <div key={p.id} className="prompt-card">
                    <div className="pc-header">
                      <h3 className="pc-title">{p.title}</h3>
                      <span className="pc-status active">Active</span>
                    </div>
                    {p.description && <p className="pc-desc">{p.description}</p>}
                    <div className="pc-meta">{p.deadline ? `Deadline: ${fmt(p.deadline)}` : `Created ${fmt(p.created_at)}`}</div>
                    <div className="pc-actions">
                      <button className="btn btn-copy" onClick={() => navigate(`/pm/prompts/${p.id}`)}>View Responses</button>
                      <button className="btn" onClick={() => toggleStatus(p)}>Close</button>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {closed.length > 0 && (
              <>
                <h2 className="dash-section-title" style={{marginTop:32,marginBottom:16}}>Closed Prompts</h2>
                <div className="prompt-cards-grid">
                  {closed.map(p => (
                    <div key={p.id} className="prompt-card closed">
                      <div className="pc-header">
                        <h3 className="pc-title">{p.title}</h3>
                        <span className="pc-status closed">Closed</span>
                      </div>
                      <div className="pc-actions">
                        <button className="btn btn-copy" onClick={() => navigate(`/pm/prompts/${p.id}`)}>View Responses</button>
                        <button className="btn" onClick={() => toggleStatus(p)}>Reopen</button>
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}
          </>
        )}

        {tab === 'rag' && (
          <section className="dash-section">
            <h2 className="dash-section-title" style={{marginBottom:20}}>Ask Your Analysts</h2>
            <RAGPanel />
          </section>
        )}
      </main>

      {showCreate && <CreatePromptModal onClose={() => setShowCreate(false)} onCreated={load} />}
    </div>
  );
}
