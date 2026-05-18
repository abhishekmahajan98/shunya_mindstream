import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { Form, Input, Button, Alert, Card, Radio } from 'antd';
import { MailOutlined, LockOutlined, UserOutlined } from '@ant-design/icons';

export default function Signup() {
  const { signup } = useAuth();
  const navigate = useNavigate();
  const [role, setRole] = useState<'analyst' | 'pm'>('analyst');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const onFinish = async (values: any) => {
    if (values.password !== values.confirm) { 
      setError('Passwords do not match.'); 
      return; 
    }
    if (values.password.length < 8) { 
      setError('Password must be at least 8 characters.'); 
      return; 
    }
    
    setLoading(true); 
    setError(null);
    try {
      const auth = await signup(values.email, values.password, values.full_name, role);
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
      <div className="auth-card-wrapper">
        <Card className="auth-card-antd" bordered={false}>
          <div className="auth-logo"><span>🌊</span></div>
          <h1 className="auth-title">Create account</h1>
          <p className="auth-sub">Join your team on Shunya Mindstream</p>

          {/* Role selector segmented using Ant Design Radio Buttons */}
          <div className="role-selector-wrap" style={{ marginBottom: 24, display: 'flex', justifyContent: 'center' }}>
            <Radio.Group 
              value={role} 
              onChange={e => setRole(e.target.value)} 
              optionType="button" 
              buttonStyle="solid"
              size="middle"
            >
              <Radio.Button value="analyst" className="role-radio-btn">🎙 Analyst</Radio.Button>
              <Radio.Button value="pm" className="role-radio-btn">📊 PM</Radio.Button>
            </Radio.Group>
          </div>

          {error && (
            <Alert
              message={error}
              type={error.includes('Check your email') ? 'info' : 'error'}
              showIcon
              style={{ marginBottom: 20 }}
            />
          )}

          <Form
            name="signup_form"
            className="auth-form-antd"
            onFinish={onFinish}
            layout="vertical"
            size="large"
          >
            <Form.Item
              name="full_name"
              rules={[{ required: true, message: 'Please enter your full name' }]}
            >
              <Input 
                prefix={<UserOutlined className="site-form-item-icon" />} 
                placeholder="Full Name" 
                autoComplete="name"
              />
            </Form.Item>

            <Form.Item
              name="email"
              rules={[
                { required: true, message: 'Please enter your work email' },
                { type: 'email', message: 'Please enter a valid email' }
              ]}
            >
              <Input 
                prefix={<MailOutlined className="site-form-item-icon" />} 
                placeholder="Work Email" 
                autoComplete="email"
              />
            </Form.Item>

            <Form.Item
              name="password"
              rules={[{ required: true, message: 'Please enter a password' }]}
            >
              <Input.Password
                prefix={<LockOutlined className="site-form-item-icon" />}
                placeholder="Password (min 8 chars)"
                autoComplete="new-password"
              />
            </Form.Item>

            <Form.Item
              name="confirm"
              rules={[{ required: true, message: 'Please confirm your password' }]}
            >
              <Input.Password
                prefix={<LockOutlined className="site-form-item-icon" />}
                placeholder="Confirm Password"
                autoComplete="new-password"
              />
            </Form.Item>

            <Form.Item>
              <Button type="primary" htmlType="submit" className="auth-submit-btn-antd" loading={loading} block>
                Sign up as {role === 'pm' ? 'Portfolio Manager' : 'Analyst'}
              </Button>
            </Form.Item>
          </Form>

          <p className="auth-switch">
            Already have an account? <Link to="/login">Sign in</Link>
          </p>
        </Card>
      </div>
    </div>
  );
}
