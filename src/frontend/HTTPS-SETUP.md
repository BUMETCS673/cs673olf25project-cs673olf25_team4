# Frontend HTTPS Setup Guide

This guide explains the HTTPS configuration for the BeatMap frontend application.

## Overview

The frontend supports HTTPS with:
- **Development**: Self-signed certificates for local HTTPS testing
- **Test Environment**: Let's Encrypt certificates for `testbeatmap.com`
- **Production**: Let's Encrypt certificates for `beatmap.live`

## Configuration Files

### NGINX Configuration

#### `nginx-ssl.conf` - Production HTTPS Configuration
- HTTP to HTTPS redirection
- SSL/TLS 1.2 and 1.3 only
- Security headers (HSTS, CSP, X-Frame-Options, etc.)
- Proxy configuration for backend API
- Certificate paths for different environments

#### `nginx.conf` - Development HTTP Configuration
- Basic HTTP server for local development
- API proxy to backend service

### Vite Configuration

#### `vite.config.js`
- HTTPS support for development server
- Automatic SSL certificate loading from `../../ssl/dev/`
- API proxy configuration for all environments
- Environment-aware build settings

### Environment Files

#### `.env.development`
```env
VITE_API_URL=https://localhost:8443
VITE_ENABLE_HTTPS=true
VITE_STRICT_SSL=false
```

#### `.env.test`
```env
VITE_API_URL=https://testbeatmap.com
VITE_ENABLE_HTTPS=true
VITE_STRICT_SSL=true
```

#### `.env.production`
```env
VITE_API_URL=https://beatmap.live
VITE_ENABLE_HTTPS=true
VITE_STRICT_SSL=true
```

## Service Worker

### `public/service-worker.js`
Progressive Web App support with:
- Offline caching strategy
- Network-first for API requests
- Cache-first for static assets
- Push notification support (future use)

### `src/serviceWorkerRegistration.js`
Service worker registration and lifecycle management:
- Automatic registration in production
- Update notifications
- Cache management
- Skip waiting functionality

## Development Setup

### 1. Generate Development Certificates

```bash
# From project root
cd ssl
./generate-dev-certs.sh
```

This creates:
- `ssl/dev/server.crt` - Self-signed certificate
- `ssl/dev/server.key` - Private key
- `ssl/dev/dhparam.pem` - Diffie-Hellman parameters

### 2. Start Development Server with HTTPS

```bash
cd src/frontend
npm run dev
```

The Vite dev server will automatically:
- Load SSL certificates from `../../ssl/dev/`
- Start on `https://localhost:3000`
- Proxy API requests to `https://localhost:8443`

### 3. Accept Self-Signed Certificate

When you first visit `https://localhost:3000`:
1. Browser will show a security warning
2. Click "Advanced" or "Details"
3. Click "Proceed to localhost (unsafe)" or "Accept the Risk"

This is normal for development with self-signed certificates.

## Docker Deployment

### Development

```bash
# Build with development configuration
docker build -t beatmap-frontend:dev .

# Run with SSL certificates mounted
docker run -p 443:443 -p 80:80 \
  -v $(pwd)/../../ssl/dev:/etc/nginx/ssl/dev:ro \
  beatmap-frontend:dev
```

### Production

```bash
# Build production image
docker build -t beatmap-frontend:prod \
  --build-arg NODE_ENV=production .

# Run with Let's Encrypt certificates
docker run -p 443:443 -p 80:80 \
  -v /etc/letsencrypt:/etc/letsencrypt:ro \
  beatmap-frontend:prod
```

## NGINX SSL Configuration Details

### SSL Protocols
- TLS 1.2 ✅
- TLS 1.3 ✅
- SSLv2 ❌ (disabled)
- SSLv3 ❌ (disabled)
- TLS 1.0 ❌ (disabled)
- TLS 1.1 ❌ (disabled)

### Security Headers

| Header | Value | Purpose |
|--------|-------|---------|
| Strict-Transport-Security | max-age=31536000; includeSubDomains; preload | Force HTTPS for 1 year |
| Content-Security-Policy | default-src 'self'; ... | Prevent XSS attacks |
| X-Frame-Options | DENY | Prevent clickjacking |
| X-Content-Type-Options | nosniff | Prevent MIME sniffing |
| X-XSS-Protection | 1; mode=block | Enable browser XSS protection |
| Referrer-Policy | strict-origin-when-cross-origin | Control referrer info |
| Permissions-Policy | geolocation=(), camera=(), ... | Restrict browser features |

### Cipher Suites

Strong cipher suites only:
- ECDHE-ECDSA-AES128-GCM-SHA256
- ECDHE-RSA-AES128-GCM-SHA256
- ECDHE-ECDSA-AES256-GCM-SHA384
- ECDHE-RSA-AES256-GCM-SHA384
- ECDHE-ECDSA-CHACHA20-POLY1305
- ECDHE-RSA-CHACHA20-POLY1305
- DHE-RSA-AES128-GCM-SHA256
- DHE-RSA-AES256-GCM-SHA384

## Testing HTTPS

### Local Development

```bash
# Check HTTPS is working
curl -k https://localhost:3000

# Test API proxy
curl -k https://localhost:3000/api/health

# Test certificate
openssl s_client -connect localhost:3000 -showcerts
```

### Test Server

```bash
# Test HTTPS connectivity
curl https://testbeatmap.com

# Test security headers
curl -I https://testbeatmap.com

# Test SSL Labs grade
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=testbeatmap.com
```

### Production Server

```bash
# Test HTTPS connectivity
curl https://beatmap.live

# Test security headers
curl -I https://beatmap.live

# Test SSL Labs grade
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=beatmap.live
```

## Troubleshooting

### Certificate Not Found Error

```
Error: ENOENT: no such file or directory, open '../../ssl/dev/server.key'
```

**Solution**: Generate development certificates:
```bash
cd ssl
./generate-dev-certs.sh
```

### Browser Shows "Not Secure" Warning

**In Development**: Normal for self-signed certificates. Click "Advanced" and proceed.

**In Production**: Check that:
1. Let's Encrypt certificates are properly installed
2. Certificate paths in `nginx-ssl.conf` are correct
3. Certificates haven't expired

### API Requests Failing

**Check**:
1. Backend is running on correct HTTPS port (8443)
2. CORS is properly configured
3. Backend SSL certificates are valid
4. Proxy configuration in Vite/NGINX is correct

### Mixed Content Warnings

**Solution**: Ensure all resources (images, scripts, styles) are loaded over HTTPS:
```javascript
// Bad
const imageUrl = 'http://example.com/image.jpg';

// Good
const imageUrl = 'https://example.com/image.jpg';
```

## Service Worker Updates

### Clear Service Worker Cache

```javascript
// In browser console
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(registrations => {
    registrations.forEach(registration => registration.unregister());
  });
  caches.keys().then(keys => {
    keys.forEach(key => caches.delete(key));
  });
}
```

### Force Service Worker Update

```javascript
// In browser console
if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
  navigator.serviceWorker.controller.postMessage({ type: 'SKIP_WAITING' });
}
```

## Security Best Practices

### 1. Always Use HTTPS in Production
- Set `VITE_ENABLE_HTTPS=true`
- Set `VITE_STRICT_SSL=true`
- Configure proper certificates

### 2. Keep Certificates Updated
- Let's Encrypt certificates expire after 90 days
- Set up automatic renewal with certbot
- Monitor certificate expiration dates

### 3. Security Headers
- All security headers are configured in `nginx-ssl.conf`
- Review and update CSP policy as needed
- Test with Mozilla Observatory

### 4. Regular Security Audits
- Run SSL Labs test quarterly
- Check for security header compliance
- Update cipher suites as needed

## Resources

- [MDN Web Security](https://developer.mozilla.org/en-US/docs/Web/Security)
- [SSL Labs Best Practices](https://github.com/ssllabs/research/wiki/SSL-and-TLS-Deployment-Best-Practices)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [OWASP HTTPS Guide](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html)
- [Vite HTTPS Configuration](https://vitejs.dev/config/server-options.html#server-https)

## Next Steps

1. ✅ NGINX SSL configuration created
2. ✅ Vite HTTPS support configured
3. ✅ Service worker implemented
4. ✅ Environment files created
5. ✅ Service worker integrated into main.jsx
6. ✅ PWA manifest linked in index.html
7. ⏭️ Update Docker Compose for SSL support
8. ⏭️ Deploy to test server
9. ⏭️ Deploy to production server

---

*Last Updated: September 29, 2025*
*Status: Phase 2.2 Frontend HTTPS Support Complete ✅*