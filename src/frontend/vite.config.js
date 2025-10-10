import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import fs from 'fs'
import path from 'path'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const certPath = path.resolve('../../ssl/dev/server.crt')
  const keyPath = path.resolve('../../ssl/dev/server.key')

  let httpsConfig = {} // always defined

  // Only add HTTPS if we're in development *and* certs exist
  if (mode === 'development' && fs.existsSync(certPath) && fs.existsSync(keyPath)) {
    httpsConfig = {
      https: {
        key: fs.readFileSync(keyPath),
        cert: fs.readFileSync(certPath),
      },
    }
  }

  return {
    plugins: [react()],
    base: './',
    build: {
      outDir: 'dist',
      sourcemap: mode === 'production',
      rollupOptions: {
        output: {
          manualChunks: {
            vendor: ['react', 'react-dom', 'react-router-dom'],
          },
        },
      },
    },
    server: {
      host: true,
      port: 3000,
      strictPort: true,
      ...httpsConfig, // safe to spread even if empty
      proxy: {
        '/api': {
          target: process.env.VITE_API_URL || 'http://localhost:8443',
          changeOrigin: true,
          secure: false,
        },
        '/concerts': {
          target: process.env.VITE_API_URL || 'http://localhost:8443',
          changeOrigin: true,
          secure: false,
        },
        '/nl-concerts': {
          target: process.env.VITE_API_URL || 'http://localhost:8443',
          changeOrigin: true,
          secure: false,
        },
        '/health': {
          target: process.env.VITE_API_URL || 'http://localhost:8443',
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
  }
})

