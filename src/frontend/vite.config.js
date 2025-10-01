import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import fs from 'fs'
import path from 'path'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // HTTPS configuration for development
  const httpsConfig = mode === 'development' ? {
    https: {
      key: fs.existsSync('../../ssl/dev/server.key')
        ? fs.readFileSync('../../ssl/dev/server.key')
        : undefined,
      cert: fs.existsSync('../../ssl/dev/server.crt')
        ? fs.readFileSync('../../ssl/dev/server.crt')
        : undefined,
    },
  } : {};

  return {
    plugins: [react()],
    base: './',
    build: {
      outDir: 'dist',
      // Generate source maps for production debugging
      sourcemap: mode === 'production',
      // Optimize chunks
      rollupOptions: {
        output: {
          manualChunks: {
            vendor: ['react', 'react-dom', 'react-router-dom'],
          },
        },
      },
    },
    server: {
      port: 3000,
      host: true,
      strictPort: true,
      ...httpsConfig,
      proxy: {
        // Proxy API requests to backend
        '/api': {
          target: process.env.VITE_API_URL || 'http://localhost:8000',
          changeOrigin: true,
          secure: false, // Allow self-signed certs in development
          rewrite: (path) => path,
        },
        '/concerts': {
          target: process.env.VITE_API_URL || 'http://localhost:8000',
          changeOrigin: true,
          secure: false,
        },
        '/nl-concerts': {
          target: process.env.VITE_API_URL || 'http://localhost:8000',
          changeOrigin: true,
          secure: false,
        },
        '/health': {
          target: process.env.VITE_API_URL || 'http://localhost:8000',
          changeOrigin: true,
          secure: false,
        },
      },
    },
    preview: {
      port: 3000,
      host: true,
      strictPort: true,
      ...httpsConfig,
    },
  };
})