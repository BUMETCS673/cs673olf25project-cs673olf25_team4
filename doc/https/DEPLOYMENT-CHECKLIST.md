# Test Server Deployment Checklist

## Quick Reference for testbeatmap.com Deployment

---

## Pre-Deployment

- [ ] DNS verified: `dig +short testbeatmap.com` returns `18.224.92.5`
- [ ] Server is reachable: `ping 18.224.92.5`
- [ ] SSH access confirmed
- [ ] Repository cloned/updated on server
- [ ] `.env` file created with all API keys

---

## SSL Certificate Setup

```bash
# Connect to server
ssh user@testbeatmap.com

# Navigate to project
cd /opt/beatmap

# Generate SSL certificates
sudo bash ssl/setup-testbeatmap-ssl.sh
```

**Verify:**
- [ ] Certificates created at `/etc/letsencrypt/live/testbeatmap.com/`
- [ ] Auto-renewal configured (check `sudo crontab -l`)

---

## Application Deployment

```bash
# Deploy application
cd /opt/beatmap
sudo bash deploy-staging.sh
```

**Confirm deployment:**
- [ ] Type `DEPLOY` when prompted (if using production script)
- [ ] Wait 5-10 minutes for deployment
- [ ] Note backup location displayed

---

## Verification Tests

### 1. DNS & Network
```bash
dig +short testbeatmap.com        # Should return: 18.224.92.5
ping -c 2 testbeatmap.com          # Should respond
```
- [ ] DNS points to correct IP
- [ ] Server responds to ping

### 2. HTTPS Connectivity
```bash
curl -I https://testbeatmap.com                  # Frontend
curl https://testbeatmap.com:8443/health         # Backend
curl https://testbeatmap.com:8001/health         # Ticketmaster
curl https://testbeatmap.com:8002/health         # JamBase
curl https://testbeatmap.com:8003/health         # Groq
```
- [ ] Frontend returns 200 OK
- [ ] Backend health check passes
- [ ] All provider health checks pass

### 3. HTTP to HTTPS Redirect
```bash
curl -I http://testbeatmap.com
```
- [ ] Returns 301/302 redirect to HTTPS

### 4. SSL Certificate
```bash
sudo certbot certificates
openssl s_client -connect testbeatmap.com:443 -servername testbeatmap.com | grep "Verify return code"
```
- [ ] Certificate valid for testbeatmap.com
- [ ] Verify return code: 0 (ok)
- [ ] Expiry date ~90 days from now

### 5. Container Status
```bash
cd /opt/beatmap/src
docker compose -f docker-compose.prod.yml ps
```
- [ ] All containers show "Up" status
- [ ] No containers restarting

### 6. Browser Test
Open in browser: `https://testbeatmap.com`
- [ ] Page loads without SSL warnings
- [ ] No mixed content warnings in console
- [ ] Frontend displays correctly

### 7. SSL Labs Test
Visit: https://www.ssllabs.com/ssltest/analyze.html?d=testbeatmap.com
- [ ] Grade: A or A+ (target)

### 8. Security Headers
```bash
curl -I https://testbeatmap.com | grep -i "strict-transport-security\|content-security-policy\|x-frame-options"
```
- [ ] HSTS header present
- [ ] CSP header present
- [ ] X-Frame-Options present

---

## Post-Deployment Monitoring

### Check Logs
```bash
# All services
docker compose -f /opt/beatmap/src/docker-compose.prod.yml logs -f

# Specific service
docker compose -f /opt/beatmap/src/docker-compose.prod.yml logs -f backend
```
- [ ] No critical errors in logs
- [ ] Services started successfully

### Monitor Certificates
```bash
cd /opt/beatmap
sudo bash ssl/monitor-certificates.sh
```
- [ ] Certificate monitoring script runs successfully
- [ ] No expiration warnings

---

## Rollback (If Needed)

```bash
cd /opt/beatmap/src
sudo docker compose -f docker-compose.prod.yml down

# Find and use backup
ls -la /opt/beatmap/backups/
sudo docker compose -f ../backups/staging_YYYYMMDD_HHMMSS/docker-compose.backup.yml up -d
```

---

## Common Issues & Quick Fixes

### Issue: Port 80 in use during certificate generation
```bash
sudo systemctl stop nginx
sudo docker compose down
# Then retry certificate generation
```

### Issue: Containers won't start
```bash
# Check certificates exist
sudo ls -la /etc/letsencrypt/live/testbeatmap.com/

# Check logs
docker compose -f src/docker-compose.prod.yml logs backend
```

### Issue: Health checks fail
```bash
# Wait 60-90 seconds, services may still be starting
sleep 60

# Retry health checks
curl https://testbeatmap.com:8443/health
```

---

## Maintenance Commands

```bash
# Restart all services
cd /opt/beatmap/src
sudo docker compose -f docker-compose.prod.yml restart

# Stop services
sudo docker compose -f docker-compose.prod.yml down

# Update and redeploy
cd /opt/beatmap
sudo git pull origin main
sudo bash deploy-staging.sh

# Renew certificate manually
sudo certbot renew --force-renewal
```

---

## Sign-Off

Deployment completed by: _____________________ Date: _____________

**Verified:**
- [ ] All checklist items completed
- [ ] All tests passed
- [ ] Monitoring configured
- [ ] Documentation updated
- [ ] Team notified

---

*Quick Reference - Full guide: [TESTSERVER-DEPLOYMENT-GUIDE.md](TESTSERVER-DEPLOYMENT-GUIDE.md)*