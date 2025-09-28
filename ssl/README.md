# SSL Certificate Management

This directory contains comprehensive scripts and tools for managing SSL certificates for the BeatMap application across all environments.

## 🚀 Quick Start

### Test Server (testbeatmap.com)
```bash
sudo ./setup-testbeatmap-ssl.sh
```

### Production Server (beatmap.live)
```bash
sudo ./setup-production-ssl.sh
```

### Monitor Certificates
```bash
./monitor-certificates.sh
```

## 📁 Directory Structure

```
ssl/
├── dev/                           # Development certificates (self-signed)
│   ├── server.crt                # Certificate file
│   ├── server.key                # Private key
│   └── dhparam.pem               # Diffie-Hellman parameters
├── testbeatmap/                   # Test server certificates
│   ├── server.crt                # Certificate file
│   ├── server.key                # Private key
│   ├── chain.pem                 # Certificate chain
│   └── cert-info.txt             # Certificate information
├── production/                    # Production certificates
│   ├── server.crt                # Certificate file
│   ├── server.key                # Private key
│   ├── chain.pem                 # Certificate chain
│   └── cert-info.txt             # Certificate information
├── generate-dev-certs.sh         # Generate development certificates
├── setup-testbeatmap-ssl.sh      # Setup test server SSL (testbeatmap.com)
├── setup-production-ssl.sh       # Setup production SSL (beatmap.live)
├── monitor-certificates.sh       # Monitor certificate health
├── deploy-certificates.sh        # Deploy certificates to services
└── README.md                     # This file
```

## 📋 Scripts Overview

### 🔧 Certificate Generation Scripts

#### `generate-dev-certs.sh`
Generates self-signed certificates for local development.

**Usage:**
```bash
./generate-dev-certs.sh
```

**Features:**
- Creates self-signed certificates for localhost
- Sets up proper directory structure
- Configures certificates for development use

#### `setup-testbeatmap-ssl.sh`
Obtains and configures SSL certificates for the test server.

**Usage:**
```bash
# Production certificates
sudo ./setup-testbeatmap-ssl.sh

# Test with staging (recommended first)
sudo ./setup-testbeatmap-ssl.sh --staging

# Force renewal
sudo ./setup-testbeatmap-ssl.sh --force-renew

# Dry run (test without changes)
sudo ./setup-testbeatmap-ssl.sh --dry-run
```

**Features:**
- Uses Let's Encrypt for free SSL certificates
- Automatic domain validation
- Configures auto-renewal
- Backup existing certificates
- Service management (stops/starts interfering services)
- Comprehensive validation and testing

#### `setup-production-ssl.sh`
Obtains and configures SSL certificates for the production server.

**Usage:**
```bash
# Production certificates (with safety checks)
sudo ./setup-production-ssl.sh

# Test with staging first (recommended)
sudo ./setup-production-ssl.sh --staging

# Force renewal
sudo ./setup-production-ssl.sh --force-renew
```

**Features:**
- Production safety checks and confirmations
- DNS validation before certificate generation
- Comprehensive backup procedures
- Production-grade auto-renewal setup
- Monitoring and alerting configuration

### 📊 Monitoring and Management Scripts

#### `monitor-certificates.sh`
Monitors certificate health and expiration for both domains.

**Usage:**
```bash
# Basic monitoring
./monitor-certificates.sh

# Custom alert threshold (default: 30 days)
./monitor-certificates.sh --alert-days 14

# Email alerts
./monitor-certificates.sh --email admin@beatmap.live
```

**Features:**
- Monitors both test and production certificates
- Checks certificate validity and expiration
- Tests HTTPS connectivity
- Generates comprehensive reports
- Email alerting support
- Syslog integration

#### `deploy-certificates.sh`
Deploys certificates to running services and applications.

**Usage:**
```bash
# Auto-detect environment
./deploy-certificates.sh

# Specific environment
./deploy-certificates.sh --environment production

# With service restart
./deploy-certificates.sh --restart-services

# With backup
./deploy-certificates.sh --backup --restart-services
```

**Features:**
- Auto-detects environment
- Deploys to NGINX, Docker containers
- Service restart management
- Certificate validation
- Deployment reporting

## 🔒 Security Features

### Certificate Validation
- ✅ Certificate and private key matching
- ✅ Certificate chain validation
- ✅ Expiration date checking
- ✅ Domain name validation

### File Security
- ✅ Proper file permissions (644 for certs, 600 for keys)
- ✅ Secure ownership (www-data/nginx)
- ✅ Backup procedures
- ✅ Access logging

### Auto-Renewal Security
- ✅ Staging environment testing
- ✅ Production safety checks
- ✅ Rollback procedures
- ✅ Monitoring and alerting

## 🌍 Environment Configuration

### Development Environment
```bash
SSL_ENABLED=true
SSL_CERT_PATH=/app/ssl/dev/server.crt
SSL_KEY_PATH=/app/ssl/dev/server.key
FORCE_HTTPS=false
HSTS_ENABLED=false
```

### Test Environment (testbeatmap.com)
```bash
SSL_ENABLED=true
SSL_CERT_PATH=/app/ssl/testbeatmap/server.crt
SSL_KEY_PATH=/app/ssl/testbeatmap/server.key
FORCE_HTTPS=true
HSTS_ENABLED=true
ENVIRONMENT=staging
```

### Production Environment (beatmap.live)
```bash
SSL_ENABLED=true
SSL_CERT_PATH=/app/ssl/production/server.crt
SSL_KEY_PATH=/app/ssl/production/server.key
FORCE_HTTPS=true
HSTS_ENABLED=true
HSTS_PRELOAD=true
ENVIRONMENT=production
```

## 🔄 Auto-Renewal Setup

### Test Server Auto-Renewal
```bash
# Cron job (automatically configured by setup script)
0 3 * * * /usr/local/bin/renew-testbeatmap-ssl.sh

# Manual renewal
sudo /usr/local/bin/renew-testbeatmap-ssl.sh
```

### Production Auto-Renewal
```bash
# Cron job (automatically configured by setup script)
0 3 * * * /usr/local/bin/renew-production-ssl.sh

# Manual renewal
sudo /usr/local/bin/renew-production-ssl.sh
```

## 📈 Monitoring Setup

### Daily Monitoring
Add to crontab for daily certificate monitoring:
```bash
# Daily certificate health check
0 9 * * * /path/to/ssl/monitor-certificates.sh --email admin@beatmap.live
```

### Log Files
- Certificate setup: `/var/log/ssl-setup.log`
- Certificate monitoring: `/var/log/cert-monitoring.log`
- Certificate renewal: `/var/log/ssl-renewal.log`

## 🚨 Troubleshooting

### Common Issues

#### 1. Certificate Generation Fails
```bash
# Check DNS configuration
dig testbeatmap.com A
dig beatmap.live A

# Test port 80 accessibility
nc -z testbeatmap.com 80
nc -z beatmap.live 80

# Check for conflicting services
sudo netstat -tlnp | grep :80
```

#### 2. Certificate Validation Errors
```bash
# Check certificate validity
openssl x509 -in /app/ssl/testbeatmap/server.crt -text -noout

# Verify certificate and key match
openssl x509 -in /app/ssl/testbeatmap/server.crt -pubkey -noout | openssl md5
openssl rsa -in /app/ssl/testbeatmap/server.key -pubout -noout | openssl md5
```

#### 3. HTTPS Connection Issues
```bash
# Test SSL handshake
echo | openssl s_client -connect testbeatmap.com:443

# Check certificate from client perspective
curl -vI https://testbeatmap.com
```

#### 4. Auto-Renewal Issues
```bash
# Test renewal manually
sudo certbot renew --dry-run

# Check renewal logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Verify cron jobs
sudo crontab -l | grep certbot
```

### Emergency Procedures

#### Certificate Expired
```bash
# Force renewal immediately
sudo ./setup-testbeatmap-ssl.sh --force-renew
sudo ./setup-production-ssl.sh --force-renew

# Deploy new certificates
sudo ./deploy-certificates.sh --restart-services
```

#### Rollback to Previous Certificate
```bash
# Find backups
ls -la /etc/ssl/backups/

# Restore from backup
sudo cp /etc/ssl/backups/BACKUP_NAME/* /app/ssl/production/

# Deploy restored certificates
sudo ./deploy-certificates.sh --restart-services
```

## 🔗 Integration

### Docker Integration
Certificates are automatically mounted into Docker containers via volume mounts:
```yaml
volumes:
  - ../ssl:/app/ssl:ro  # Read-only SSL certificates
```

### NGINX Integration
Certificates are automatically deployed to NGINX configuration:
```nginx
ssl_certificate /app/ssl/production/server.crt;
ssl_certificate_key /app/ssl/production/server.key;
```

### Application Integration
Use environment variables to configure SSL in your application:
```python
ssl_settings = SSLSettings()
if ssl_settings.enabled:
    uvicorn.run(app, ssl_certfile=ssl_settings.cert_path, ssl_keyfile=ssl_settings.key_path)
```

## 📞 Support

### Log Analysis
```bash
# View recent SSL setup logs
sudo tail -f /var/log/ssl-setup.log

# View certificate monitoring logs
sudo tail -f /var/log/cert-monitoring.log

# View renewal logs
sudo tail -f /var/log/ssl-renewal.log
```

### Health Checks
```bash
# Quick certificate health check
./monitor-certificates.sh

# Comprehensive system check
./deploy-certificates.sh --environment auto
```

### Emergency Contacts
- DNS Issues: Check with domain registrar
- Certificate Issues: Let's Encrypt community forum
- Application Issues: See main TROUBLESHOOTING.md

---

## 📚 Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [SSL Labs Best Practices](https://github.com/ssllabs/research/wiki/SSL-and-TLS-Deployment-Best-Practices)
- [OWASP Transport Layer Security](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html)
- Main project documentation: `../HTTPS-Roadmap.md`