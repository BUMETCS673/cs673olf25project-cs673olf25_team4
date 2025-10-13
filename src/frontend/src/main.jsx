{/*/ This file was generated with the help of AI. 90% of the code was written by AI, 
while the remaining 10% was added/modified by humans. */}

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './styles/globals.css'
import App from './App.jsx'
import * as serviceWorkerRegistration from './serviceWorkerRegistration.js'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)

// Register service worker for HTTPS and PWA support
serviceWorkerRegistration.register({
  onUpdate: (registration) => {
    console.log('[SW] New version available! Please refresh.')
    // Optional: Show update notification to user
    if (registration && registration.waiting) {
      registration.waiting.postMessage({ type: 'SKIP_WAITING' })
    }
  },
  onSuccess: () => {
    console.log('[SW] Service worker registered successfully')
  }
})
