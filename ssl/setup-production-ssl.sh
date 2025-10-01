#!/bin/bash

# SSL Certificate Setup for beatmap.live (Production)
# This script obtains and configures SSL certificates for the production server
#
# Usage: ./setup-production-ssl.sh [--staging] [--force-renew]
#
# Options:
#   --staging     Use Let's Encrypt staging environment (for testing)
#   --force-renew Force renewal of existing certificates
#   --dry-run     Test the renewal process without making changes

set -euo pipefail

# Configuration
DOMAIN="beatmap.live"
EMAIL="admin@beatmap.live"  # Update with your email
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
BACKUP_DIR="/etc/ssl/backups"
APP_SSL_DIR="/app/ssl/production"
LOG_FILE="/var/log/ssl-setup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

info() { log "INFO" "${BLUE}$*${NC}"; }
warn() { log "WARN" "${YELLOW}$*${NC}"; }
error() { log "ERROR" "${RED}$*${NC}"; }
success() { log "SUCCESS" "${GREEN}$*${NC}"; }

# Parse command line arguments
STAGING=""
FORCE_RENEW=""
DRY_RUN=""

for arg in "$@"; do
    case $arg in
        --staging)
            STAGING="--staging"
            info "Using Let's Encrypt staging environment"
            ;;
        --force-renew)
            FORCE_RENEW="--force-renewal"
            info "Force renewal enabled"
            ;;
        --dry-run)
            DRY_RUN="--dry-run"
            info "Dry run mode enabled"
            ;;
        *)
            error "Unknown option: $arg"
            echo "Usage: $0 [--staging] [--force-renew] [--dry-run]"
            exit 1
            ;;
    esac
done

# Pre-production safety checks
production_safety_checks() {
    info "Running production safety checks..."

    # Check if we're really in production
    warn "⚠️  PRODUCTION DEPLOYMENT WARNING ⚠️"
    warn "You are about to obtain SSL certificates for PRODUCTION domain: ${DOMAIN}"
    warn "This will:"
    warn "  - Generate real SSL certificates (not staging)"
    warn "  - Potentially affect live traffic"
    warn "  - Create permanent certificate transparency logs"
    warn ""

    if [[ -z "${STAGING}" ]] && [[ -z "${FORCE_RENEW}" ]]; then
        read -p "Are you sure you want to proceed with PRODUCTION certificate generation? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            info "Production certificate generation cancelled by user"
            exit 0
        fi
    fi

    # Check DNS configuration
    info "Checking DNS configuration for ${DOMAIN}..."
    local dns_ip=$(dig +short ${DOMAIN} A | head -1)
    local public_ip=$(curl -s http://checkip.amazonaws.com/ || curl -s http://ipinfo.io/ip || echo "unknown")

    if [[ -n "$dns_ip" ]]; then
        info "DNS resolves ${DOMAIN} to: ${dns_ip}"
        info "Current public IP: ${public_ip}"

        if [[ "$dns_ip" != "$public_ip" ]]; then
            warn "DNS IP (${dns_ip}) does not match public IP (${public_ip})"
            warn "This may cause certificate validation to fail"

            if [[ -z "${FORCE_RENEW}" ]]; then
                read -p "Continue anyway? (yes/no): " continue_confirm
                if [[ "$continue_confirm" != "yes" ]]; then
                    error "Stopping due to DNS mismatch"
                    exit 1
                fi
            fi
        else
            success "DNS configuration looks correct"
        fi
    else
        error "Could not resolve DNS for ${DOMAIN}"
        exit 1
    fi

    # Check port 80 accessibility
    info "Checking port 80 accessibility..."
    if nc -z -w5 ${DOMAIN} 80; then
        success "Port 80 is accessible"
    else
        warn "Port 80 may not be accessible from the internet"
        warn "Let's Encrypt requires port 80 for domain validation"
    fi

    success "Production safety checks completed"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Install certbot if not present
install_certbot() {
    info "Checking certbot installation..."

    if ! command -v certbot &> /dev/null; then
        info "Installing certbot..."

        # Detect OS and install accordingly
        if [[ -f /etc/redhat-release ]]; then
            # RHEL/CentOS/Amazon Linux
            yum update -y
            yum install -y certbot
        elif [[ -f /etc/debian_version ]]; then
            # Debian/Ubuntu
            apt-get update
            apt-get install -y certbot
        else
            error "Unsupported operating system"
            exit 1
        fi

        success "Certbot installed successfully"
    else
        success "Certbot is already installed"
    fi
}

# Create necessary directories
create_directories() {
    info "Creating SSL directories..."

    mkdir -p "${BACKUP_DIR}"
    mkdir -p "${APP_SSL_DIR}"
    mkdir -p /var/log

    # Set proper permissions
    chmod 755 "${BACKUP_DIR}"
    chmod 755 "${APP_SSL_DIR}"

    success "SSL directories created"
}

# Backup existing certificates
backup_certificates() {
    if [[ -d "${CERT_DIR}" ]] && [[ -z "${FORCE_RENEW}" ]]; then
        info "Backing up existing certificates..."

        local backup_name="production-$(date +%Y%m%d-%H%M%S)"
        local backup_path="${BACKUP_DIR}/${backup_name}"

        cp -r "${CERT_DIR}" "${backup_path}"
        success "Certificates backed up to ${backup_path}"
    fi
}

# Stop services that might interfere with certificate generation
stop_services() {
    info "Stopping services on port 80..."

    # Stop nginx if running
    if systemctl is-active --quiet nginx; then
        systemctl stop nginx
        info "Stopped nginx"
    fi

    # Stop apache if running
    if systemctl is-active --quiet apache2; then
        systemctl stop apache2
        info "Stopped apache2"
    fi

    # Stop any docker containers using port 80
    if command -v docker &> /dev/null; then
        local containers=$(docker ps --filter "publish=80" --format "{{.Names}}" || true)
        if [[ -n "$containers" ]]; then
            info "Stopping Docker containers on port 80: $containers"
            echo "$containers" | xargs -r docker stop
        fi
    fi
}

# Start services after certificate generation
start_services() {
    info "Starting services..."

    # Start nginx if it was running
    if systemctl is-enabled --quiet nginx 2>/dev/null; then
        systemctl start nginx
        info "Started nginx"
    fi

    # Start apache if it was running
    if systemctl is-enabled --quiet apache2 2>/dev/null; then
        systemctl start apache2
        info "Started apache2"
    fi
}

# Obtain SSL certificate
obtain_certificate() {
    info "Obtaining SSL certificate for ${DOMAIN}..."

    local cmd="certbot certonly --standalone"
    cmd+=" --non-interactive"
    cmd+=" --agree-tos"
    cmd+=" --email ${EMAIL}"
    cmd+=" -d ${DOMAIN}"

    if [[ -n "${STAGING}" ]]; then
        cmd+=" ${STAGING}"
    fi

    if [[ -n "${FORCE_RENEW}" ]]; then
        cmd+=" ${FORCE_RENEW}"
    fi

    if [[ -n "${DRY_RUN}" ]]; then
        cmd+=" ${DRY_RUN}"
    fi

    info "Running: ${cmd}"

    if eval "${cmd}"; then
        if [[ -z "${DRY_RUN}" ]]; then
            success "SSL certificate obtained successfully"
        else
            success "Dry run completed successfully"
        fi
    else
        error "Failed to obtain SSL certificate"
        return 1
    fi
}

# Copy certificates to application directory
copy_certificates() {
    if [[ -n "${DRY_RUN}" ]]; then
        info "Skipping certificate copy (dry run mode)"
        return 0
    fi

    if [[ ! -d "${CERT_DIR}" ]]; then
        error "Certificate directory ${CERT_DIR} does not exist"
        return 1
    fi

    info "Copying certificates to application directory..."

    # Copy certificate files
    cp "${CERT_DIR}/fullchain.pem" "${APP_SSL_DIR}/server.crt"
    cp "${CERT_DIR}/privkey.pem" "${APP_SSL_DIR}/server.key"
    cp "${CERT_DIR}/chain.pem" "${APP_SSL_DIR}/chain.pem"

    # Set proper permissions
    chmod 644 "${APP_SSL_DIR}/server.crt"
    chmod 600 "${APP_SSL_DIR}/server.key"
    chmod 644 "${APP_SSL_DIR}/chain.pem"

    # Set ownership (assuming app runs as www-data or similar)
    if id "www-data" &>/dev/null; then
        chown www-data:www-data "${APP_SSL_DIR}"/*
    elif id "nginx" &>/dev/null; then
        chown nginx:nginx "${APP_SSL_DIR}"/*
    fi

    success "Certificates copied to ${APP_SSL_DIR}"
}

# Validate certificate
validate_certificate() {
    if [[ -n "${DRY_RUN}" ]]; then
        info "Skipping certificate validation (dry run mode)"
        return 0
    fi

    info "Validating certificate..."

    local cert_file="${APP_SSL_DIR}/server.crt"

    if [[ ! -f "${cert_file}" ]]; then
        error "Certificate file not found: ${cert_file}"
        return 1
    fi

    # Check certificate validity
    local expiry_date=$(openssl x509 -in "${cert_file}" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "${expiry_date}" +%s)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

    info "Certificate expires on: ${expiry_date}"
    info "Days until expiry: ${days_until_expiry}"

    if [[ ${days_until_expiry} -lt 30 ]]; then
        warn "Certificate expires in less than 30 days!"
    fi

    # Test certificate with openssl
    if openssl x509 -in "${cert_file}" -text -noout > /dev/null; then
        success "Certificate is valid"
    else
        error "Certificate validation failed"
        return 1
    fi

    # Check if certificate matches domain
    local cert_domain=$(openssl x509 -in "${cert_file}" -noout -subject | grep -oP 'CN=\K[^,]*')
    if [[ "${cert_domain}" == "${DOMAIN}" ]]; then
        success "Certificate domain matches: ${cert_domain}"
    else
        warn "Certificate domain mismatch: expected ${DOMAIN}, got ${cert_domain}"
    fi
}

# Create certificate info file
create_cert_info() {
    if [[ -n "${DRY_RUN}" ]]; then
        return 0
    fi

    info "Creating certificate information file..."

    local info_file="${APP_SSL_DIR}/cert-info.txt"
    local cert_file="${APP_SSL_DIR}/server.crt"

    cat > "${info_file}" << EOF
# SSL Certificate Information for ${DOMAIN} (PRODUCTION)
# Generated on: $(date)

Domain: ${DOMAIN}
Certificate Path: ${cert_file}
Private Key Path: ${APP_SSL_DIR}/server.key
Chain Path: ${APP_SSL_DIR}/chain.pem

# Certificate Details:
$(openssl x509 -in "${cert_file}" -text -noout | head -20)

# Expiry Information:
Not After: $(openssl x509 -in "${cert_file}" -noout -enddate | cut -d= -f2)

# Renewal Command:
sudo $0 --force-renew

# Auto-renewal is configured via cron job
EOF

    success "Certificate info saved to ${info_file}"
}

# Test HTTPS connectivity
test_https() {
    if [[ -n "${DRY_RUN}" ]]; then
        info "Skipping HTTPS test (dry run mode)"
        return 0
    fi

    info "Testing HTTPS connectivity..."

    # Wait a moment for services to start
    sleep 5

    # Test local HTTPS connection
    if curl -s -k "https://localhost" > /dev/null; then
        success "Local HTTPS test passed"
    else
        warn "Local HTTPS test failed (this may be normal if application isn't running)"
    fi

    # Test domain HTTPS connection
    if curl -s --connect-timeout 10 "https://${DOMAIN}" > /dev/null; then
        success "Domain HTTPS test passed: https://${DOMAIN}"
    else
        warn "Domain HTTPS test failed (check DNS configuration and firewall)"
    fi
}

# Setup auto-renewal with production-specific settings
setup_auto_renewal() {
    info "Setting up automatic certificate renewal for production..."

    # Create renewal script with production safety measures
    local renewal_script="/usr/local/bin/renew-production-ssl.sh"
    cat > "${renewal_script}" << 'EOF'
#!/bin/bash
# Automatic SSL renewal script for beatmap.live (PRODUCTION)

LOG_FILE="/var/log/ssl-renewal.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "${LOG_FILE}"
}

log "Starting production SSL renewal check..."

# Run renewal with minimal output
if /usr/bin/certbot renew --quiet --deploy-hook "/usr/local/bin/deploy-production-certs.sh"; then
    log "Certificate renewal check completed successfully"
else
    log "ERROR: Certificate renewal failed"
    # Send alert (you can add email notification here)
    echo "Production SSL renewal failed on $(hostname) at $(date)" | mail -s "SSL Renewal Failure" admin@beatmap.live || true
fi
EOF

    chmod +x "${renewal_script}"

    # Create certificate deployment script
    local deploy_script="/usr/local/bin/deploy-production-certs.sh"
    cat > "${deploy_script}" << 'EOF'
#!/bin/bash
# Deploy renewed certificates for production

DOMAIN="beatmap.live"
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
APP_SSL_DIR="/app/ssl/production"
LOG_FILE="/var/log/ssl-renewal.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "${LOG_FILE}"
}

if [[ -f "${CERT_DIR}/fullchain.pem" ]]; then
    log "Deploying renewed certificates..."

    # Backup old certificates
    if [[ -f "${APP_SSL_DIR}/server.crt" ]]; then
        cp "${APP_SSL_DIR}/server.crt" "${APP_SSL_DIR}/server.crt.backup.$(date +%s)"
        cp "${APP_SSL_DIR}/server.key" "${APP_SSL_DIR}/server.key.backup.$(date +%s)"
    fi

    # Copy new certificates
    cp "${CERT_DIR}/fullchain.pem" "${APP_SSL_DIR}/server.crt"
    cp "${CERT_DIR}/privkey.pem" "${APP_SSL_DIR}/server.key"
    cp "${CERT_DIR}/chain.pem" "${APP_SSL_DIR}/chain.pem"

    # Set permissions
    chmod 644 "${APP_SSL_DIR}/server.crt"
    chmod 600 "${APP_SSL_DIR}/server.key"
    chmod 644 "${APP_SSL_DIR}/chain.pem"

    # Restart services gracefully
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
        log "Reloaded nginx with new certificates"
    fi

    # Restart Docker containers if running
    if command -v docker &> /dev/null; then
        if docker ps --format "{{.Names}}" | grep -q "beatmap_frontend"; then
            docker restart beatmap_frontend
            log "Restarted beatmap_frontend container"
        fi

        if docker ps --format "{{.Names}}" | grep -q "concert_backend"; then
            docker restart concert_backend
            log "Restarted concert_backend container"
        fi
    fi

    log "Certificate deployment completed successfully"
else
    log "ERROR: New certificate not found at ${CERT_DIR}/fullchain.pem"
fi
EOF

    chmod +x "${deploy_script}"

    # Add to root's crontab if not already present
    local cron_job="0 3 * * * ${renewal_script} >> /var/log/ssl-renewal.log 2>&1"

    if ! crontab -l 2>/dev/null | grep -q "renew-production-ssl"; then
        (crontab -l 2>/dev/null; echo "${cron_job}") | crontab -
        success "Production auto-renewal cron job added"
    else
        info "Auto-renewal cron job already exists"
    fi

    success "Production renewal scripts created:"
    info "  Renewal script: ${renewal_script}"
    info "  Deploy script: ${deploy_script}"
}

# Main execution
main() {
    info "Starting SSL certificate setup for ${DOMAIN} (PRODUCTION)"

    check_root
    production_safety_checks
    install_certbot
    create_directories
    backup_certificates
    stop_services

    if obtain_certificate; then
        copy_certificates
        validate_certificate
        create_cert_info
        setup_auto_renewal
        start_services
        test_https

        success "🎉 Production SSL certificate setup completed successfully!"
        info "Certificate files are available in: ${APP_SSL_DIR}"
        info "To use in your application, set:"
        info "  SSL_CERT_PATH=${APP_SSL_DIR}/server.crt"
        info "  SSL_KEY_PATH=${APP_SSL_DIR}/server.key"

        if [[ -z "${STAGING}" ]] && [[ -z "${DRY_RUN}" ]]; then
            success "🌐 Your production site should now be available at: https://${DOMAIN}"
            info "🔍 Check SSL rating at: https://www.ssllabs.com/ssltest/analyze.html?d=${DOMAIN}"
            info "📊 Monitor certificate at: https://crt.sh/?q=${DOMAIN}"
        fi
    else
        error "Production SSL certificate setup failed"
        start_services
        exit 1
    fi
}

# Run main function
main "$@"