import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { ProtectedRoute } from './components/ProtectedRoute';
import Login from './pages/Login';
import Signup from './pages/Signup';
import AnalystHome from './pages/AnalystHome';
import PMDashboard from './pages/PMDashboard';
import PromptResponses from './pages/PromptResponses';
import './index.css';

function RootRedirect() {
  const { userId, profile, loading } = useAuth();
  if (loading) return <div className="auth-loading"><div className="auth-loading-spinner"/></div>;
  if (!userId) return <Navigate to="/login" replace />;
  return <Navigate to={profile?.role === 'pm' ? '/pm' : '/analyst'} replace />;
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login"  element={<Login />} />
          <Route path="/signup" element={<Signup />} />
          <Route path="/" element={<RootRedirect />} />
          <Route path="/analyst" element={
            <ProtectedRoute requiredRole="analyst"><AnalystHome /></ProtectedRoute>
          }/>
          <Route path="/pm" element={
            <ProtectedRoute requiredRole="pm"><PMDashboard /></ProtectedRoute>
          }/>
          <Route path="/pm/prompts/:id" element={
            <ProtectedRoute requiredRole="pm"><PromptResponses /></ProtectedRoute>
          }/>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}
