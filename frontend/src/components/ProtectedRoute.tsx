import { type ReactNode } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

interface Props {
  children: ReactNode;
  requiredRole?: 'analyst' | 'pm';
}

export function ProtectedRoute({ children, requiredRole }: Props) {
  const { userId, profile, loading } = useAuth();

  if (loading) {
    return (
      <div className="auth-loading">
        <div className="auth-loading-spinner" />
      </div>
    );
  }

  if (!userId) return <Navigate to="/login" replace />;

  if (requiredRole && profile?.role !== requiredRole) {
    return <Navigate to={profile?.role === 'pm' ? '/pm' : '/analyst'} replace />;
  }

  return <>{children}</>;
}
