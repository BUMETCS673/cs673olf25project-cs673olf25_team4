# Docker HTTPS Setup Guide

This guide explains how to run the BeatMap application with HTTPS using Docker and Docker Compose.

## Overview

Three Docker Compose configurations are provided:

1. **docker-compose.yml** - HTTP only (basic testing, no SSL)
2. **docker-compose.dev.yml** - HTTPS with self-signed certificates (development)
3. **docker-compose.prod.yml** - HTTPS with Let's Encrypt certificates (production)

## Architecture

```
┌────────────────────────────────────────────────────────┐
│               Frontend (NGINX)                          │
│         HTTP: Port 80 | HTTPS: Port 443                │
│      (Redirects HTTP → HTTPS in production)            │
└────────────────────────────────────────────────────────┘
                         │
                         │ HTTPS
                         ▼
┌────────────────────────────────────────────────────────┐
│             Backend API (FastAPI)                       │
│                HTTPS: Port 8443                         │
└────────────────────────────────────────────────────────┘
         │              │              │
         │ HTTPS        │ HTTPS        │ HTTPS
         ▼              ▼              ▼
┌───────────────┐ ┌──────────────┐ ┌──────────────┐
│  Ticketmaster │ │   JamBase    │ │     Groq     │
│   Provider    │ │   Provider   │ │   Provider   │
│  Port 8001    │ │  Port 8002   │ │  Port 8003   │
└───────────────┘ └──────────────┘ └──────────────┘
```

## Prerequisites

### 1. Docker and Docker Compose

```bash
# Verify Docker is installed
docker --version

# Verify Docker Compose is installed
docker compose version
```

### 2. SSL Certificates

**For Development:**
```bash
# Generate self-signed certificates
cd ssl
./generate-dev-certs.sh
cd ..
```

**For Production:**
```bash
# Certificates should be obtained via Let's Encrypt
# See ssl/setup-production-ssl.sh
```

### 3. Environment Variables

Create a `.env` file in the `src/` directory:

```env
# API Keys
JAMBASE_API_KEY=your_jambase_api_key
TM_API_KEY=your_ticketmaster_api_key
TM_API_SECRET=your_ticketmaster_secret
GROQ_API_KEY=your_groq_api_key
```

## Usage

### HTTP Only (Basic Testing)

Use the default `docker-compose.yml` for basic testing without SSL:

```bash
cd src

# Start services
docker compose up -d

# View logs
docker compose logs -f

# Stop services
docker compose down
```

**Access:**
- Frontend: http://localhost:3000
- Backend: http://localhost:8000
- Ticketmaster Provider: http://localhost:8001
- JamBase Provider: http://localhost:8002
- Groq Provider: http://localhost:8003

### HTTPS Development

Use `docker-compose.dev.yml` with self-signed certificates:

```bash
cd src

# Start services with development SSL configuration
docker compose -f docker-compose.dev.yml up -d

# View logs
docker compose -f docker-compose.dev.yml logs -f

# Stop services
docker compose -f docker-compose.dev.yml down
```

**Access:**
- Frontend: https://localhost (port 443)
- Backend: https://localhost:8443
- Ticketmaster Provider: https://localhost:8001
- JamBase Provider: https://localhost:8002
- Groq Provider: https://localhost:8003

**Note:** Your browser will show a security warning for self-signed certificates. Click "Advanced" and "Proceed" to continue.

### Frontend Live Testing (React + Vite)

For live testing for frontend changes with automatic reloads (hot reloading and retriggers), use the **frontend live dev container**.  
This setup runs Vite inside Docker, so your UI updates instantly whenever you edit files locally.

```bash
# Start frontend live dev container
docker compose -f docker-compose.dev.frontend.yml up

# View logs
docker compose -f docker-compose.dev.frontend.yml logs -f

# Stop and remove containers
docker compose -f docker-compose.dev.frontend.yml down
```

### HTTPS Production

Use `docker-compose.prod.yml` with Let's Encrypt certificates:

```bash
cd src

# Start services with production SSL configuration
docker compose -f docker-compose.prod.yml up -d

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Stop services
docker compose -f docker-compose.prod.yml down
```

**Access:**
- Frontend: https://beatmap.live
- Backend: https://beatmap.live:8443

## Docker Compose Files Explained

### docker-compose.yml (HTTP Only)

**Purpose:** Basic testing without SSL/TLS encryption

**Features:**
- All services on HTTP
- No certificate mounting
- Simplified configuration
- Fastest startup time

**Use Case:** Local development when HTTPS is not required

### docker-compose.dev.yml (Development HTTPS)

**Purpose:** Local development with HTTPS using self-signed certificates

**Features:**
- All services on HTTPS
- Mounts `ssl/dev/` certificates
- Self-signed certificates (browser warnings expected)
- HSTS disabled for easier development
- HTTP fallback available

**Certificate Mounting:**
```yaml
volumes:
  - ../ssl/dev:/app/ssl:ro  # Read-only mount
```

**Use Case:**
- Testing HTTPS locally
- Developing SSL-dependent features
- Testing certificate handling

### docker-compose.prod.yml (Production HTTPS)

**Purpose:** Production deployment with Let's Encrypt certificates

**Features:**
- HTTPS only (HTTP redirects to HTTPS)
- Mounts Let's Encrypt certificates from `/etc/letsencrypt/`
- HSTS enabled with preload
- Automatic restart policies
- Log rotation configured
- Strict SSL verification

**Certificate Mounting:**
```yaml
volumes:
  - /etc/letsencrypt/live/beatmap.live:/app/ssl:ro
```

**Use Case:** Production deployment on beatmap.live

## SSL Certificate Volumes

### Development Certificates

Mounted from `ssl/dev/`:
- `server.crt` - Self-signed certificate
- `server.key` - Private key
- `dhparam.pem` - Diffie-Hellman parameters

```yaml
volumes:
  - ../ssl/dev:/app/ssl:ro
```

### Production Certificates

Mounted from Let's Encrypt:
- `fullchain.pem` - Full certificate chain
- `privkey.pem` - Private key

```yaml
volumes:
  - /etc/letsencrypt/live/beatmap.live:/app/ssl:ro
```

## Environment Variables

### Backend SSL Configuration

```yaml
environment:
  SSL_ENABLED: "true"
  SSL_CERT_PATH: /app/ssl/server.crt
  SSL_KEY_PATH: /app/ssl/server.key
  FORCE_HTTPS: "false"  # "true" in production
  HSTS_ENABLED: "false"  # "true" in production
```

### Provider SSL Configuration

Each provider service has similar environment variables:

```yaml
environment:
  # Example for Ticketmaster
  TM_SSL_ENABLED: "true"
  TM_SSL_CERT_PATH: /app/ssl/server.crt
  TM_SSL_KEY_PATH: /app/ssl/server.key
  TM_HOST: "0.0.0.0"
  TM_PORT: "8001"
  TM_ALLOW_BIND_ALL: "true"
```

### Frontend Configuration

```yaml
environment:
  VITE_API_URL: https://backend:8443
  VITE_ENABLE_HTTPS: "true"
  VITE_STRICT_SSL: "false"  # "true" in production
```

## Port Mappings

### HTTP Configuration (docker-compose.yml)

| Service              | Container Port | Host Port | Protocol |
|---------------------|----------------|-----------|----------|
| Frontend            | 80             | 3000      | HTTP     |
| Backend             | 8000           | 8000      | HTTP     |
| Ticketmaster        | 8001           | 8001      | HTTP     |
| JamBase             | 8002           | 8002      | HTTP     |
| Groq                | 8003           | 8003      | HTTP     |

### HTTPS Development (docker-compose.dev.yml)

| Service              | Container Port | Host Port | Protocol |
|---------------------|----------------|-----------|----------|
| Frontend HTTP       | 80             | 80        | HTTP     |
| Frontend HTTPS      | 443            | 443       | HTTPS    |
| Backend HTTP        | 8000           | 8000      | HTTP     |
| Backend HTTPS       | 8443           | 8443      | HTTPS    |
| Ticketmaster        | 8001           | 8001      | HTTPS    |
| JamBase             | 8002           | 8002      | HTTPS    |
| Groq                | 8003           | 8003      | HTTPS    |

### HTTPS Production (docker-compose.prod.yml)

| Service              | Container Port | Host Port | Protocol |
|---------------------|----------------|-----------|----------|
| Frontend HTTP       | 80             | 80        | HTTP→HTTPS |
| Frontend HTTPS      | 443            | 443       | HTTPS    |
| Backend HTTPS       | 8443           | 8443      | HTTPS    |
| Ticketmaster        | 8001           | 8001      | HTTPS    |
| JamBase             | 8002           | 8002      | HTTPS    |
| Groq                | 8003           | 8003      | HTTPS    |

## Building Images

### Build All Services

```bash
# HTTP configuration
docker compose build

# Development HTTPS
docker compose -f docker-compose.dev.yml build

# Production HTTPS
docker compose -f docker-compose.prod.yml build
```

### Build Specific Service

```bash
# Build only backend
docker compose build backend

# Build only frontend
docker compose build frontend

# Build all providers
docker compose build ticketmaster_provider jambase_provider groq_provider
```

### Build with No Cache

```bash
# Force rebuild without cache
docker compose build --no-cache

# For specific configuration
docker compose -f docker-compose.dev.yml build --no-cache
```

## Common Commands

### Start Services

```bash
# Start in foreground
docker compose -f docker-compose.dev.yml up

# Start in background (detached)
docker compose -f docker-compose.dev.yml up -d

# Start specific services
docker compose -f docker-compose.dev.yml up backend frontend
```

### View Logs

```bash
# All services
docker compose -f docker-compose.dev.yml logs -f

# Specific service
docker compose -f docker-compose.dev.yml logs -f backend

# Last 100 lines
docker compose -f docker-compose.dev.yml logs --tail=100
```

### Stop Services

```bash
# Stop services (containers remain)
docker compose -f docker-compose.dev.yml stop

# Stop and remove containers
docker compose -f docker-compose.dev.yml down

# Stop, remove containers, and remove volumes
docker compose -f docker-compose.dev.yml down -v
```

### Restart Services

```bash
# Restart all services
docker compose -f docker-compose.dev.yml restart

# Restart specific service
docker compose -f docker-compose.dev.yml restart backend
```

### Execute Commands in Containers

```bash
# Open shell in backend container
docker compose -f docker-compose.dev.yml exec backend sh

# Run pytest in backend
docker compose -f docker-compose.dev.yml exec backend pytest

# Check certificate in container
docker compose -f docker-compose.dev.yml exec backend ls -la /app/ssl
```

## Troubleshooting

### Certificate Not Found

**Error:**
```
ERROR: SSL certificates not found at /app/ssl/
```

**Solution:**
```bash
# Verify certificates exist
ls -la ssl/dev/

# If missing, generate them
cd ssl && ./generate-dev-certs.sh && cd ..

# Verify volume mount in docker-compose file
docker compose -f docker-compose.dev.yml config | grep -A 2 volumes
```

### Permission Denied for Certificates

**Error:**
```
PermissionError: [Errno 13] Permission denied: '/app/ssl/server.key'
```

**Solution:**
```bash
# Check certificate permissions
ls -la ssl/dev/

# Fix permissions
chmod 644 ssl/dev/server.crt
chmod 600 ssl/dev/server.key
```

### Port Already in Use

**Error:**
```
ERROR: Port 443 is already in use
```

**Solution:**
```bash
# Find process using port
lsof -i :443

# Kill process or stop conflicting service
sudo systemctl stop nginx  # If nginx is running on host

# Or change port mapping in docker-compose file
```

### SSL Handshake Error

**Error:**
```
SSL: CERTIFICATE_VERIFY_FAILED
```

**Solution for Development:**
- Accept self-signed certificate in browser
- Set `VITE_STRICT_SSL=false` in environment
- Use `-k` flag with curl: `curl -k https://localhost`

**Solution for Production:**
- Verify Let's Encrypt certificates are valid
- Check certificate paths in docker-compose.prod.yml
- Ensure certificates haven't expired

### Container Won't Start

**Debug:**
```bash
# Check container logs
docker compose -f docker-compose.dev.yml logs backend

# Check container status
docker compose -f docker-compose.dev.yml ps

# Inspect container
docker inspect concert_backend_dev

# Try starting with no detach to see errors
docker compose -f docker-compose.dev.yml up backend
```

### Inter-Service Communication Fails

**Debug:**
```bash
# Test from backend to provider
docker compose -f docker-compose.dev.yml exec backend \
  curl -k https://ticketmaster_provider:8001/

# Check network
docker network ls
docker network inspect src_default

# Verify service names in environment variables
docker compose -f docker-compose.dev.yml config
```

## Testing HTTPS

### Test Frontend

```bash
# HTTP
curl http://localhost:3000

# HTTPS (development)
curl -k https://localhost

# HTTPS (with certificate verification)
curl --cacert ssl/dev/server.crt https://localhost
```

### Test Backend

```bash
# HTTPS endpoint
curl -k https://localhost:8443/health

# Check SSL certificate
openssl s_client -connect localhost:8443 -showcerts
```

### Test Provider Services

```bash
# Ticketmaster provider
curl -k https://localhost:8001/

# JamBase provider
curl -k https://localhost:8002/

# Groq provider
curl -k https://localhost:8003/
```

## Production Deployment

### 1. Obtain Let's Encrypt Certificates

```bash
# On production server
sudo ./ssl/setup-production-ssl.sh
```

### 2. Set Environment Variables

Create `/etc/beatmap/.env`:
```env
JAMBASE_API_KEY=production_key
TM_API_KEY=production_key
TM_API_SECRET=production_secret
GROQ_API_KEY=production_key
```

### 3. Deploy with Docker Compose

```bash
# Pull latest code
git pull origin main

# Build images
cd src
docker compose -f docker-compose.prod.yml build

# Start services
docker compose -f docker-compose.prod.yml up -d

# Verify services are running
docker compose -f docker-compose.prod.yml ps

# Check logs
docker compose -f docker-compose.prod.yml logs -f
```

### 4. Verify HTTPS

```bash
# Test from server
curl https://beatmap.live

# Test SSL certificate
openssl s_client -connect beatmap.live:443 -servername beatmap.live

# Check SSL Labs rating
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=beatmap.live
```

## Security Best Practices

1. **Never commit certificates to git**
   - Already in `.gitignore`
   - Use volume mounts instead

2. **Use read-only volume mounts**
   ```yaml
   volumes:
     - ../ssl/dev:/app/ssl:ro  # :ro = read-only
   ```

3. **Rotate certificates regularly**
   - Let's Encrypt: Auto-renewal every 90 days
   - Development: Regenerate periodically

4. **Use environment-specific configurations**
   - Development: Self-signed, relaxed security
   - Production: Let's Encrypt, strict security

5. **Enable HSTS in production**
   ```yaml
   HSTS_ENABLED: "true"
   HSTS_PRELOAD: "true"
   ```

6. **Use restart policies in production**
   ```yaml
   restart: unless-stopped
   ```

7. **Implement log rotation**
   ```yaml
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "3"
   ```

## Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Networking](https://docs.docker.com/network/)
- [Uvicorn SSL Documentation](https://www.uvicorn.org/#running-with-https)
- [NGINX SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)

## Next Steps

1. ✅ Dockerfiles updated for SSL support
2. ✅ Docker Compose configurations created
3. ✅ SSL volume mounts configured
4. ⏭️ Test locally with docker-compose.dev.yml
5. ⏭️ Deploy to test server with docker-compose.prod.yml

---

*Last Updated: September 29, 2025*
*Status: Phase 3.1 Docker Configuration Complete ✅*