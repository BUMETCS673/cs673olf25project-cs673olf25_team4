#!/bin/bash

# SSL Certificate Setup for testbeatmap.com
# This script obtains and configures SSL certificates for the test server
#
# Usage: ./setup-testbeatmap-ssl.sh [--staging] [--force-renew]
#
# Options:
#   --staging     Use Let's Encrypt staging environment (for testing)
#   --force-renew Force renewal of existing certificates
#   --dry-run     Test the renewal process without making changes

set -euo pipefail

# Configuration
DOMAIN="testbeatmap.com"
EMAIL="admin@testbeatmap.com"  # Update with your email
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
BACKUP_DIR="/etc/ssl/backups"
APP_SSL_DIR="/app/ssl/testbeatmap"
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

        local backup_name="testbeatmap-$(date +%Y%m%d-%H%M%S)"
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
# SSL Certificate Information for ${DOMAIN}
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

    # Test domain HTTPS connection (if DNS is configured)
    if curl -s --connect-timeout 10 "https://${DOMAIN}" > /dev/null; then
        success "Domain HTTPS test passed: https://${DOMAIN}"
    else
        warn "Domain HTTPS test failed (check DNS configuration and firewall)"
    fi
}

# Setup auto-renewal
setup_auto_renewal() {
    info "Setting up automatic certificate renewal..."

    local cron_job="0 3 * * * /usr/bin/certbot renew --quiet --deploy-hook '$0 --force-renew > /dev/null 2>&1'"

    # Add to root's crontab if not already present
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "${cron_job}") | crontab -
        success "Auto-renewal cron job added"
    else
        info "Auto-renewal cron job already exists"
    fi

    # Create renewal script
    local renewal_script="/usr/local/bin/renew-testbeatmap-ssl.sh"
    cat > "${renewal_script}" << 'EOF'
#!/bin/bash
# Automatic SSL renewal script for testbeatmap.com

/usr/bin/certbot renew --quiet
if [[ $? -eq 0 ]]; then
    # Copy renewed certificates
    if [[ -f "/etc/letsencrypt/live/testbeatmap.com/fullchain.pem" ]]; then
        cp "/etc/letsencrypt/live/testbeatmap.com/fullchain.pem" "/app/ssl/testbeatmap/server.crt"
        cp "/etc/letsencrypt/live/testbeatmap.com/privkey.pem" "/app/ssl/testbeatmap/server.key"

        # Restart services to use new certificates
        systemctl reload nginx || true
        docker restart beatmap_frontend || true
        docker restart concert_backend || true

        echo "$(date): SSL certificates renewed and services restarted" >> /var/log/ssl-renewal.log
    fi
fi
EOF

    chmod +x "${renewal_script}"
    success "Renewal script created at ${renewal_script}"
}

# Main execution
main() {
    info "Starting SSL certificate setup for ${DOMAIN}"

    check_root
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

        success "SSL certificate setup completed successfully!"
        info "Certificate files are available in: ${APP_SSL_DIR}"
        info "To use in your application, set:"
        info "  SSL_CERT_PATH=${APP_SSL_DIR}/server.crt"
        info "  SSL_KEY_PATH=${APP_SSL_DIR}/server.key"

        if [[ -z "${STAGING}" ]] && [[ -z "${DRY_RUN}" ]]; then
            info "Test your HTTPS setup at: https://${DOMAIN}"
            info "Check SSL rating at: https://www.ssllabs.com/ssltest/analyze.html?d=${DOMAIN}"
        fi
    else
        error "SSL certificate setup failed"
        start_services
        exit 1
    fi
}

# Run main function
main "$@"