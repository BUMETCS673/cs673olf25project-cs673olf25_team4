# BeatMap HTTPS Deployment

## Overview

This repository includes comprehensive HTTPS support for the BeatMap application across all environments (development, staging/test, and production).

## 🚀 Automated Deployment (Recommended)

**Primary deployment method:** GitHub Actions automatically handles SSL certificate setup and HTTPS deployment.

### Quick Start - Test Server
```bash
git push origin test
```
GitHub Actions automatically:
- Generates/renews SSL certificates
- Deploys with HTTPS support
- Runs health checks
- Access at: https://testbeatmap.com

### Quick Start - Production
```bash
git push origin main
```
GitHub Actions automatically:
- Creates backup
- Generates/renews SSL certificates
- Deploys with HTTPS support
- Runs health checks
- Auto-rollback on failure
- Access at: https://beatmap.live

**See:** [GITHUB-ACTIONS-DEPLOYMENT.md](GITHUB-ACTIONS-DEPLOYMENT.md) for complete automated deployment guide.

---

## 🔧 Manual Deployment (Alternative)

---

## Quick Start

### Development (Local)
Deploy locally with self-signed certificates:

```bash
bash deploy-dev.sh
```

Access at:
- Frontend: https://localhost or http://localhost
- Backend: https://localhost:8443 or http://localhost:8000

**Note:** Your browser will show a security warning for self-signed certificates. This is expected.

### Staging/Test Server (testbeatmap.com)
Deploy to test server with Let's Encrypt certificates:

```bash
# On the test server (18.224.92.5)
sudo bash deploy-staging.sh
```

Access at:
- Frontend: https://testbeatmap.com
- Backend: https://testbeatmap.com:8443

**See:** [TESTSERVER-DEPLOYMENT-GUIDE.md](TESTSERVER-DEPLOYMENT-GUIDE.md) for detailed instructions.

### Production (beatmap.live)
Deploy to production with Let's Encrypt certificates:

```bash
# On the production server
sudo bash deploy-prod.sh
```

Access at:
- Frontend: https://beatmap.live
- Backend: https://beatmap.live:8443

---

## Deployment Scripts

| Script | Environment | SSL Certificates | Purpose |
|--------|-------------|------------------|---------|
| `deploy-dev.sh` | Development | Self-signed | Local development with HTTPS |
| `deploy-staging.sh` | Staging/Test | Let's Encrypt | Test server deployment (testbeatmap.com) |
| `deploy-prod.sh` | Production | Let's Encrypt | Production deployment (beatmap.live) |

### Script Features
- ✅ Automated prerequisite checks (Docker, certificates, environment)
- ✅ DNS verification (staging/production)
- ✅ SSL certificate generation and validation
- ✅ Automated backup before deployment
- ✅ Health checks for all services
- ✅ Automatic rollback on failure
- ✅ Comprehensive error handling and logging

---

## SSL Certificate Management

### Generate Development Certificates
```bash
bash ssl/generate-dev-certs.sh
```

### Set Up Test Server Certificates (testbeatmap.com)
```bash
sudo bash ssl/setup-testbeatmap-ssl.sh
```

### Set Up Production Certificates (beatmap.live)
```bash
sudo bash ssl/setup-production-ssl.sh
```

### Monitor Certificates
```bash
bash ssl/monitor-certificates.sh
```

### Deploy Certificates to Services
```bash
sudo bash ssl/deploy-certificates.sh --environment [development|test|production]
```

---

## Architecture

### Services
- **Frontend** (Port 80/HTTP, 443/HTTPS): React application served by NGINX
- **Backend** (Port 8000/HTTP, 8443/HTTPS): FastAPI application with SSL support
- **Ticketmaster Provider** (Port 8001/HTTPS): Ticketmaster API integration
- **JamBase Provider** (Port 8002/HTTPS): JamBase API integration
- **Groq Provider** (Port 8003/HTTPS): Groq AI integration

### Docker Compose Configurations
- `src/docker-compose.yml` - HTTP only (basic testing)
- `src/docker-compose.dev.yml` - Development with self-signed SSL
- `src/docker-compose.prod.yml` - Production with Let's Encrypt SSL

---

## Prerequisites

### All Environments
- Docker and Docker Compose
- OpenSSL
- Git

### Staging/Production Only
- Root/sudo access
- Certbot (Let's Encrypt client)
- DNS configured correctly
- Ports 80, 443, 8001-8003, 8443 open in firewall

---

## Environment Configuration

Create `src/.env` file with required API keys:

```env
# API Keys
JAMBASE_API_KEY=your_jambase_api_key
TM_API_KEY=your_ticketmaster_api_key
TM_API_SECRET=your_ticketmaster_api_secret
GROQ_API_KEY=your_groq_api_key

# Ticketmaster Configuration
TM_BASE_URL=https://app.ticketmaster.com/discovery/v2
```

---

## Documentation

### Deployment Guides
- [TESTSERVER-DEPLOYMENT-GUIDE.md](TESTSERVER-DEPLOYMENT-GUIDE.md) - Complete test server deployment guide
- [DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md) - Quick reference checklist

### Technical Documentation
- [../../HTTPS.md](../../HTTPS.md) - HTTPS implementation roadmap and status
- [src/DOCKER-HTTPS-SETUP.md](src/DOCKER-HTTPS-SETUP.md) - Docker HTTPS configuration details
- [ssl/README.md](ssl/README.md) - SSL certificate management guide

---

## Common Commands

### View Logs
```bash
# Development
docker compose -f src/docker-compose.dev.yml logs -f

# Staging/Production
docker compose -f src/docker-compose.prod.yml logs -f

# Specific service
docker compose -f src/docker-compose.prod.yml logs -f backend
```

### Check Service Status
```bash
docker compose -f src/docker-compose.dev.yml ps
```

### Restart Services
```bash
# All services
docker compose -f src/docker-compose.dev.yml restart

# Specific service
docker compose -f src/docker-compose.dev.yml restart backend
```

### Stop Services
```bash
docker compose -f src/docker-compose.dev.yml down
```

---

## Health Checks

### Frontend
```bash
curl -I https://localhost                    # Development
curl -I https://testbeatmap.com              # Staging
curl -I https://beatmap.live                 # Production
```

### Backend
```bash
curl https://localhost:8443/health           # Development
curl https://testbeatmap.com:8443/health     # Staging
curl https://beatmap.live:8443/health        # Production
```

### Provider Services
```bash
curl https://localhost:8001/health           # Ticketmaster
curl https://localhost:8002/health           # JamBase
curl https://localhost:8003/health           # Groq
```

---

## Security Features

### SSL/TLS Configuration
- ✅ TLS 1.2 and TLS 1.3 support
- ✅ Strong cipher suites
- ✅ Perfect Forward Secrecy
- ✅ Certificate validation

### Security Headers
- ✅ HSTS (HTTP Strict Transport Security)
- ✅ CSP (Content Security Policy)
- ✅ X-Frame-Options
- ✅ X-Content-Type-Options
- ✅ X-XSS-Protection
- ✅ Referrer Policy
- ✅ Permissions Policy

### CORS Configuration
- ✅ Environment-aware CORS policies
- ✅ HTTPS-only origins in production
- ✅ Secure credentials handling

---

## Troubleshooting

### Issue: Browser shows SSL warning (Development)
**Expected behavior** - Self-signed certificates will show warnings. Click "Advanced" and proceed.

### Issue: Containers won't start
```bash
# Check logs
docker compose logs backend

# Verify certificates exist
ls -la ssl/dev/  # Development
sudo ls -la /etc/letsencrypt/live/testbeatmap.com/  # Staging
```

### Issue: Health checks fail
Wait 60-90 seconds for services to fully start, then retry.

### Issue: Port already in use
```bash
# Find process using port
sudo lsof -i :443

# Stop conflicting service
sudo systemctl stop nginx
```

---

## SSL Certificate Renewal

### Automatic Renewal
Certificates are automatically renewed via cron job (configured during setup).

### Manual Renewal
```bash
# Test renewal (dry run)
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal

# Restart services after renewal
docker compose -f src/docker-compose.prod.yml restart
```

---

## Rollback Procedure

Backups are automatically created during deployment in `backups/` directory.

To rollback:
```bash
# Stop current deployment
cd src
docker compose -f docker-compose.prod.yml down

# Find backup
ls -la ../backups/

# Start backup
docker compose -f ../backups/staging_YYYYMMDD_HHMMSS/docker-compose.backup.yml up -d
```

---

## Testing SSL Configuration

### OpenSSL Test
```bash
openssl s_client -connect testbeatmap.com:443 -servername testbeatmap.com
```

### SSL Labs Test
Visit: https://www.ssllabs.com/ssltest/analyze.html?d=testbeatmap.com

**Target Grade:** A or A+

---

## Support

### Getting Help
- Review documentation in this repository
- Check logs for error messages
- Verify prerequisites are installed
- Ensure environment variables are set correctly

### Useful Resources
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [NGINX SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)

---

## Current Status

### ✅ Completed
- [x] Phase 1: SSL/TLS Infrastructure Setup
- [x] Phase 2: Application Configuration (Backend, Frontend, Providers)
- [x] Phase 3: Infrastructure and Deployment (Docker, Deployment Scripts)
- [x] Test Server Documentation and Scripts Ready

### 🔄 In Progress
- [ ] Phase 4: Test Server Deployment (testbeatmap.com)
  - DNS configured ✅
  - Scripts ready ✅
  - Documentation complete ✅
  - **Awaiting execution on server**

### ⏳ Planned
- [ ] Phase 4: Production Server Setup (beatmap.live)
- [ ] Phase 5: Security Hardening
- [ ] Phase 6: Testing and Validation
- [ ] Phase 7: Monitoring and Maintenance
- [ ] Phase 8: Performance Optimization

See [../../HTTPS.md](../../HTTPS.md) for detailed status and roadmap.

---

## Next Steps

### For Test Server Deployment:
1. SSH to test server: `ssh user@testbeatmap.com`
2. Clone/update repository
3. Configure `.env` file with API keys
4. Run: `sudo bash ssl/setup-testbeatmap-ssl.sh`
5. Run: `sudo bash deploy-staging.sh`
6. Verify: `curl https://testbeatmap.com`

See [DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md) for detailed checklist.

---

*Last Updated: September 30, 2025*
*Status: Ready for test server deployment*