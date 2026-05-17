import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // The Azure Speech SDK ships some CommonJS modules — this makes Vite pre-bundle them correctly
  optimizeDeps: {
    include: ['microsoft-cognitiveservices-speech-sdk'],
  },
  server: {
    port: 5173,
  },
})
