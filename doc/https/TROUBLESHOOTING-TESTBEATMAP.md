# Troubleshooting testbeatmap.com HTTPS Access

## Current Status
- ✅ Deployment successful
- ✅ SSL certificates generated and valid
- ✅ All containers started (including frontend)
- ❌ Health checks failed
- ❌ https://testbeatmap.com not accessible

---

## Diagnostic Steps

### 1. Test Port Connectivity

```bash
# Test if port 443 is reachable
nc -zv testbeatmap.com 443
# Expected: Connection to testbeatmap.com port 443 [tcp/https] succeeded!

# Test port 80
nc -zv testbeatmap.com 80
# Expected: Connection to testbeatmap.com port 80 [tcp/http] succeeded!

# Test if server responds
curl -v --max-time 10 https://testbeatmap.com
```

### 2. Check If Containers Are Running

SSH to server and check:
```bash
ssh ec2-user@testbeatmap.com

# Check containers
docker ps

# Expected output - all should show "Up":
# - concert_backend_prod
# - beatmap_frontend_prod
# - ticketmaster_provider_prod
# - jambase_provider_prod
# - groq_provider_prod
```

### 3. Check Container Logs

```bash
# Frontend logs
docker logs beatmap_frontend_prod

# Backend logs
docker logs concert_backend_prod

# Look for errors or SSL issues
```

### 4. Test From Server Itself

```bash
# From inside the server
curl -k https://localhost
curl -k https://localhost:8443/health

# Should return responses if containers are working
```

### 5. Check NGINX Configuration

```bash
# Get into frontend container
docker exec -it beatmap_frontend_prod sh

# Check NGINX config
cat /etc/nginx/conf.d/https.conf.template

# Check if SSL cert files exist
ls -la /etc/nginx/ssl/

# Test NGINX config
nginx -t

# Exit container
exit
```

### 6. Check Certificate Mounting

```bash
# Check if certificates are mounted in frontend
docker exec beatmap_frontend_prod ls -la /etc/nginx/ssl/

# Expected files:
# - fullchain.pem or cert.pem
# - privkey.pem
```

---

## Common Issues and Solutions

### Issue 1: Port 443 Not Reachable
**Symptom:** `nc -zv testbeatmap.com 443` fails

**Solution:** AWS Security Group issue
1. Go to AWS Console → EC2 → Security Groups
2. Find security group for test server
3. Verify inbound rule for port 443 exists:
   - Type: HTTPS
   - Protocol: TCP
   - Port: 443
   - Source: 0.0.0.0/0

### Issue 2: Containers Running But Not Responding
**Symptom:** `docker ps` shows containers up, but curl fails

**Possible causes:**
1. NGINX not configured correctly
2. SSL certificates not mounted
3. NGINX listening on wrong port

**Check:**
```bash
# See if NGINX is listening
docker exec beatmap_frontend_prod netstat -tlnp | grep :443

# Check NGINX error logs
docker logs beatmap_frontend_prod 2>&1 | grep -i error
```

### Issue 3: SSL Certificate Issues
**Symptom:** SSL handshake errors

**Check certificates:**
```bash
# On server
ls -la /etc/letsencrypt/live/testbeatmap.com/

# Should see:
# - fullchain.pem
# - privkey.pem
# - cert.pem
# - chain.pem

# Verify cert is valid
openssl x509 -in /etc/letsencrypt/live/testbeatmap.com/fullchain.pem -text -noout | grep -A 2 "Validity"
```

### Issue 4: NGINX Not Using SSL Config
**Symptom:** Container running but only HTTP works

**Check:**
```bash
# Check if SSL config is being used
docker exec beatmap_frontend_prod cat /etc/nginx/conf.d/https.conf.template

# Check NGINX is actually using SSL
docker exec beatmap_frontend_prod nginx -T | grep ssl_certificate
```

---

## Quick Fix Commands

### Restart All Containers
```bash
ssh ec2-user@testbeatmap.com
cd ~/cs673olf25project-cs673olf25_team4/src
sudo docker-compose -f docker-compose.prod.yml restart
```

### View All Logs
```bash
sudo docker-compose -f docker-compose.prod.yml logs -f
```

### Rebuild and Restart
```bash
sudo docker-compose -f docker-compose.prod.yml down
sudo docker-compose -f docker-compose.prod.yml up -d --build
```

---

## Current Deployment Configuration

### Expected Files on Server:
- `/etc/letsencrypt/live/testbeatmap.com/fullchain.pem`
- `/etc/letsencrypt/live/testbeatmap.com/privkey.pem`

### Docker Volumes (after sed replacement):
```yaml
volumes:
  - /etc/letsencrypt/live/testbeatmap.com:/etc/nginx/ssl:ro
```

### Expected Ports:
- 80 (HTTP) → should redirect to 443
- 443 (HTTPS) → frontend
- 8443 (HTTPS) → backend API
- 8001, 8002, 8003 → provider services

---

## Next Steps to Debug

1. **SSH to server** and run diagnostics
2. **Check container logs** for errors
3. **Verify NGINX configuration** inside container
4. **Test locally on server** (curl from localhost)
5. **Check AWS Security Group** one more time
6. **Verify certificates** are mounted correctly

---

## If All Else Fails

### Manual Container Inspection
```bash
# Check what docker-compose.prod.yml looks like after sed replacements
ssh ec2-user@testbeatmap.com
cat ~/cs673olf25project-cs673olf25_team4/src/docker-compose.prod.yml | grep -A 5 frontend

# Manually test frontend container
docker run -it --rm \
  -p 8080:443 \
  -v /etc/letsencrypt/live/testbeatmap.com:/etc/nginx/ssl:ro \
  src-frontend:latest
```

---

*Last Updated: September 30, 2025*
*Status: Containers running, investigating connectivity*