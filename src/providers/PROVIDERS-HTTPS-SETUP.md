# Provider Services HTTPS Setup Guide

This guide explains the HTTPS configuration for BeatMap provider services (JamBase, Ticketmaster, Groq).

## Overview

All provider services now support HTTPS with:
- **Development**: Shared self-signed certificates for local HTTPS testing
- **Test Environment**: Shared Let's Encrypt certificates for `testbeatmap.com`
- **Production**: Shared Let's Encrypt certificates for `beatmap.live`

## Provider Services

### 1. JamBase Provider
- **Port**: 8002 (HTTP) / 8002 (HTTPS)
- **Endpoints**: `/`, `/search`
- **Purpose**: Concert data from JamBase API

### 2. Ticketmaster Provider
- **Port**: 8001 (HTTP) / 8001 (HTTPS)
- **Endpoints**: `/`, `/search`, `/events/{event_id}`
- **Purpose**: Concert data from Ticketmaster API

### 3. Groq Provider
- **Port**: 8003 (HTTP) / 8003 (HTTPS)
- **Endpoints**: `/`, `/get_tokens`, `/get_summary`
- **Purpose**: Natural language processing and token extraction

## Certificate Sharing Strategy

All provider services share the same SSL certificates with the backend service:

```
ssl/
├── dev/                    # Shared development certificates
│   ├── server.crt         # Self-signed certificate
│   ├── server.key         # Private key
│   └── dhparam.pem        # Diffie-Hellman parameters
├── testbeatmap/           # Shared test server certificates
└── production/            # Shared production certificates
```

### Benefits of Certificate Sharing:
1. **Simplified Management**: Single set of certificates for all internal services
2. **Reduced Overhead**: Fewer certificates to renew and monitor
3. **Consistent Security**: All services use the same SSL/TLS configuration
4. **Cost Effective**: Single wildcard or multi-domain certificate covers all services

### Security Considerations:
- Certificates are shared only between internal microservices
- All services run on localhost in development
- Production services communicate over private network
- External traffic goes through NGINX reverse proxy only

## SSL Configuration Files

### JamBase Provider: `.env.ssl`
```env
# Service Configuration
JAMBASE_HOST=127.0.0.1
JAMBASE_PORT=8002
JAMBASE_ALLOW_BIND_ALL=false

# SSL/TLS Configuration
JAMBASE_SSL_ENABLED=true
JAMBASE_SSL_CERT_PATH=../../../ssl/dev/server.crt
JAMBASE_SSL_KEY_PATH=../../../ssl/dev/server.key

# API Key
JAMBASE_API_KEY=your_jambase_api_key_here
```

### Ticketmaster Provider: `.env.ssl`
```env
# Service Configuration
TM_HOST=127.0.0.1
TM_PORT=8001
TM_ALLOW_BIND_ALL=false

# SSL/TLS Configuration
TM_SSL_ENABLED=true
TM_SSL_CERT_PATH=../../../ssl/dev/server.crt
TM_SSL_KEY_PATH=../../../ssl/dev/server.key

# API Configuration
TM_BASE_URL=https://app.ticketmaster.com/discovery/v2
TM_API_KEY=your_ticketmaster_api_key_here
```

### Groq Provider: `.env.ssl`
```env
# Service Configuration
GROQ_HOST=127.0.0.1
GROQ_PORT=8003
GROQ_ALLOW_BIND_ALL=false
GROQ_RELOAD=false

# SSL/TLS Configuration
GROQ_SSL_ENABLED=true
GROQ_SSL_CERT_PATH=../../../ssl/dev/server.crt
GROQ_SSL_KEY_PATH=../../../ssl/dev/server.key

# API Configuration
GROQ_API_KEY=your_groq_api_key_here
```

## Development Setup

### 1. Verify SSL Certificates Exist

```bash
# From project root
ls -la ssl/dev/
# Should see: server.crt, server.key, dhparam.pem
```

If certificates don't exist, generate them:
```bash
cd ssl
./generate-dev-certs.sh
```

### 2. Configure Environment Files

Copy and configure SSL environment files for each provider:

```bash
# JamBase
cd src/providers/jambase
cp .env.ssl .env
# Edit .env and set your JAMBASE_API_KEY

# Ticketmaster
cd ../ticketmaster
cp .env.ssl .env
# Edit .env and set your TM_API_KEY

# Groq
cd ../groq
cp .env.ssl .env
# Edit .env and set your GROQ_API_KEY
```

### 3. Start Provider Services with HTTPS

**JamBase Service:**
```bash
cd src/providers/jambase
python jambase_service.py
# Should see: HTTPS enabled for Jambase service
# Service runs on: https://127.0.0.1:8002
```

**Ticketmaster Service:**
```bash
cd src/providers/ticketmaster
python ticketmaster_service.py
# Should see: HTTPS enabled for Ticketmaster service
# Service runs on: https://127.0.0.1:8001
```

**Groq Service:**
```bash
cd src/providers/groq
python groq_service.py
# Should see: HTTPS enabled for Groq service
# Service runs on: https://127.0.0.1:8003
```

### 4. Test HTTPS Endpoints

```bash
# Test JamBase (with self-signed cert warning)
curl -k https://127.0.0.1:8002/
# Expected: {"status":"ok","message":"Jambase service is running."}

# Test Ticketmaster
curl -k https://127.0.0.1:8001/
# Expected: {"status":"ok","message":"Ticketmaster service is running."}

# Test Groq
curl -k https://127.0.0.1:8003/
# Expected: {"status":"ok","message":"Groq service is running."}
```

## Inter-Service Communication

### Backend to Provider Communication

The backend service communicates with provider services over HTTPS:

**Backend Configuration** (`.env.ssl`):
```env
# Provider Service URLs (HTTPS)
JAMBASE_SERVICE_URL=https://127.0.0.1:8002
TICKETMASTER_SERVICE_URL=https://127.0.0.1:8001
GROQ_SERVICE_URL=https://127.0.0.1:8003

# SSL Verification (disable for self-signed certs in development)
VERIFY_SSL=false
```

**Python HTTP Client Configuration:**
```python
import httpx

# For development with self-signed certificates
async with httpx.AsyncClient(verify=False) as client:
    response = await client.get("https://127.0.0.1:8002/")

# For production with valid certificates
async with httpx.AsyncClient() as client:
    response = await client.get("https://provider.beatmap.live/")
```

## Production Deployment

### Certificate Paths for Production

Update `.env.ssl` files for production environment:

```env
# Production certificate paths
JAMBASE_SSL_CERT_PATH=/etc/letsencrypt/live/beatmap.live/fullchain.pem
JAMBASE_SSL_KEY_PATH=/etc/letsencrypt/live/beatmap.live/privkey.pem
```

### Service Binding

For production deployment behind a reverse proxy:

```env
# Allow binding to all interfaces in production
JAMBASE_HOST=0.0.0.0
JAMBASE_ALLOW_BIND_ALL=true
```

⚠️ **Security Warning**: Only enable `ALLOW_BIND_ALL` when services are behind a firewall or reverse proxy.

### Reverse Proxy Configuration

NGINX configuration for proxying to provider services:

```nginx
# Internal provider services (not exposed externally)
upstream jambase_service {
    server localhost:8002;
}

upstream ticketmaster_service {
    server localhost:8001;
}

upstream groq_service {
    server localhost:8003;
}

# Backend can communicate with providers over HTTPS
# External clients only access backend, not providers directly
```

## Testing HTTPS

### Development Testing

```bash
# Test certificate validity
openssl s_client -connect 127.0.0.1:8002 -showcerts

# Test HTTPS connectivity
curl -k https://127.0.0.1:8002/

# Test with certificate verification (will fail with self-signed)
curl https://127.0.0.1:8002/
```

### Integration Testing

```bash
# Test backend -> provider communication
cd src/backend
python -c "
import httpx
import asyncio

async def test():
    async with httpx.AsyncClient(verify=False) as client:
        r = await client.get('https://127.0.0.1:8002/')
        print(r.json())

asyncio.run(test())
"
```

## Troubleshooting

### Certificate Not Found Error

```
SSL certificates not found. Running without HTTPS.
Expected cert: ../../../ssl/dev/server.crt, key: ../../../ssl/dev/server.key
```

**Solution**: Generate development certificates:
```bash
cd ssl
./generate-dev-certs.sh
```

### Permission Denied Error

```
PermissionError: [Errno 13] Permission denied: '../../../ssl/dev/server.key'
```

**Solution**: Check file permissions:
```bash
ls -la ssl/dev/
# server.key should be: -rw------- (600)
chmod 600 ssl/dev/server.key
```

### SSL Handshake Error

```
SSL: CERTIFICATE_VERIFY_FAILED
```

**Solution**: For development with self-signed certificates:
```python
# Python httpx
async with httpx.AsyncClient(verify=False) as client:
    ...

# curl
curl -k https://127.0.0.1:8002/
```

### Port Already in Use

```
OSError: [Errno 48] error while attempting to bind on address ('127.0.0.1', 8002)
```

**Solution**: Kill existing process or change port:
```bash
# Find process using port
lsof -i :8002

# Kill process
kill -9 <PID>

# Or change port in .env
JAMBASE_PORT=8012
```

## Security Best Practices

### 1. Certificate Security
- Keep private keys secure with 600 permissions
- Never commit certificates to version control
- Rotate certificates regularly (Let's Encrypt: 90 days)

### 2. Service Binding
- Default to localhost (127.0.0.1) in development
- Only bind to 0.0.0.0 in production behind firewall
- Use `ALLOW_BIND_ALL` flag as explicit security control

### 3. SSL Verification
- Disable SSL verification only in development
- Always verify SSL certificates in production
- Use proper CA-signed certificates for production

### 4. API Key Security
- Store API keys in environment variables only
- Never commit API keys to version control
- Use different API keys for dev/test/production

### 5. Network Isolation
- Run provider services on private network
- Expose only backend/frontend through reverse proxy
- Use firewall rules to restrict access

## Environment-Specific Configuration

### Development
```env
SSL_ENABLED=true
SSL_CERT_PATH=../../../ssl/dev/server.crt
SSL_KEY_PATH=../../../ssl/dev/server.key
HOST=127.0.0.1
ALLOW_BIND_ALL=false
VERIFY_SSL=false  # For self-signed certs
```

### Test (testbeatmap.com)
```env
SSL_ENABLED=true
SSL_CERT_PATH=/etc/letsencrypt/live/testbeatmap.com/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/testbeatmap.com/privkey.pem
HOST=0.0.0.0
ALLOW_BIND_ALL=true
VERIFY_SSL=true
```

### Production (beatmap.live)
```env
SSL_ENABLED=true
SSL_CERT_PATH=/etc/letsencrypt/live/beatmap.live/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/beatmap.live/privkey.pem
HOST=0.0.0.0
ALLOW_BIND_ALL=true
VERIFY_SSL=true
```

## Service Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     NGINX (Port 443)                     │
│              Frontend + Reverse Proxy (HTTPS)            │
└─────────────────────────────────────────────────────────┘
                           │
                           │ HTTPS
                           ▼
┌─────────────────────────────────────────────────────────┐
│              Backend API (Port 8443/HTTPS)               │
│                   FastAPI Application                    │
└─────────────────────────────────────────────────────────┘
         │                 │                 │
         │ HTTPS           │ HTTPS           │ HTTPS
         ▼                 ▼                 ▼
┌────────────────┐  ┌─────────────┐  ┌─────────────┐
│   JamBase      │  │ Ticketmaster│  │    Groq     │
│   Provider     │  │  Provider   │  │  Provider   │
│ Port 8002/HTTPS│  │Port 8001/HTTPS│ │Port 8003/HTTPS│
└────────────────┘  └─────────────┘  └─────────────┘
         │                 │                 │
         ▼                 ▼                 ▼
┌────────────────┐  ┌─────────────┐  ┌─────────────┐
│  JamBase API   │  │Ticketmaster │  │  Groq API   │
│   (External)   │  │API (External)│  │ (External)  │
└────────────────┘  └─────────────┘  └─────────────┘
```

## Resources

- [Uvicorn SSL Documentation](https://www.uvicorn.org/#running-with-https)
- [FastAPI Security](https://fastapi.tiangolo.com/advanced/security/)
- [Python HTTPX SSL Configuration](https://www.python-httpx.org/advanced/#ssl-certificates)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

## Next Steps

1. ✅ SSL configuration implemented for all providers
2. ✅ Environment files created (.env.ssl)
3. ✅ Certificate sharing strategy documented
4. ⏭️ Update Docker Compose to mount SSL certificates
5. ⏭️ Configure backend to communicate with providers over HTTPS
6. ⏭️ Deploy to test server with Let's Encrypt certificates

---

*Last Updated: September 29, 2025*
*Status: Phase 2.3 Provider Services HTTPS Support Complete ✅*