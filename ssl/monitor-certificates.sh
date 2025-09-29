#!/bin/bash

# SSL Certificate Monitoring Script
# Monitors certificate expiration and health for both domains
#
# Usage: ./monitor-certificates.sh [--alert-days N] [--email EMAIL]

set -euo pipefail

# Configuration
TESTBEATMAP_CERT="/app/ssl/testbeatmap/server.crt"
PRODUCTION_CERT="/app/ssl/production/server.crt"
ALERT_DAYS=${ALERT_DAYS:-30}  # Alert when cert expires in N days
LOG_FILE="${LOG_FILE:-/var/log/cert-monitoring.log}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Email settings (optional)
EMAIL_ALERT=""
SMTP_SERVER="localhost"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --alert-days)
            ALERT_DAYS="$2"
            shift 2
            ;;
        --email)
            EMAIL_ALERT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--alert-days N] [--email EMAIL]"
            exit 1
            ;;
    esac
done

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

# Check certificate expiration
check_certificate() {
    local cert_file="$1"
    local domain="$2"
    local environment="$3"

    if [[ ! -f "$cert_file" ]]; then
        error "Certificate file not found: $cert_file"
        return 1
    fi

    info "Checking certificate for $domain ($environment)..."

    # Get certificate expiration date
    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

    # Get certificate issuer
    local issuer=$(openssl x509 -in "$cert_file" -noout -issuer | cut -d= -f2-)

    # Get certificate subject
    local subject=$(openssl x509 -in "$cert_file" -noout -subject | cut -d= -f2-)

    info "Domain: $domain"
    info "Environment: $environment"
    info "Issuer: $issuer"
    info "Subject: $subject"
    info "Expires: $expiry_date"
    info "Days until expiry: $days_until_expiry"

    # Check certificate validity
    if openssl x509 -in "$cert_file" -checkend 0 &>/dev/null; then
        success "Certificate is currently valid"
    else
        error "Certificate has expired!"
        send_alert "$domain" "$environment" "EXPIRED" "$expiry_date"
        return 1
    fi

    # Check if certificate will expire soon
    if [[ $days_until_expiry -le $ALERT_DAYS ]]; then
        warn "Certificate expires in $days_until_expiry days (threshold: $ALERT_DAYS days)"
        send_alert "$domain" "$environment" "EXPIRING" "$expiry_date" "$days_until_expiry"
    else
        success "Certificate expiry is within acceptable range"
    fi

    # Test certificate chain
    if openssl verify -CAfile "$cert_file" "$cert_file" &>/dev/null; then
        success "Certificate chain is valid"
    else
        warn "Certificate chain validation failed (this may be normal for self-signed certs)"
    fi

    echo ""
    return 0
}

# Test HTTPS connectivity
test_https_connectivity() {
    local domain="$1"
    local environment="$2"

    info "Testing HTTPS connectivity for $domain ($environment)..."

    # Test HTTPS connection
    if curl -s --connect-timeout 10 --max-time 30 "https://$domain" > /dev/null; then
        success "HTTPS connectivity test passed"
    else
        warn "HTTPS connectivity test failed"
        return 1
    fi

    # Test SSL handshake
    local ssl_info=$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "SSL test failed")

    if [[ "$ssl_info" != "SSL test failed" ]]; then
        success "SSL handshake successful"
        info "Remote certificate info: $ssl_info"
    else
        warn "SSL handshake test failed"
    fi

    echo ""
}

# Send alert notifications
send_alert() {
    local domain="$1"
    local environment="$2"
    local alert_type="$3"
    local expiry_date="$4"
    local days_remaining="${5:-0}"

    local subject=""
    local message=""

    case "$alert_type" in
        "EXPIRED")
            subject="🚨 SSL Certificate EXPIRED for $domain ($environment)"
            message="The SSL certificate for $domain ($environment) has EXPIRED on $expiry_date. Immediate action required!"
            ;;
        "EXPIRING")
            subject="⚠️ SSL Certificate expiring soon for $domain ($environment)"
            message="The SSL certificate for $domain ($environment) will expire in $days_remaining days on $expiry_date. Please renew soon."
            ;;
    esac

    error "$subject"
    error "$message"

    # Send email alert if configured
    if [[ -n "$EMAIL_ALERT" ]] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$EMAIL_ALERT"
        info "Alert email sent to $EMAIL_ALERT"
    fi

    # Log to syslog
    logger -t ssl-monitor "$subject - $message"
}

# Generate monitoring report
generate_report() {
    local report_file="/tmp/ssl-certificate-report-$(date +%Y%m%d-%H%M%S).txt"

    info "Generating certificate monitoring report..."

    cat > "$report_file" << EOF
# SSL Certificate Monitoring Report
# Generated on: $(date)
# Hostname: $(hostname)

## Summary
- Alert threshold: $ALERT_DAYS days
- Email notifications: ${EMAIL_ALERT:-"Not configured"}

## Certificate Status

EOF

    # Check testbeatmap.com
    echo "### Test Environment (testbeatmap.com)" >> "$report_file"
    if [[ -f "$TESTBEATMAP_CERT" ]]; then
        {
            echo "Certificate file: $TESTBEATMAP_CERT"
            echo "Status: $(openssl x509 -in "$TESTBEATMAP_CERT" -checkend 0 &>/dev/null && echo "Valid" || echo "Invalid/Expired")"
            echo "Expires: $(openssl x509 -in "$TESTBEATMAP_CERT" -noout -enddate | cut -d= -f2)"
            echo "Days remaining: $(( ($(date -d "$(openssl x509 -in "$TESTBEATMAP_CERT" -noout -enddate | cut -d= -f2)" +%s) - $(date +%s)) / 86400 ))"
            echo ""
        } >> "$report_file"
    else
        echo "Certificate file not found: $TESTBEATMAP_CERT" >> "$report_file"
        echo "" >> "$report_file"
    fi

    # Check beatmap.live
    echo "### Production Environment (beatmap.live)" >> "$report_file"
    if [[ -f "$PRODUCTION_CERT" ]]; then
        {
            echo "Certificate file: $PRODUCTION_CERT"
            echo "Status: $(openssl x509 -in "$PRODUCTION_CERT" -checkend 0 &>/dev/null && echo "Valid" || echo "Invalid/Expired")"
            echo "Expires: $(openssl x509 -in "$PRODUCTION_CERT" -noout -enddate | cut -d= -f2)"
            echo "Days remaining: $(( ($(date -d "$(openssl x509 -in "$PRODUCTION_CERT" -noout -enddate | cut -d= -f2)" +%s) - $(date +%s)) / 86400 ))"
            echo ""
        } >> "$report_file"
    else
        echo "Certificate file not found: $PRODUCTION_CERT" >> "$report_file"
        echo "" >> "$report_file"
    fi

    # Add system information
    cat >> "$report_file" << EOF
## System Information
- Server: $(hostname)
- Date: $(date)
- Uptime: $(uptime)
- Disk space: $(df -h / | tail -1)

## Recent Certificate Logs
$(tail -20 "$LOG_FILE" 2>/dev/null || echo "No recent logs found")
EOF

    success "Report generated: $report_file"

    # Display report summary
    info "Report Summary:"
    cat "$report_file"
}

# Check certificate renewal status
check_renewal_status() {
    info "Checking certificate renewal configuration..."

    # Check if certbot is installed
    if command -v certbot &> /dev/null; then
        success "Certbot is installed: $(certbot --version)"

        # List certificates
        info "Installed certificates:"
        certbot certificates 2>/dev/null || warn "No certificates found or certbot access denied"
    else
        warn "Certbot is not installed"
    fi

    # Check cron jobs
    info "Checking renewal cron jobs:"
    if crontab -l 2>/dev/null | grep -q certbot; then
        success "Found certbot renewal cron job:"
        crontab -l 2>/dev/null | grep certbot
    else
        warn "No certbot renewal cron job found"
    fi

    # Check renewal scripts
    local scripts=("/usr/local/bin/renew-testbeatmap-ssl.sh" "/usr/local/bin/renew-production-ssl.sh")
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            success "Renewal script found: $script"
        else
            warn "Renewal script not found: $script"
        fi
    done

    echo ""
}

# Main execution
main() {
    info "Starting SSL certificate monitoring..."
    info "Alert threshold: $ALERT_DAYS days"

    if [[ -n "$EMAIL_ALERT" ]]; then
        info "Email alerts enabled: $EMAIL_ALERT"
    else
        info "Email alerts disabled"
    fi

    echo ""

    # Check certificates
    local exit_code=0

    if [[ -f "$TESTBEATMAP_CERT" ]]; then
        check_certificate "$TESTBEATMAP_CERT" "testbeatmap.com" "test" || exit_code=1
        test_https_connectivity "testbeatmap.com" "test" || true
    else
        warn "Test certificate not found: $TESTBEATMAP_CERT"
    fi

    if [[ -f "$PRODUCTION_CERT" ]]; then
        check_certificate "$PRODUCTION_CERT" "beatmap.live" "production" || exit_code=1
        test_https_connectivity "beatmap.live" "production" || true
    else
        warn "Production certificate not found: $PRODUCTION_CERT"
    fi

    # Check renewal status
    check_renewal_status

    # Generate report
    generate_report

    if [[ $exit_code -eq 0 ]]; then
        success "All certificate checks passed"
    else
        error "Some certificate checks failed - see logs above"
    fi

    info "Monitoring completed"
    return $exit_code
}

# Create log file if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Run main function
main "$@"