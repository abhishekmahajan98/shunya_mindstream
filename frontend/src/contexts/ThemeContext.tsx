import { createContext, useContext, useEffect, useState, useCallback, type ReactNode } from 'react';
import { ConfigProvider, theme as antdTheme } from 'antd';

type Theme = 'light' | 'dark';

interface ThemeContextType {
  themeMode: Theme;
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextType | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [themeMode, setThemeMode] = useState<Theme>(() => {
    const saved = localStorage.getItem('theme-mode');
    if (saved === 'light' || saved === 'dark') return saved;
    // Default to dark since it's a voice-first meditative app
    return 'dark';
  });

  const toggleTheme = useCallback(() => {
    setThemeMode((prev) => (prev === 'light' ? 'dark' : 'light'));
  }, []);

  // Update localStorage and apply body class
  useEffect(() => {
    localStorage.setItem('theme-mode', themeMode);
    
    const root = document.documentElement;
    if (themeMode === 'light') {
      root.classList.remove('theme-dark');
      root.classList.add('theme-light');
      document.body.style.backgroundColor = '#f8f6f2';
    } else {
      root.classList.remove('theme-light');
      root.classList.add('theme-dark');
      document.body.style.backgroundColor = '#09090a';
    }
  }, [themeMode]);

  // Ant Design customized theme configurations
  const antThemeConfig = {
    algorithm: themeMode === 'dark' ? antdTheme.darkAlgorithm : antdTheme.defaultAlgorithm,
    token: themeMode === 'dark' 
      ? {
          colorPrimary: '#6aada0', // Meditative Teal
          colorBgBase: '#09090a',   // Background
          colorBgContainer: '#121214', // Cards / containers
          colorTextBase: '#e0d8cf', // Creamy text
          colorBorder: 'rgba(255, 255, 255, 0.08)',
          borderRadius: 12,
          fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
        }
      : {
          colorPrimary: '#4c8c7f', // Softer, darker teal for light mode
          colorBgBase: '#f8f6f2',   // Warm light sand background
          colorBgContainer: '#ffffff',
          colorTextBase: '#3c3836', // Warm deep brown-gray text
          colorBorder: 'rgba(0, 0, 0, 0.08)',
          borderRadius: 12,
          fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
        },
    components: {
      Button: {
        colorPrimary: themeMode === 'dark' ? '#6aada0' : '#4c8c7f',
        borderRadius: 24, // pill buttons for zen look
        controlHeight: 38,
        fontWeight: 500,
      },
      Card: {
        colorBgContainer: themeMode === 'dark' ? 'rgba(18, 18, 20, 0.65)' : 'rgba(255, 255, 255, 0.8)',
        backdropFilter: 'blur(20px)',
        border: '1px solid var(--border)',
      },
      Switch: {
        colorPrimary: themeMode === 'dark' ? '#6aada0' : '#4c8c7f',
      },
    },
  };

  return (
    <ThemeContext.Provider value={{ themeMode, toggleTheme }}>
      <ConfigProvider theme={antThemeConfig}>
        {children}
      </ConfigProvider>
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider');
  return ctx;
}
