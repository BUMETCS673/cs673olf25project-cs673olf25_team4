# HTTPS Configuration Guide

This guide explains how HTTPS is configured and used throughout the BeatMap application.

## Overview

**All services in BeatMap communicate via HTTPS**, including internal microservice communication. This ensures end-to-end encryption for all data in transit.

## Architecture

```
User Browser (HTTPS)
    ↓
Frontend Service (HTTPS)
    ↓
Backend Service (HTTPS)
    ↓
Provider Services (HTTPS)
    ├── Ticketmaster Provider
    ├── Jambase Provider
    └── Groq Provider
```

## Certificate Types by Environment

### Development (Local)
- **Certificate Type**: Self-signed
- **Generation**: Automatic via `ssl/ensure-dev-certs.sh`
- **SSL Verification**: Disabled (to allow self-signed certificates)
- **Location**: `ssl/dev/`
- **Valid For**: 365 days
- **Auto-Generated**: Yes, by `start-dev.sh` script

### Staging/Test (testbeatmap.com)
- **Certificate Type**: Let's Encrypt (CA-signed)
- **Generation**: Manual via `ssl/setup-testbeatmap-ssl.sh`
- **SSL Verification**: Enabled
- **Location**: `/etc/letsencrypt/live/testbeatmap.com/`
- **Valid For**: 90 days (auto-renewed)
- **Auto-Renewal**: Yes, via certbot

### Production (beatmap.live)
- **Certificate Type**: Let's Encrypt (CA-signed)
- **Generation**: Manual via `ssl/setup-production-ssl.sh`
- **SSL Verification**: Enabled
- **Location**: `/etc/letsencrypt/live/beatmap.live/`
- **Valid For**: 90 days (auto-renewed)
- **Auto-Renewal**: Yes, via certbot

## Environment-Based SSL Verification

The application automatically adjusts SSL certificate verification based on the `ENVIRONMENT` variable:

```python
# Backend code automatically detects environment
environment = os.getenv("ENVIRONMENT", "development").lower()
verify_ssl = environment in ["production", "prod", "staging"]

# Used in HTTP clients
async with httpx.AsyncClient(verify=verify_ssl) as client:
    # Makes HTTPS requests with appropriate verification
```

### Why Different Verification Settings?

**Development (verify=False)**:
- Allows use of self-signed certificates
- No need for domain names or CA validation
- Faster iteration and testing
- Still encrypts traffic, just doesn't verify certificate authority

**Production/Staging (verify=True)**:
- Validates certificates are signed by trusted CA
- Ensures no man-in-the-middle attacks
- Required for public-facing services
- Full security compliance

## Service URLs

### Development
All services use HTTPS URLs with self-signed certificates:
```bash
ENVIRONMENT=development
JAMBASE_API_URL=https://jambase_provider:8002
TICKETMASTER_API_URL=https://ticketmaster_provider:8001
GROQ_API_URL=https://groq_provider:8003
```

### Production
All services use HTTPS URLs with Let's Encrypt certificates:
```bash
ENVIRONMENT=production
JAMBASE_API_URL=https://jambase_provider:8002
TICKETMASTER_API_URL=https://ticketmaster_provider:8001
GROQ_API_URL=https://groq_provider:8003
```

## Docker Compose Configuration

### Certificate Mounting

**Development** (`docker-compose.dev.yml`):
```yaml
backend:
  volumes:
    - ../ssl/dev:/app/ssl:ro  # Read-only mount of dev certificates
  environment:
    SSL_ENABLED: "true"
    SSL_CERT_PATH: /app/ssl/server.crt
    SSL_KEY_PATH: /app/ssl/server.key
    ENVIRONMENT: development
```

**Production** (`docker-compose.prod.yml`):
```yaml
backend:
  volumes:
    - /etc/letsencrypt/live/beatmap.live:/app/ssl:ro
  environment:
    SSL_ENABLED: "true"
    SSL_CERT_PATH: /app/ssl/fullchain.pem
    SSL_KEY_PATH: /app/ssl/privkey.pem
    ENVIRONMENT: production
```

## Local Development Setup

### Automatic (Recommended)
```bash
# From project root
./start-dev.sh
```

This automatically:
1. Checks if Docker is running
2. Generates SSL certificates (if needed)
3. Creates `.env` file template
4. Starts all services with HTTPS

### Manual
```bash
# 1. Generate certificates
cd ssl
./ensure-dev-certs.sh

# 2. Start services
cd ../src
docker-compose -f docker-compose.dev.yml up --build
```

## Common Issues & Solutions

### Issue: "SSL: CERTIFICATE_VERIFY_FAILED"
**Cause**: SSL verification is enabled but using self-signed certificates
**Solution**: Ensure `ENVIRONMENT=development` is set in docker-compose.dev.yml

### Issue: Backend can't connect to providers
**Cause**: Wrong environment variable names or missing ENVIRONMENT setting
**Solution**: Check that these are set in docker-compose:
```yaml
environment:
  ENVIRONMENT: development  # Important!
  JAMBASE_API_URL: https://jambase_provider:8002
  TICKETMASTER_API_URL: https://ticketmaster_provider:8001
  GROQ_API_URL: https://groq_provider:8003
```

### Issue: Certificates expired in development
**Cause**: Development certificates are valid for 365 days
**Solution**: Regenerate certificates:
```bash
cd ssl
rm -rf dev/
./generate-dev-certs.sh
```

### Issue: Frontend shows "NET::ERR_CERT_INVALID"
**Cause**: Browser doesn't trust self-signed certificate (expected in development)
**Solution**: Click "Advanced" → "Proceed to localhost (unsafe)" - this is normal for development

## Security Considerations

### Development
- Self-signed certificates are **only for local development**
- Never use development certificates in production
- Never commit private keys to git (they're in .gitignore)

### Production
- Let's Encrypt certificates are automatically renewed
- Monitor certificate expiration with `ssl/monitor-certificates.sh`
- Certificates are mounted read-only in containers
- Private keys have restricted permissions (600)

## Certificate Lifecycle

### Development Certificates
1. Generated automatically by `ensure-dev-certs.sh`
2. Valid for 365 days
3. No renewal process needed
4. Regenerate manually if expired

### Production Certificates
1. Generated manually via setup scripts
2. Valid for 90 days
3. Auto-renewed via certbot (runs twice daily)
4. Monitored via monitoring scripts
5. Email alerts configured for expiration warnings

## Testing HTTPS Configuration

### Test Backend HTTPS
```bash
# Should return JSON without SSL errors
curl -k https://localhost:8443/health
```

### Test Provider Communication
```bash
# Check backend logs for SSL verification status
docker-compose -f docker-compose.dev.yml logs backend | grep -i ssl
```

### Test Certificate Validity
```bash
# Check certificate details
openssl x509 -in ssl/dev/server.crt -text -noout
```

## Additional Resources

- **SSL Certificate Management**: See `ssl/README.md`
- **Development Setup**: See main `README.md`
- **Implementation Details**: See `implement-team-feedback.md`
- **Certificate Monitoring**: `ssl/monitor-certificates.sh`
