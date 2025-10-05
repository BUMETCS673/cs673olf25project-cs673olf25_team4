# 🚀 HTTPS Deployment - Start Here

## Quick Start Guide

The BeatMap application now supports **fully automated HTTPS deployment** via GitHub Actions.

---

## ✅ Everything is Ready!

All HTTPS infrastructure, SSL certificate management, and automated deployment workflows are implemented and ready to use.

---

## 🎯 How to Deploy

### Test Server (testbeatmap.com)

**Simply push to the `test` branch:**

```bash
git checkout test
git merge your-branch
git push origin test
```

**That's it!** GitHub Actions will automatically:
- ✅ Generate SSL certificates (first time)
- ✅ Deploy with HTTPS support
- ✅ Run health checks
- ✅ Make available at https://testbeatmap.com

### Production Server (beatmap.live)

**Push to the `main` branch:**

```bash
git checkout main
git merge your-branch
git push origin main
```

**GitHub Actions automatically:**
- ✅ Creates backup
- ✅ Generates SSL certificates (first time)
- ✅ Deploys with HTTPS support
- ✅ Runs health checks
- ✅ Rolls back on failure
- ✅ Makes available at https://beatmap.live

---

## 📋 What You Need to Know

### 1. No Manual Steps Required
- SSL certificates are generated automatically
- Certificate renewal is automatic
- Deployment happens on git push
- Health checks run automatically

### 2. Monitor Deployment
- Go to GitHub → Actions tab
- Watch your deployment in real-time
- See detailed logs and status

### 3. Access Your Application
- **Test:** https://testbeatmap.com
- **Production:** https://beatmap.live

### 4. Check Status
```bash
# Test server health
curl https://testbeatmap.com/health

# Production health
curl https://beatmap.live/health
```

---

## 📚 Documentation

### Primary Guides
1. **[IMPLEMENTATION-SUMMARY.md](IMPLEMENTATION-SUMMARY.md)** - Complete implementation overview
2. **[GITHUB-ACTIONS-DEPLOYMENT.md](GITHUB-ACTIONS-DEPLOYMENT.md)** - Detailed deployment guide
3. **[DEPLOYMENT-README.md](DEPLOYMENT-README.md)** - All deployment options

### Reference
- **[../../HTTPS.md](../../HTTPS.md)** - Implementation roadmap and status
- **[TESTSERVER-DEPLOYMENT-GUIDE.md](TESTSERVER-DEPLOYMENT-GUIDE.md)** - Manual deployment (backup)
- **[DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md)** - Quick reference

---

## ⚙️ GitHub Secrets (Already Configured)

These should already be set in your repository:

- `JAMBASE_API_KEY` - JamBase API key
- `TM_API_KEY` - Ticketmaster API key
- `TM_API_SECRET` - Ticketmaster secret
- `GROQ_API_KEY` - Groq API key
- `EC2_HOST_TEST` - Test server address
- `EC2_HOST` - Production server address
- `EC2_DEPLOY_KEY` - SSH key for servers

---

## 🔐 SSL Certificates

### Automatic Management
- ✅ First deployment: Certificates generated automatically
- ✅ Each deployment: Expiration checked automatically
- ✅ Renewal: Automatic if <7 days from expiration
- ✅ Background: Certbot checks daily, renews at 30 days

### Certificate Authority
- Let's Encrypt (free, trusted, automatic renewal)
- Valid for 90 days
- Auto-renewed every 60 days

---

## 🎯 Next Steps

### For Test Server (Immediate)

1. **Push to test branch:**
   ```bash
   git push origin test
   ```

2. **Watch deployment:**
   - GitHub → Actions → Deploy to EC2 - TEST (HTTPS)

3. **Verify:**
   ```bash
   curl -I https://testbeatmap.com
   ```

4. **Test in browser:**
   - Visit https://testbeatmap.com
   - Should show no SSL warnings
   - All features should work

5. **Run SSL Labs test:**
   - https://www.ssllabs.com/ssltest/analyze.html?d=testbeatmap.com
   - Target: A or A+ grade

### For Production (When Ready)

1. Set up production EC2 infrastructure (if not done)
2. Configure DNS for beatmap.live
3. Push to main branch
4. Monitor deployment
5. Verify at https://beatmap.live

---

## 🚨 If Something Goes Wrong

### Deployment Fails
1. Check GitHub Actions logs (Actions tab)
2. Look for error messages
3. Common issues:
   - DNS not configured → Fix DNS settings
   - Port 80 blocked → Open firewall
   - Secrets missing → Add to GitHub settings

### Application Not Accessible
1. Check if containers are running:
   ```bash
   ssh ec2-user@testbeatmap.com
   docker ps
   ```

2. Check logs:
   ```bash
   cd ~/cs673olf25project-cs673olf25_team4/src
   sudo docker-compose -f docker-compose.prod.yml logs
   ```

3. Review workflow logs in GitHub Actions

### SSL Certificate Issues
- First deployment takes 2-3 minutes for certificate generation
- Certificates require port 80 to be accessible
- DNS must point to correct IP address

**See:** [GITHUB-ACTIONS-DEPLOYMENT.md](GITHUB-ACTIONS-DEPLOYMENT.md) for detailed troubleshooting.

---

## ✅ What's Included

### Infrastructure
- ✅ SSL/TLS certificate management (automated)
- ✅ Let's Encrypt integration
- ✅ Certificate auto-renewal

### Application
- ✅ Backend HTTPS support (FastAPI)
- ✅ Frontend HTTPS support (React/NGINX)
- ✅ Provider services HTTPS (Ticketmaster, JamBase, Groq)
- ✅ Security headers (HSTS, CSP, etc.)

### Deployment
- ✅ GitHub Actions automated deployment
- ✅ Health checks and verification
- ✅ Production backup and rollback
- ✅ Environment-specific configurations

### Docker
- ✅ Development environment (self-signed SSL)
- ✅ Production environment (Let's Encrypt SSL)
- ✅ All services SSL-enabled

---

## 💡 Key Points

1. **Automated Everything** - Just push to git, deployment handles the rest
2. **SSL is Automatic** - Certificates generated, renewed, and managed automatically
3. **Production Safe** - Backup created, rollback on failure
4. **Health Checked** - Every deployment verifies services are healthy
5. **Well Documented** - Multiple guides for different needs

---

## 📞 Support

### Documentation
- [IMPLEMENTATION-SUMMARY.md](IMPLEMENTATION-SUMMARY.md) - Complete overview
- [GITHUB-ACTIONS-DEPLOYMENT.md](GITHUB-ACTIONS-DEPLOYMENT.md) - Deployment guide
- [../../HTTPS.md](../../HTTPS.md) - Implementation status

### Troubleshooting
- Check GitHub Actions logs first
- Review workflow error messages
- SSH to server to check logs
- Verify DNS and firewall settings

---

## 🎉 You're All Set!

Everything is ready for HTTPS deployment. Simply push to the appropriate branch and let GitHub Actions handle the rest!

```bash
# Deploy to test server
git push origin test

# Deploy to production
git push origin main
```

**Happy deploying! 🚀**

---

*Last Updated: September 30, 2025*
*Status: Ready for deployment*