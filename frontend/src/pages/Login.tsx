import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ email: '', password: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handle = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      await login(form.email, form.password);
      navigate('/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="orb orb-1"/><div className="orb orb-2"/>
      <div className="auth-card">
        <div className="auth-logo"><span>🌊</span></div>
        <h1 className="auth-title">Welcome back</h1>
        <p className="auth-sub">Sign in to Shunya Mindstream</p>

        {error && <div className="error-banner" role="alert">{error}</div>}

        <form onSubmit={handle} className="auth-form">
          <div className="field-group">
            <label className="field-label" htmlFor="email">Email</label>
            <input
              id="email" type="email" className="field-input" placeholder="you@firm.com"
              value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))}
              required autoFocus
            />
          </div>
          <div className="field-group">
            <label className="field-label" htmlFor="password">Password</label>
            <input
              id="password" type="password" className="field-input" placeholder="••••••••"
              value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))}
              required
            />
          </div>
          <button type="submit" className="auth-submit-btn" disabled={loading}>
            {loading ? 'Signing in…' : 'Sign In'}
          </button>
        </form>

        <p className="auth-switch">
          Don't have an account? <Link to="/signup">Sign up</Link>
        </p>
      </div>
    </div>
  );
}
