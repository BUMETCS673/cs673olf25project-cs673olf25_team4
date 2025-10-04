# GitHub Actions Automated HTTPS Deployment

## Overview

The BeatMap application uses GitHub Actions for automated deployment with HTTPS support. Simply push to the appropriate branch, and the deployment happens automatically on the respective EC2 server.

---

## Deployment Workflows

### Test Server (testbeatmap.com)
**Workflow:** `.github/workflows/deploy-test.yml`
**Trigger:** Push to `test` branch
**Domain:** testbeatmap.com (18.224.92.5)

```bash
# Deploy to test server
git checkout test
git merge your-feature-branch
git push origin test
```

### Production Server (beatmap.live)
**Workflow:** `.github/workflows/deploy.yml`
**Trigger:** Successful build on `main` branch
**Domain:** beatmap.live

```bash
# Deploy to production
git checkout main
git merge your-feature-branch
git push origin main
```

---

## What the Workflows Do Automatically

### 1. **Environment Setup**
- ✅ Installs Git and Certbot on EC2 server
- ✅ Creates environment file with API keys from GitHub Secrets
- ✅ Clones repository from appropriate branch

### 2. **SSL Certificate Management**
- ✅ Checks if SSL certificates exist
- ✅ Generates Let's Encrypt certificates if missing
- ✅ Checks certificate expiration (renews if <7 days)
- ✅ Validates certificate configuration

### 3. **Application Deployment**
- ✅ Creates backup of current deployment
- ✅ Stops existing containers gracefully
- ✅ Builds new Docker images with SSL support
- ✅ Starts containers with HTTPS configuration
- ✅ Uses `docker-compose.prod.yml` for SSL-enabled deployment

### 4. **Health Checks**
- ✅ Waits for services to start (30-45 seconds)
- ✅ Tests frontend HTTPS connectivity
- ✅ Tests backend API health endpoint
- ✅ Reports health status in workflow logs

### 5. **Rollback (Production Only)**
- ✅ Creates timestamped backup before deployment
- ✅ Automatically rolls back if SSL setup fails
- ✅ Backup available for manual rollback if needed

---

## Monitoring Deployments

### View Workflow Status

1. Go to your repository on GitHub
2. Click **Actions** tab
3. Select the deployment workflow
4. View real-time logs

### Workflow Logs Show:

```
════════════════════════════════════════════════
  Deploying Test Server with HTTPS Support
  Domain: testbeatmap.com
════════════════════════════════════════════════
▶ Checking prerequisites...
▶ Checking SSL certificates...
✓ SSL certificates found
Certificate expires in 75 days
▶ Deploying application with HTTPS...
▶ Performing health checks...
✓ Backend service is healthy
✓ Frontend service is healthy
════════════════════════════════════════════════
  ✓ Test Server Deployment Complete
  Access: https://testbeatmap.com
════════════════════════════════════════════════
```

---

## First-Time Deployment

### Initial SSL Certificate Setup

The first time you deploy to a server, the workflow will:
1. Detect no SSL certificates exist
2. Run the SSL setup script automatically
3. Obtain Let's Encrypt certificates
4. Configure auto-renewal
5. Complete deployment with HTTPS

**Note:** First deployment may take 2-3 minutes longer for SSL setup.

---

## Required GitHub Secrets

Ensure these secrets are configured in your repository:

### API Keys (All Deployments)
- `JAMBASE_API_KEY` - JamBase API key
- `TM_API_KEY` - Ticketmaster API key
- `TM_API_SECRET` - Ticketmaster API secret
- `GROQ_API_KEY` - Groq API key

### Server Access
- `EC2_HOST_TEST` - Test server IP (testbeatmap.com)
- `EC2_HOST` - Production server IP (beatmap.live)
- `EC2_DEPLOY_KEY` - SSH private key for EC2 access

### Setting Secrets

1. Go to repository **Settings**
2. Click **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with its value

---

## Deployment Process

### Test Server Deployment

1. **Push to `test` branch:**
   ```bash
   git push origin test
   ```

2. **Automatic workflow steps:**
   - Clone repository on EC2
   - Check/generate SSL certificates for testbeatmap.com
   - Deploy using `docker-compose.prod.yml`
   - Verify HTTPS connectivity

3. **Access application:**
   - Frontend: https://testbeatmap.com
   - Backend: https://testbeatmap.com:8443

### Production Deployment

1. **Push to `main` branch:**
   ```bash
   git push origin main
   ```

2. **Build workflow runs first**
   - Runs tests and builds
   - If successful, triggers deployment

3. **Automatic deployment steps:**
   - Create backup of current deployment
   - Clone repository on EC2
   - Check/generate SSL certificates for beatmap.live
   - Deploy using `docker-compose.prod.yml`
   - Run health checks
   - Rollback if deployment fails

4. **Access application:**
   - Frontend: https://beatmap.live
   - Backend: https://beatmap.live:8443

---

## SSL Certificate Lifecycle

### Automatic Certificate Generation

On first deployment or if certificates are missing:

```
▶ Checking SSL certificates...
SSL certificates not found. Generating...
Running SSL setup script...
✓ Certificates obtained from Let's Encrypt
✓ Certificates saved to /etc/letsencrypt/live/[domain]/
✓ Auto-renewal configured
```

### Automatic Certificate Renewal

On each deployment, the workflow checks expiration:

```
▶ Checking SSL certificates...
✓ SSL certificates found
Certificate expires in 75 days
```

If expiring within 7 days:

```
Certificate expires in 5 days
Certificate expiring soon. Renewing...
✓ Certificate renewed
```

### Manual Certificate Renewal

If needed, SSH to server and run:

```bash
ssh ec2-user@testbeatmap.com
sudo certbot renew --force-renewal
sudo docker-compose -f ~/cs673olf25project-cs673olf25_team4/src/docker-compose.prod.yml restart
```

---

## Troubleshooting

### Workflow Fails at SSL Setup

**Symptoms:**
```
SSL certificates not found. Generating...
❌ SSL setup failed. Attempting deployment anyway...
```

**Causes:**
- DNS not pointing to server IP
- Port 80 blocked (Let's Encrypt requires port 80)
- Rate limiting from Let's Encrypt

**Solutions:**
1. Verify DNS: `dig +short testbeatmap.com`
2. Check firewall rules allow port 80
3. Wait 1 hour if rate limited, then retry

### Workflow Fails at Health Checks

**Symptoms:**
```
⚠️  Backend health check failed (may still be starting)
⚠️  Frontend health check failed (may still be starting)
```

**Possible Causes:**
- Services need more time to start
- SSL certificates not mounted correctly
- Environment variables missing

**Solutions:**
1. SSH to server and check logs:
   ```bash
   ssh ec2-user@testbeatmap.com
   cd ~/cs673olf25project-cs673olf25_team4/src
   sudo docker-compose -f docker-compose.prod.yml logs
   ```

2. Check containers are running:
   ```bash
   sudo docker-compose -f docker-compose.prod.yml ps
   ```

3. Manually test health endpoints:
   ```bash
   curl https://testbeatmap.com
   curl https://testbeatmap.com:8443/health
   ```

### Production Deployment Rollback

**Automatic Rollback:**
If SSL setup fails in production, workflow automatically rolls back to backup.

**Manual Rollback:**
```bash
ssh ec2-user@beatmap.live
cd /home/ec2-user

# Find backup
ls -la backups/

# Stop current deployment
sudo docker-compose -f cs673olf25project-cs673olf25_team4/src/docker-compose.prod.yml down

# Start from backup
sudo docker-compose -f backups/prod_YYYYMMDD_HHMMSS/docker-compose.backup.yml up -d
```

---

## Workflow Comparison

| Feature | Test Server (`test` branch) | Production (`main` branch) |
|---------|----------------------------|----------------------------|
| **Domain** | testbeatmap.com | beatmap.live |
| **Trigger** | Push to `test` | Build success on `main` |
| **SSL Certs** | Let's Encrypt (Production) | Let's Encrypt (Production) |
| **Backup** | Optional | Automatic |
| **Rollback** | Manual if needed | Automatic on SSL failure |
| **Health Checks** | Yes | Yes (more comprehensive) |
| **Deployment Time** | 2-3 minutes | 3-5 minutes |

---

## Best Practices

### 1. **Test Before Production**
Always deploy to test server first:
```bash
git checkout test
git merge feature-branch
git push origin test
# Verify at https://testbeatmap.com
# If successful, merge to main
```

### 2. **Monitor Workflow Logs**
- Watch the Actions tab during deployment
- Check for SSL certificate status
- Verify health checks pass

### 3. **Verify Deployment**
After deployment completes:
```bash
# Check test server
curl -I https://testbeatmap.com

# Check production
curl -I https://beatmap.live
```

### 4. **SSL Certificate Monitoring**
Set up monitoring for certificate expiration:
- Let's Encrypt certs expire in 90 days
- Workflow checks and renews if <7 days
- Manual check: `sudo certbot certificates`

### 5. **Keep Secrets Updated**
- Rotate API keys regularly
- Update GitHub Secrets when keys change
- Test after updating secrets

---

## Deployment Checklist

### Before Deploying

- [ ] Code tested locally
- [ ] All tests passing
- [ ] API keys configured in GitHub Secrets
- [ ] DNS pointing to correct IP
- [ ] Feature branch merged to `test` or `main`

### After Deployment

- [ ] Workflow completed successfully
- [ ] Health checks passed
- [ ] Application accessible via HTTPS
- [ ] No SSL warnings in browser
- [ ] API endpoints responding correctly
- [ ] Check logs for any errors

---

## Manual Deployment Override

If you need to deploy manually (bypassing GitHub Actions):

### SSH to Server
```bash
ssh ec2-user@testbeatmap.com  # or beatmap.live
```

### Run Deployment Script
```bash
cd /home/ec2-user/cs673olf25project-cs673olf25_team4
sudo bash deploy-staging.sh    # for test server
# or
sudo bash deploy-prod.sh       # for production
```

**Note:** Manual deployment requires sudo privileges and all environment variables.

---

## Advanced Configuration

### Customize Deployment

Edit workflow files to customize:
- `.github/workflows/deploy-test.yml` - Test server
- `.github/workflows/deploy.yml` - Production

### Add Deployment Notifications

Add Slack/Discord notifications to workflow:
```yaml
- name: Notify on deployment
  if: success()
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -d '{"text":"Deployment to test server successful!"}'
```

### Adjust Health Check Timeout

Change sleep duration in workflow:
```yaml
echo "▶ Waiting for services to start..."
sleep 60  # Increase if services need more time
```

---

## Support

### View Workflow Runs
- GitHub Repository → Actions tab
- Filter by workflow name
- Click run to see detailed logs

### Common Issues
- SSL certificate generation failures → Check DNS
- Health check failures → Check container logs
- Deployment timeouts → Increase sleep duration

### Get Help
- Check workflow logs for error messages
- SSH to server and inspect Docker logs
- Review server firewall rules
- Verify GitHub Secrets are set correctly

---

*Last Updated: September 30, 2025*
*Automated deployment with HTTPS support*