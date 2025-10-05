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
        if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
            info "Non-interactive mode detected — skipping confirmation prompt"
        else
            read -p "Are you sure you want to proceed with PRODUCTION certificate generation? (yes/no): " confirm
            if [[ "$confirm" != "yes" ]]; then
                info "Production certificate generation cancelled by user"
                exit 0
            fi
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
                if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
                    warn "Non-interactive mode — continuing despite DNS mismatch"
                else
                    read -p "Continue anyway? (yes/no): " continue_confirm
                    if [[ "$continue_confirm" != "yes" ]]; then
                        error "Stopping due to DNS mismatch"
                        exit 1
                    fi
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
            yum update -y
            yum install -y certbot
        elif [[ -f /etc/debian_version ]]; then
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

# (the rest of the functions remain unchanged...)

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
