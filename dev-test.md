# Development Environment Testing Guide

This guide provides step-by-step instructions to verify that your local development environment is working properly.

## Prerequisites Check

Before starting, ensure you have:
- [ ] Docker Desktop installed and running
- [ ] Git repository cloned
- [ ] Terminal/command prompt open

## Test Procedure

### Step 1: Start Local Environment

```bash
# From the project root directory
./start-dev.sh --clean --yes
```

**Expected outcome:**
- Script runs without errors
- See messages about:
  - Docker checks passing
  - SSL certificates being generated/verified
  - `.env` file status
  - Docker images building
  - Containers starting

**Wait time:** 2-5 minutes for initial build

---

### Step 2: Verify All Containers Are Running

```bash
cd src
docker-compose -f docker-compose.dev.yml ps
```

**Expected outcome:**
All services should show "Up" status:
- `concert_backend_dev` - Up
- `beatmap_frontend_dev` - Up
- `ticketmaster_provider_dev` - Up
- `jambase_provider_dev` - Up
- `groq_provider_dev` - Up

**If any service is not running:**
```bash
# Check logs for the failing service
docker-compose -f docker-compose.dev.yml logs <service_name>
```

---

### Step 3: Test Frontend (HTTP)

**Navigate to:** http://localhost

**Expected outcome:**
- Page loads successfully
- BeatMap application appears
- No console errors (open browser DevTools with F12)

**Common browser warning (expected):**
- If redirected to HTTPS, browser may show "Your connection is not private" or "NET::ERR_CERT_INVALID"
- This is **normal** for self-signed certificates
- Click "Advanced" → "Proceed to localhost (unsafe)"

---

### Step 4: Test Frontend (HTTPS)

**Navigate to:** https://localhost

**Expected outcome:**
- Browser shows security warning (expected for self-signed cert)
- Click "Advanced" → "Proceed to localhost (unsafe)"
- Page loads successfully
- Application functions normally

---

### Step 5: Test Backend API (Health Check)

```bash
# From terminal
curl -k https://localhost:8443/health
```

**Expected outcome:**
```json
{
  "status": "healthy",
  "environment": "development",
  "version": "<version_number>",
  "ssl_enabled": true,
  "timestamp": "<timestamp>"
}
```

**Note:** The `-k` flag tells curl to accept self-signed certificates

---

### Step 6: Test Backend API Documentation

**Navigate to:** https://localhost:8443/docs

**Expected outcome:**
- Browser shows security warning (accept it)
- FastAPI Swagger UI documentation loads
- You can see available API endpoints
- Interactive API documentation is accessible

---

### Step 7: Test Backend Search Endpoint

**Navigate to:** https://localhost:8443/search?city=Boston

Or use curl:
```bash
curl -k "https://localhost:8443/search?city=Boston"
```

**Expected outcome:**
- Returns JSON response with concert data
- No error messages
- Response includes events/concerts (if providers are working)

**Note:** This requires valid API keys in your `.env` file

---

### Step 8: Verify SSL Certificates Exist

```bash
# From project root
ls -la ssl/dev/
```

**Expected outcome:**
You should see these files:
- `server.crt` - SSL certificate
- `server.key` - Private key
- `dhparam.pem` - Diffie-Hellman parameters
- `cert-info.txt` - Certificate information

---

### Step 9: Check Backend Logs for SSL Verification

```bash
cd src
docker-compose -f docker-compose.dev.yml logs backend | grep -i ssl
```

**Expected outcome:**
Should see messages like:
- "SSL verification disabled for development environment"
- "SSL enabled - server will run on port 8443"
- "SSL Configuration Summary"
- No SSL error messages

---

### Step 10: Test Inter-Service Communication

```bash
# Check if backend can reach providers
docker-compose -f docker-compose.dev.yml logs backend | grep -i provider
```

**Expected outcome:**
- Should see log entries about provider communication
- No "SSL: CERTIFICATE_VERIFY_FAILED" errors
- No connection errors to provider services

---

### Step 11: Verify Environment Variables

```bash
# From project root
docker exec concert_backend_dev env | grep -E "ENVIRONMENT|SSL_|JAMBASE|TICKETMASTER|GROQ"
```

**Expected outcome:**
Should see:
```
ENVIRONMENT=development
SSL_ENABLED=true
SSL_CERT_PATH=/app/ssl/server.crt
SSL_KEY_PATH=/app/ssl/server.key
JAMBASE_API_URL=https://jambase_provider:8002
TICKETMASTER_API_URL=https://ticketmaster_provider:8001
GROQ_API_URL=https://groq_provider:8003
```

---

### Step 12: Test Provider Services Individually

**Ticketmaster Provider:**
```bash
curl -k "https://localhost:8001/search?city=Boston"
```

**Jambase Provider:**
```bash
curl -k "https://localhost:8002/search?city=Boston"
```

**Groq Provider:**
```bash
curl -k "https://localhost:8003/health"
```

**Expected outcome:**
- Each endpoint returns a valid response
- No SSL or connection errors

---

### Step 13: Verify Docker Network Communication

```bash
# Check that containers can reach each other
docker exec concert_backend_dev ping -c 2 ticketmaster_provider
docker exec concert_backend_dev ping -c 2 jambase_provider
docker exec concert_backend_dev ping -c 2 groq_provider
```

**Expected outcome:**
- All pings succeed
- Shows response times

---

### Step 14: Check Container Resource Usage

```bash
docker stats --no-stream
```

**Expected outcome:**
- All containers show reasonable CPU/memory usage
- No container using excessive resources
- Memory usage should be stable

---

### Step 15: Test Frontend-Backend Integration

1. **Navigate to:** https://localhost (accept certificate warning)
2. **In the application:**
   - Try searching for concerts in a city
   - Check that results load
   - Verify no errors in browser console (F12)

**Expected outcome:**
- Search functionality works
- Data loads from backend
- No CORS errors
- No SSL errors in console

---

## Cleanup / Stop Environment

```bash
cd src
docker-compose -f docker-compose.dev.yml down
```

**Expected outcome:**
- All containers stop gracefully
- Networks are removed
- No error messages

---

## Common Issues and Solutions

### Issue: "Docker daemon not running"
**Solution:** Start Docker Desktop application

### Issue: Port already in use (80, 443, 8443, etc.)
**Solution:**
```bash
# Stop any services using these ports
docker-compose -f docker-compose.dev.yml down
# Or find and kill the process using the port
lsof -ti:8443 | xargs kill -9  # macOS/Linux
```

### Issue: Certificate errors in logs
**Solution:**
```bash
# Regenerate certificates
cd ssl
rm -rf dev/
./generate-dev-certs.sh
cd ../src
docker-compose -f docker-compose.dev.yml restart
```

### Issue: "FileNotFoundError" for certificates
**Solution:**
```bash
# Rebuild without cache
./start-dev.sh --clean --yes
```

### Issue: Backend can't connect to providers
**Solution:**
Check that `ENVIRONMENT=development` is set:
```bash
docker exec concert_backend_dev env | grep ENVIRONMENT
```

### Issue: Frontend shows blank page
**Solution:**
```bash
# Check frontend logs
docker-compose -f docker-compose.dev.yml logs frontend
# Rebuild frontend without cache
docker-compose -f docker-compose.dev.yml up --build --force-recreate frontend
```

---

## Success Criteria

✅ All 15 steps completed without errors
✅ All containers running and healthy
✅ Frontend accessible via HTTP and HTTPS
✅ Backend API responding correctly
✅ All provider services responding
✅ SSL certificates generated and working
✅ Inter-service communication functioning
✅ No SSL verification errors in logs

If all criteria are met, your development environment is working correctly!

---

## Additional Verification (Optional)

### Check Certificate Expiration
```bash
openssl x509 -in ssl/dev/server.crt -noout -enddate
```

### View All Container Logs
```bash
cd src
docker-compose -f docker-compose.dev.yml logs -f
```

### Test with Different Cities
```bash
curl -k "https://localhost:8443/search?city=NewYork"
curl -k "https://localhost:8443/search?city=LosAngeles"
curl -k "https://localhost:8443/search?city=Chicago"
```

### Monitor Real-time Logs
```bash
# In separate terminal windows, monitor each service
docker-compose -f docker-compose.dev.yml logs -f backend
docker-compose -f docker-compose.dev.yml logs -f frontend
docker-compose -f docker-compose.dev.yml logs -f ticketmaster_provider
```
