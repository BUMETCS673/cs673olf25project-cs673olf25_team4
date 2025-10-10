import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import fs from 'fs'
import path from 'path'
import basicSsl from '@vitejs/plugin-basic-ssl'

// ------------------------------------------------------
// Vite Configuration (Development + Production Safe)
// ------------------------------------------------------
// - Uses your real self-signed certs if present
// - Falls back to vite's built-in temp certs in Docker
// - Ignored entirely during `vite build` (production)
// ------------------------------------------------------

export default defineConfig(({ mode }) => {
  const certPath = path.resolve('../../ssl/dev/server.crt')
  const keyPath = path.resolve('../../ssl/dev/server.key')

  // Detect whether dev certs exist
  const hasLocalCerts = fs.existsSync(certPath) && fs.existsSync(keyPath)

  // Enable HTTPS if:
  // - Local certs exist, OR
  // - We're inside Docker (DOCKER_ENV=true from docker-compose)
  const useHttps = hasLocalCerts || process.env.DOCKER_ENV === 'true'

  return {
    plugins: [
      react(),
      ...(useHttps ? [basicSsl()] : []), // fallback to auto SSL when needed
    ],

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

    // ------------------------------------------------------
    // Dev Server (ignored in production builds)
    // ------------------------------------------------------
    server: {
      host: true,            // make server accessible outside container
      port: 3000,            // matches docker-compose
      strictPort: true,
      https: hasLocalCerts
        ? {
            key: fs.readFileSync(keyPath),
            cert: fs.readFileSync(certPath),
          }
        : useHttps,           // enables vite's built-in HTTPS if no certs
      watch: { usePolling: true }, // required for Docker hot reload

      // Proxy API requests to backend during development
      proxy: {
        '/api': {
          target: process.env.VITE_API_URL || 'https://localhost:8443',
          changeOrigin: true,
          secure: false, // allow self-signed backend certs
        },
        '/concerts': {
          target: process.env.VITE_API_URL || 'https://localhost:8443',
          changeOrigin: true,
          secure: false,
        },
        '/nl-concerts': {
          target: process.env.VITE_API_URL || 'https://localhost:8443',
          changeOrigin: true,
          secure: false,
        },
        '/health': {
          target: process.env.VITE_API_URL || 'https://localhost:8443',
          changeOrigin: true,
          secure: false,
        },
      },
    },

    // ------------------------------------------------------
    // Preview Server (for `vite preview`)
    // ------------------------------------------------------
    preview: {
      port: 3000,
      host: true,
      strictPort: true,
      https: hasLocalCerts
        ? {
            key: fs.readFileSync(keyPath),
            cert: fs.readFileSync(certPath),
          }
        : useHttps,
    },
  }
})
