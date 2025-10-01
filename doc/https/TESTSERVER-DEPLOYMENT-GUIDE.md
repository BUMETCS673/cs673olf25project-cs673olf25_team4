# Test Server Deployment Guide (testbeatmap.com)

## Overview
This guide provides step-by-step instructions for deploying the BeatMap application with HTTPS support to the test server at `testbeatmap.com` (IP: 18.224.92.5).

---

## Prerequisites Verification

### 1. DNS Configuration ✅
- **Domain**: testbeatmap.com
- **IP Address**: 18.224.92.5
- **Status**: DNS A record verified and pointing to correct IP

Verify with:
```bash
dig +short testbeatmap.com
# Should return: 18.224.92.5
```

### 2. Server Access
You will need:
- SSH access to the test server (18.224.92.5)
- Root or sudo privileges on the server
- Repository access to clone/pull the latest code

---

## Deployment Steps

### Step 1: Connect to Test Server

```bash
ssh user@testbeatmap.com
# or
ssh user@18.224.92.5
```

### Step 2: Clone/Update Repository

If first time:
```bash
cd /opt
sudo git clone <repository-url> beatmap
cd beatmap
```

If already cloned:
```bash
cd /opt/beatmap
sudo git pull origin main
# Or checkout specific branch
sudo git checkout BMP-160
sudo git pull origin BMP-160
```

### Step 3: Install Prerequisites

Ensure all required software is installed:

```bash
# Update system
sudo apt update

# Install Docker
sudo apt install docker.io docker-compose -y
sudo systemctl start docker
sudo systemctl enable docker

# Install Certbot for Let's Encrypt
sudo apt install certbot python3-certbot-nginx -y

# Install OpenSSL (usually pre-installed)
sudo apt install openssl -y

# Install dig for DNS verification
sudo apt install dnsutils -y
```

### Step 4: Configure Environment Variables

Create the `.env` file in the `src/` directory:

```bash
cd /opt/beatmap/src
sudo nano .env
```

Add the following environment variables:
```env
# API Keys (replace with actual keys)
JAMBASE_API_KEY=your_jambase_api_key_here
TM_API_KEY=your_ticketmaster_api_key_here
TM_API_SECRET=your_ticketmaster_api_secret_here
GROQ_API_KEY=your_groq_api_key_here

# Ticketmaster Configuration
TM_BASE_URL=https://app.ticketmaster.com/discovery/v2
```

Save and exit (Ctrl+X, Y, Enter in nano).

### Step 5: Generate SSL Certificates

Run the SSL setup script for testbeatmap.com:

```bash
cd /opt/beatmap
sudo bash ssl/setup-testbeatmap-ssl.sh
```

**What this script does:**
- Verifies DNS configuration
- Stops any services using port 80 (required for Let's Encrypt)
- Obtains SSL certificates from Let's Encrypt
- Sets up auto-renewal via cron job
- Validates certificate installation
- Creates certificate monitoring

**Expected Output:**
```
✅ DNS configuration verified
✅ SSL certificates obtained
✅ Certificates saved to /etc/letsencrypt/live/testbeatmap.com/
✅ Auto-renewal configured
```

**Troubleshooting:**
- If port 80 is in use, stop the service: `sudo systemctl stop nginx` or `sudo docker compose down`
- If DNS verification fails, wait 5-10 minutes for DNS propagation
- For staging certificates (testing), the script can use Let's Encrypt staging environment

### Step 6: Deploy Application with HTTPS

Run the staging deployment script:

```bash
cd /opt/beatmap
sudo bash deploy-staging.sh
```

**What this script does:**
1. Checks all prerequisites (Docker, certificates, environment)
2. Verifies DNS and SSL certificates
3. Creates backup of current deployment
4. Stops existing containers gracefully
5. Builds new Docker images
6. Starts containers with HTTPS configuration
7. Performs health checks on all services
8. Verifies HTTPS connectivity

**Expected Output:**
```
╔════════════════════════════════════════════════╗
║     Staging Deployment Successful!            ║
╚════════════════════════════════════════════════╝

Access Points:
  🌐 Frontend:  https://testbeatmap.com
  🔧 Backend:   https://testbeatmap.com:8443

Provider Services:
  🎫 Ticketmaster: https://testbeatmap.com:8001
  🎵 JamBase:      https://testbeatmap.com:8002
  🤖 Groq:         https://testbeatmap.com:8003
```

**Deployment Time:** Approximately 5-10 minutes

---

## Step 7: Verify HTTPS Connectivity

### A. Test Frontend
```bash
# From test server
curl -I https://testbeatmap.com

# From your local machine
open https://testbeatmap.com
# or
curl -I https://testbeatmap.com
```

**Expected Response:**
```
HTTP/2 200
server: nginx
content-type: text/html
```

### B. Test Backend API
```bash
curl https://testbeatmap.com:8443/health
```

**Expected Response:**
```json
{"status": "healthy"}
```

### C. Test Provider Services
```bash
# Ticketmaster
curl https://testbeatmap.com:8001/health

# JamBase
curl https://testbeatmap.com:8002/health

# Groq
curl https://testbeatmap.com:8003/health
```

### D. Verify HTTP to HTTPS Redirect
```bash
curl -I http://testbeatmap.com
```

**Expected Response:**
```
HTTP/1.1 301 Moved Permanently
Location: https://testbeatmap.com
```

---

## Step 8: SSL Certificate Verification

### A. Check Certificate Details
```bash
sudo certbot certificates
```

**Expected Output:**
```
Certificate Name: testbeatmap.com
  Domains: testbeatmap.com
  Expiry Date: [90 days from now]
  Certificate Path: /etc/letsencrypt/live/testbeatmap.com/fullchain.pem
  Private Key Path: /etc/letsencrypt/live/testbeatmap.com/privkey.pem
```

### B. Test SSL with OpenSSL
```bash
openssl s_client -connect testbeatmap.com:443 -servername testbeatmap.com
```

Look for:
- `Verify return code: 0 (ok)` - Certificate is valid and trusted
- Certificate chain information
- TLS version (should be TLS 1.2 or 1.3)

### C. SSL Labs Test
Visit: https://www.ssllabs.com/ssltest/analyze.html?d=testbeatmap.com

**Target Grade:** A or A+

---

## Step 9: Monitor Services

### Check Container Status
```bash
cd /opt/beatmap/src
docker compose -f docker-compose.prod.yml ps
```

**Expected Output:**
```
NAME                      STATUS    PORTS
concert_backend_prod      Up        0.0.0.0:8443->8443/tcp
beatmap_frontend_prod     Up        0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
ticketmaster_provider_prod Up       0.0.0.0:8001->8001/tcp
jambase_provider_prod     Up        0.0.0.0:8002->8002/tcp
groq_provider_prod        Up        0.0.0.0:8003->8003/tcp
```

### View Logs
```bash
# All services
docker compose -f docker-compose.prod.yml logs -f

# Specific service
docker compose -f docker-compose.prod.yml logs -f backend
docker compose -f docker-compose.prod.yml logs -f frontend
docker compose -f docker-compose.prod.yml logs -f ticketmaster_provider
```

### Monitor Certificates
```bash
cd /opt/beatmap
sudo bash ssl/monitor-certificates.sh
```

---

## Testing Checklist

After deployment, verify the following:

### ✅ Basic Connectivity
- [ ] `https://testbeatmap.com` loads successfully
- [ ] No SSL warnings in browser
- [ ] HTTP redirects to HTTPS
- [ ] Frontend displays correctly

### ✅ Backend API
- [ ] `https://testbeatmap.com:8443/health` returns healthy status
- [ ] API endpoints respond correctly
- [ ] CORS headers are present
- [ ] Security headers are set (HSTS, CSP, etc.)

### ✅ Provider Services
- [ ] Ticketmaster provider health check passes
- [ ] JamBase provider health check passes
- [ ] Groq provider health check passes
- [ ] Inter-service communication works

### ✅ SSL/TLS Configuration
- [ ] Certificate is valid and trusted
- [ ] Certificate matches domain (testbeatmap.com)
- [ ] Certificate expires in 90 days
- [ ] Auto-renewal is configured
- [ ] TLS 1.2 or 1.3 is enabled
- [ ] Strong cipher suites are used

### ✅ Security Headers
Check headers with:
```bash
curl -I https://testbeatmap.com
```

Expected headers:
- `Strict-Transport-Security` (HSTS)
- `Content-Security-Policy` (CSP)
- `X-Frame-Options`
- `X-Content-Type-Options`
- `X-XSS-Protection`

### ✅ Application Functionality
- [ ] Search for concerts works
- [ ] Event details display correctly
- [ ] Map functionality works
- [ ] All pages load without mixed content warnings
- [ ] Service worker installs (if applicable)

---

## Troubleshooting

### Issue: SSL Certificate Generation Fails

**Symptoms:**
```
Failed to obtain certificate from Let's Encrypt
```

**Solutions:**
1. Verify DNS is pointing to correct IP:
   ```bash
   dig +short testbeatmap.com
   ```

2. Ensure port 80 is available:
   ```bash
   sudo netstat -tlnp | grep :80
   # Stop any service using port 80
   sudo systemctl stop nginx
   ```

3. Check firewall rules:
   ```bash
   sudo ufw status
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

4. Try using staging environment first:
   Edit `ssl/setup-testbeatmap-ssl.sh` and use `--staging` flag for testing

### Issue: Containers Won't Start

**Symptoms:**
```
Container exits immediately after starting
```

**Solutions:**
1. Check logs:
   ```bash
   docker compose -f src/docker-compose.prod.yml logs
   ```

2. Verify SSL certificates exist:
   ```bash
   sudo ls -la /etc/letsencrypt/live/testbeatmap.com/
   ```

3. Check environment variables:
   ```bash
   cat src/.env
   ```

4. Verify certificate permissions:
   ```bash
   sudo chmod 644 /etc/letsencrypt/live/testbeatmap.com/*.pem
   sudo chmod 600 /etc/letsencrypt/live/testbeatmap.com/privkey.pem
   ```

### Issue: Health Checks Failing

**Symptoms:**
```
Service health check failed (may still be starting)
```

**Solutions:**
1. Wait longer - services may take 60-90 seconds to start
2. Check individual container logs
3. Verify SSL certificates are mounted correctly:
   ```bash
   docker exec concert_backend_prod ls -la /app/ssl/
   ```

### Issue: Mixed Content Warnings

**Symptoms:**
Browser shows mixed content warnings (HTTP resources on HTTPS page)

**Solutions:**
1. Check CSP headers are configured correctly
2. Ensure all API endpoints use HTTPS
3. Update frontend environment variables:
   ```bash
   # In .env
   VITE_API_URL=https://testbeatmap.com:8443
   ```

### Issue: Auto-Renewal Not Working

**Symptoms:**
Certificate expires without renewal

**Solutions:**
1. Check cron job:
   ```bash
   sudo crontab -l | grep certbot
   ```

2. Test renewal:
   ```bash
   sudo certbot renew --dry-run
   ```

3. Manually renew:
   ```bash
   sudo certbot renew --force-renewal
   ```

---

## Rollback Procedure

If deployment fails, rollback using the backup:

```bash
cd /opt/beatmap/src

# Find backup directory
ls -la /opt/beatmap/backups/

# Rollback to previous deployment
sudo docker compose -f docker-compose.prod.yml down
sudo docker compose -f ../backups/staging_YYYYMMDD_HHMMSS/docker-compose.backup.yml up -d
```

---

## Maintenance Commands

### Restart Services
```bash
cd /opt/beatmap/src
sudo docker compose -f docker-compose.prod.yml restart
```

### Restart Specific Service
```bash
sudo docker compose -f docker-compose.prod.yml restart backend
```

### Stop All Services
```bash
sudo docker compose -f docker-compose.prod.yml down
```

### Update Application (Pull Latest Code)
```bash
cd /opt/beatmap
sudo git pull origin main
sudo bash deploy-staging.sh
```

### Renew SSL Certificate Manually
```bash
sudo certbot renew --force-renewal
sudo docker compose -f /opt/beatmap/src/docker-compose.prod.yml restart
```

### View Certificate Expiration
```bash
cd /opt/beatmap
sudo bash ssl/monitor-certificates.sh
```

---

## Security Recommendations

1. **Firewall Configuration**
   ```bash
   sudo ufw enable
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 80/tcp    # HTTP
   sudo ufw allow 443/tcp   # HTTPS
   sudo ufw allow 8443/tcp  # Backend API
   sudo ufw allow 8001/tcp  # Ticketmaster provider
   sudo ufw allow 8002/tcp  # JamBase provider
   sudo ufw allow 8003/tcp  # Groq provider
   ```

2. **Regular Updates**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

3. **Monitor Certificate Expiration**
   Set up automated monitoring via cron:
   ```bash
   sudo crontab -e
   # Add:
   0 0 * * * /opt/beatmap/ssl/monitor-certificates.sh --alert-days 30
   ```

4. **Backup Strategy**
   - Automatic backups created during deployment
   - Consider regular database backups if applicable
   - Keep at least 3 deployment backups

5. **Log Rotation**
   Docker logs are configured with max-size: 10m and max-file: 3

---

## Success Criteria

### ✅ Deployment Complete When:
- [ ] HTTPS accessible at `https://testbeatmap.com`
- [ ] HTTP redirects to HTTPS automatically
- [ ] All health checks pass
- [ ] SSL certificate is valid (no browser warnings)
- [ ] SSL Labs grade is A or A+
- [ ] All application features work correctly
- [ ] No mixed content warnings
- [ ] Security headers properly configured
- [ ] Certificate auto-renewal configured
- [ ] Services restart on failure

---

## Support

### Documentation
- [../../HTTPS.md](../../HTTPS.md) - Overall HTTPS implementation plan
- [DOCKER-HTTPS-SETUP.md](src/DOCKER-HTTPS-SETUP.md) - Docker HTTPS configuration
- [ssl/README.md](ssl/README.md) - SSL certificate management

### Useful Commands Reference
```bash
# Check service status
sudo systemctl status docker
sudo systemctl status certbot.timer

# View all Docker containers
docker ps -a

# Docker system cleanup
docker system prune -a

# Certificate information
sudo certbot certificates

# Test SSL configuration
openssl s_client -connect testbeatmap.com:443 -servername testbeatmap.com

# DNS check
dig testbeatmap.com ANY
```

---

## Next Steps

After successful test server deployment:

1. **Monitor for 24-48 hours** to ensure stability
2. **Test all application features** thoroughly
3. **Run SSL Labs test** and address any issues
4. **Document any issues or improvements** needed
5. **Prepare for production deployment** to beatmap.live

---

*Last Updated: September 30, 2025*
*Deployment Target: testbeatmap.com (18.224.92.5)*
*Status: Ready for deployment*