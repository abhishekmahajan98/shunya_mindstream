import { createContext, useContext, useEffect, useState, useCallback, type ReactNode } from 'react';
import {
  type AuthSession,
  type Profile,
  clearSession,
  getStoredUser,
  setSession,
  login as apiLogin,
  signup as apiSignup,
} from '../services/api';

interface AuthState {
  userId: string | null;
  email: string | null;
  profile: Profile | null;
  loading: boolean;
}

interface AuthContextType extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string, fullName: string, role: 'analyst' | 'pm') => Promise<AuthSession>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({
    userId: null,
    email: null,
    profile: null,
    loading: true,
  });

  // Rehydrate from localStorage on mount
  useEffect(() => {
    const stored = getStoredUser();
    if (stored) {
      setState({ userId: stored.user_id, email: stored.email, profile: stored.profile, loading: false });
    } else {
      setState(s => ({ ...s, loading: false }));
    }
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const auth = await apiLogin(email, password);
    setSession(auth);
    setState({ userId: auth.user_id, email: auth.email, profile: auth.profile, loading: false });
  }, []);

  const signup = useCallback(async (email: string, password: string, fullName: string, role: 'analyst' | 'pm' = 'analyst'): Promise<AuthSession> => {
    const auth = await apiSignup(email, password, fullName, role);
    setSession(auth);
    setState({ userId: auth.user_id, email: auth.email, profile: auth.profile, loading: false });
    return auth;
  }, []);

  const logout = useCallback(() => {
    clearSession();
    setState({ userId: null, email: null, profile: null, loading: false });
  }, []);

  return (
    <AuthContext.Provider value={{ ...state, login, signup, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
