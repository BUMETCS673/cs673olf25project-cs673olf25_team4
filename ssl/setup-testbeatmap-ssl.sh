#!/bin/bash
#
# SSL Certificate Setup for testbeatmap.com (Test Server)
# Obtains and configures SSL certificates, copies them to /app/ssl/testbeatmap,
# and installs a renewal cron job with a deploy hook.
#
# Usage: ./setup-testbeatmap-ssl.sh [--staging] [--force-renew] [--dry-run]
#
# Env:
#   NON_INTERACTIVE=true   # skip prompts in CI
#
set -euo pipefail

# =======================
# Configuration
# =======================
DOMAIN="testbeatmap.com"
EMAIL="admin@testbeatmap.com"          # TODO: set a valid email you manage
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
BACKUP_DIR="/etc/ssl/backups"
APP_SSL_DIR="/app/ssl/testbeatmap"
LOG_FILE="/var/log/ssl-setup.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =======================
# Logging helpers
# =======================
log() {
  local level=$1; shift
  local message="$*"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "${ts} [${level}] ${message}" | tee -a "${LOG_FILE}"
}
info()    { log "INFO"    "${BLUE}$*${NC}"; }
warn()    { log "WARN"    "${YELLOW}$*${NC}"; }
error()   { log "ERROR"   "${RED}$*${NC}"; }
success() { log "SUCCESS" "${GREEN}$*${NC}"; }

# =======================
# CLI args
# =======================
STAGING=""
FORCE_RENEW=""
DRY_RUN=""

for arg in "$@"; do
  case "$arg" in
    --staging)     STAGING="--staging";       info "Using Let's Encrypt STAGING";;
    --force-renew) FORCE_RENEW="--force-renewal"; info "Force renewal enabled";;
    --dry-run)     DRY_RUN="--dry-run";       info "Dry run enabled";;
    *)
      error "Unknown option: $arg"
      echo "Usage: $0 [--staging] [--force-renew] [--dry-run]"
      exit 1
      ;;
  esac
done

# =======================
# Guards & prerequisites
# =======================
check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)."
    exit 1
  fi
}

install_prereqs() {
  info "Ensuring prerequisites (dig, nc, openssl) are installed..."
  if [[ -f /etc/redhat-release ]]; then
    # Amazon Linux / RHEL family
    command -v dig >/dev/null 2>&1 || yum install -y bind-utils >/dev/null
    command -v nc  >/dev/null 2>&1 || yum install -y nmap-ncat  >/dev/null
    command -v openssl >/dev/null 2>&1 || yum install -y openssl >/dev/null
  elif [[ -f /etc/debian_version ]]; then
    apt-get update -y >/dev/null
    command -v dig >/dev/null 2>&1 || apt-get install -y dnsutils >/dev/null
    command -v nc  >/dev/null 2>&1 || apt-get install -y netcat  >/dev/null
    command -v openssl >/dev/null 2>&1 || apt-get install -y openssl >/dev/null
  fi
  success "Prerequisites present."
}

install_certbot() {
  info "Checking certbot installation..."
  if ! command -v certbot >/dev/null 2>&1; then
    info "Installing certbot..."
    if [[ -f /etc/redhat-release ]]; then
      yum update -y >/dev/null
      yum install -y certbot >/dev/null
      # Optional: yum install -y python3-certbot-nginx
    elif [[ -f /etc/debian_version ]]; then
      apt-get update -y >/dev/null
      apt-get install -y certbot >/dev/null
      # Optional: apt-get install -y python3-certbot-nginx
    else
      error "Unsupported OS for automatic certbot install."
      exit 1
    fi
    success "Certbot installed."
  else
    success "Certbot already installed."
  fi
}

# =======================
# Safety checks
# =======================
testserver_safety_checks() {
  info "Running test server safety checks..."
  warn "⚠️  You are about to obtain certificates for ${DOMAIN}"

  if [[ -z "${STAGING}" ]] && [[ -z "${FORCE_RENEW}" ]]; then
    if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
      info "NON_INTERACTIVE mode — skipping confirmation prompt"
    else
      read -p "Proceed with issuance for ${DOMAIN}? (yes/no): " confirm
      if [[ "${confirm}" != "yes" ]]; then
        info "Cancelled by user."
        exit 0
      fi
    fi
  fi

  info "Checking DNS..."
  local dns_ip public_ip
  dns_ip=$(dig +short "${DOMAIN}" A | head -1 || true)
  public_ip=$(curl -s http://checkip.amazonaws.com/ || curl -s http://ipinfo.io/ip || echo "unknown")
  if [[ -n "${dns_ip}" ]]; then
    info "DNS ${DOMAIN} -> ${dns_ip}, this host -> ${public_ip}"
    if [[ "${dns_ip}" != "${public_ip}" ]]; then
      warn "DNS IP and host public IP differ. Validation may fail."
      if [[ -z "${FORCE_RENEW}" ]]; then
        if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
          warn "NON_INTERACTIVE — continuing despite DNS mismatch"
        else
          read -p "Continue anyway? (yes/no): " cont
          if [[ "${cont}" != "yes" ]]; then
            error "Stopping due to DNS mismatch."
            exit 1
          fi
        fi
      fi
    else
      success "DNS appears correct."
    fi
  else
    error "Could not resolve ${DOMAIN}"
    exit 1
  fi

  info "Checking port 80 reachability..."
  if nc -z -w5 "${DOMAIN}" 80; then
    success "Port 80 reachable from the internet."
  else
    warn "Port 80 may not be reachable. HTTP-01 challenge might fail."
  fi

  success "Safety checks complete."
}

# =======================
# FS prep & backup
# =======================
create_directories() {
  info "Creating directories..."
  mkdir -p "${BACKUP_DIR}" "${APP_SSL_DIR}" /var/log
  chmod 755 "${BACKUP_DIR}" "${APP_SSL_DIR}"
  success "Directories ready."
}

backup_certificates() {
  if [[ -d "${CERT_DIR}" ]] && [[ -z "${FORCE_RENEW}" ]]; then
    info "Backing up existing certs from ${CERT_DIR} ..."
    local stamp backup_path
    stamp=$(date +%Y%m%d-%H%M%S)
    backup_path="${BACKUP_DIR}/testbeatmap-${stamp}"
    mkdir -p "${backup_path}"
    cp -r "${CERT_DIR}" "${backup_path}/" || true
    success "Backup at ${backup_path}"
  fi
}

# =======================
# Service control
# =======================
stop_services() {
  info "Stopping any services bound to port 80..."
  if systemctl is-active --quiet nginx;  then systemctl stop nginx;  info "Stopped nginx";  fi
  if systemctl is-active --quiet apache2; then systemctl stop apache2; info "Stopped apache2"; fi

  if command -v docker >/dev/null 2>&1; then
    local containers
    containers=$(docker ps --filter "publish=80" --format "{{.Names}}" || true)
    if [[ -n "${containers}" ]]; then
      info "Stopping Docker containers on port 80: ${containers}"
      echo "${containers}" | xargs -r docker stop
    fi
  fi

  # As a last resort, kill any process still on 80
  fuser -k 80/tcp || true
  success "Port 80 should now be free."
}

start_services() {
  info "Starting previously-managed services (if enabled)..."
  if systemctl is-enabled --quiet nginx  2>/dev/null; then systemctl start nginx;  info "Started nginx";  fi
  if systemctl is-enabled --quiet apache2 2>/dev/null; then systemctl start apache2; info "Started apache2"; fi
}

# =======================
# Cert issuance
# =======================
obtain_certificate() {
  info "Requesting certificate for ${DOMAIN}..."

  local cmd="certbot certonly --standalone --non-interactive --agree-tos --email ${EMAIL} -d ${DOMAIN}"
  [[ -n "${STAGING}"     ]] && cmd+=" ${STAGING}"
  [[ -n "${FORCE_RENEW}" ]] && cmd+=" ${FORCE_RENEW}"
  [[ -n "${DRY_RUN}"     ]] && cmd+=" ${DRY_RUN}"

  info "Running: ${cmd}"
  if eval "${cmd}"; then
    [[ -z "${DRY_RUN}" ]] && success "Certificate obtained." || success "Dry run OK."
    return 0
  else
    error "Certbot failed."
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

# =======================
# Auto-renew setup
# =======================
setup_auto_renewal() {
  info "Installing renewal + deploy-hook scripts..."

  local renewal_script="/usr/local/bin/renew-testbeatmap-ssl.sh"
  cat > "${renewal_script}" << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/ssl-renewal.log"
log(){ echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "${LOG_FILE}"; }
log "Starting test server SSL renewal..."
if /usr/bin/certbot renew --quiet --deploy-hook "/usr/local/bin/deploy-testbeatmap-certs.sh"; then
  log "Renewal check OK"
else
  log "ERROR: Renewal failed"
  command -v mail >/dev/null 2>&1 && echo "SSL Renewal Failure $(hostname) $(date)" | mail -s "SSL Renewal Failure" admin@testbeatmap.com || true
fi
EOF
  chmod +x "${renewal_script}"

  local deploy_script="/usr/local/bin/deploy-testbeatmap-certs.sh"
  cat > "${deploy_script}" << 'EOF'
#!/bin/bash
DOMAIN="testbeatmap.com"
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
APP_SSL_DIR="/app/ssl/testbeatmap"
LOG_FILE="/var/log/ssl-renewal.log"
log(){ echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "${LOG_FILE}"; }

if [[ -f "${CERT_DIR}/fullchain.pem" && -f "${CERT_DIR}/privkey.pem" ]]; then
  log "Deploying renewed certificates..."
  if [[ -f "${APP_SSL_DIR}/server.crt" ]]; then
    cp "${APP_SSL_DIR}/server.crt" "${APP_SSL_DIR}/server.crt.backup.$(date +%s)"
    cp "${APP_SSL_DIR}/server.key" "${APP_SSL_DIR}/server.key.backup.$(date +%s)"
  fi
  cp "${CERT_DIR}/fullchain.pem" "${APP_SSL_DIR}/server.crt"
  cp "${CERT_DIR}/privkey.pem"   "${APP_SSL_DIR}/server.key"
  [[ -f "${CERT_DIR}/chain.pem" ]] && cp "${CERT_DIR}/chain.pem" "${APP_SSL_DIR}/chain.pem" || true
  chmod 644 "${APP_SSL_DIR}/server.crt" "${APP_SSL_DIR}/chain.pem" 2>/dev/null || true
  chmod 600 "${APP_SSL_DIR}/server.key"

  if systemctl is-active --quiet nginx; then
    systemctl reload nginx
    log "Reloaded nginx"
  fi
  if command -v docker >/dev/null 2>&1; then
    docker ps --format "{{.Names}}" | grep -q "beatmap_frontend" && docker restart beatmap_frontend && log "Restarted beatmap_frontend" || true
    docker ps --format "{{.Names}}" | grep -q "concert_backend"   && docker restart concert_backend   && log "Restarted concert_backend" || true
  fi
  log "Certificate deployment done."
else
  log "ERROR: New certificate files not found in ${CERT_DIR}"
fi
EOF
  chmod +x "${deploy_script}"

  # --- Try cron first ---
  if ! command -v crontab >/dev/null 2>&1; then
    info "crontab not found — installing cron service..."
    if [[ -f /etc/redhat-release ]]; then
      yum install -y cronie >/dev/null 2>&1 || true
      systemctl enable --now crond >/dev/null 2>&1 || true
    elif [[ -f /etc/debian_version ]]; then
      apt-get update -y >/dev/null 2>&1 || true
      apt-get install -y cron >/dev/null 2>&1 || true
      systemctl enable --now cron >/dev/null 2>&1 || true
    fi
  fi

  if command -v crontab >/dev/null 2>&1; then
    local cron_job="0 3 * * * ${renewal_script} >> /var/log/ssl-renewal.log 2>&1"
    if ! crontab -l 2>/dev/null | grep -q "renew-testbeatmap-ssl.sh"; then
      (crontab -l 2>/dev/null; echo "${cron_job}") | crontab -
      success "Auto-renewal via cron installed (daily at 03:00)."
    else
      info "Auto-renewal cron already present."
    fi
    return 0
  fi

  # --- Fallback to systemd timer ---
  warn "Cron unavailable — falling back to systemd timer for renewal."
  local svc="/etc/systemd/system/testbeatmap-ssl-renew.service"
  local tmr="/etc/systemd/system/testbeatmap-ssl-renew.timer"

  cat > "${svc}" <<EOF
[Unit]
Description=Testbeatmap SSL renewal

[Service]
Type=oneshot
ExecStart=${renewal_script}
EOF

  cat > "${tmr}" <<EOF
[Unit]
Description=Run Testbeatmap SSL renewal daily at 03:00
[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now testbeatmap-ssl-renew.timer
  success "Auto-renewal via systemd timer installed (daily at 03:00)."
}


# =======================
# Main
# =======================
main() {
  info "Starting SSL setup for ${DOMAIN} (TEST SERVER)"

  check_root
  install_prereqs
  testserver_safety_checks
  install_certbot
  create_directories
  backup_certificates
  stop_services

  if obtain_certificate; then
      # Ensure Let's Encrypt certs are world-readable for Docker mounts
    info "Fixing permissions for Let's Encrypt certs..."
    chmod -R a+r /etc/letsencrypt/live || true
    chmod -R a+r /etc/letsencrypt/archive || true
    success "Permissions adjusted for Docker access."

    copy_certificates
    validate_certificate
    create_cert_info
    setup_auto_renewal
    start_services
    test_https

    success "🎉 SSL setup completed successfully."
    info "Certs at: ${APP_SSL_DIR}"
    info "Set in app: SSL_CERT_PATH=${APP_SSL_DIR}/server.crt, SSL_KEY_PATH=${APP_SSL_DIR}/server.key"
    if [[ -z "${STAGING}" ]] && [[ -z "${DRY_RUN}" ]]; then
      info "Visit: https://${DOMAIN}"
    fi
  else
    error "SSL setup failed."
    start_services
    exit 1
  fi
}

main "$@"