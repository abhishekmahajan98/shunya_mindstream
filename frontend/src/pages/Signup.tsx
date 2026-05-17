import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export default function Signup() {
  const { signup } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ full_name: '', email: '', password: '', confirm: '' });
  const [role, setRole] = useState<'analyst' | 'pm'>('analyst');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handle = async (e: React.FormEvent) => {
    e.preventDefault();
    if (form.password !== form.confirm) { setError('Passwords do not match.'); return; }
    if (form.password.length < 8) { setError('Password must be at least 8 characters.'); return; }
    setLoading(true); setError(null);
    try {
      const auth = await signup(form.email, form.password, form.full_name, role);
      if (!auth.access_token) {
        setError('Check your email to confirm your account before signing in.');
        return;
      }
      navigate('/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Signup failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="orb orb-1"/><div className="orb orb-2"/>
      <div className="auth-card">
        <div className="auth-logo"><span>🌊</span></div>
        <h1 className="auth-title">Create account</h1>
        <p className="auth-sub">Join your team on Shunya Mindstream</p>

        {/* Role toggle */}
        <div className="role-toggle">
          <button
            type="button"
            className={`role-toggle-btn ${role === 'analyst' ? 'active' : ''}`}
            onClick={() => setRole('analyst')}
          >
            🎙 Analyst
          </button>
          <button
            type="button"
            className={`role-toggle-btn ${role === 'pm' ? 'active pm' : ''}`}
            onClick={() => setRole('pm')}
          >
            📊 Portfolio Manager
          </button>
        </div>

        {error && <div className="error-banner" role="alert">{error}</div>}

        <form onSubmit={handle} className="auth-form">
          <div className="field-group">
            <label className="field-label" htmlFor="full_name">Full Name</label>
            <input
              id="full_name" type="text" className="field-input" placeholder="Alex Chen"
              value={form.full_name} onChange={e => setForm(f => ({ ...f, full_name: e.target.value }))}
              required autoFocus
            />
          </div>
          <div className="field-group">
            <label className="field-label" htmlFor="email">Work Email</label>
            <input
              id="email" type="email" className="field-input" placeholder="you@firm.com"
              value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))}
              required
            />
          </div>
          <div className="field-group">
            <label className="field-label" htmlFor="password">Password</label>
            <input
              id="password" type="password" className="field-input" placeholder="Min 8 characters"
              value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))}
              required
            />
          </div>
          <div className="field-group">
            <label className="field-label" htmlFor="confirm">Confirm Password</label>
            <input
              id="confirm" type="password" className="field-input" placeholder="••••••••"
              value={form.confirm} onChange={e => setForm(f => ({ ...f, confirm: e.target.value }))}
              required
            />
          </div>
          <button type="submit" className="auth-submit-btn" disabled={loading}>
            {loading ? 'Creating account…' : `Sign up as ${role === 'pm' ? 'Portfolio Manager' : 'Analyst'}`}
          </button>
        </form>

        <p className="auth-switch">
          Already have an account? <Link to="/login">Sign in</Link>
        </p>
      </div>
    </div>
  );
}
