#!/bin/bash
#
# SSL Certificate Setup for beatmap.live (Production)
# Obtains and configures SSL certificates, copies them to /app/ssl/production,
# and installs a renewal cron job with a deploy hook.
#
# Usage: ./setup-production-ssl.sh [--staging] [--force-renew] [--dry-run]
#
# Env:
#   NON_INTERACTIVE=true   # skip prompts in CI
#
set -euo pipefail

# =======================
# Configuration
# =======================
DOMAIN="beatmap.live"
EMAIL="admin@beatmap.live"          # TODO: set a valid email you manage
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
BACKUP_DIR="/etc/ssl/backups"
APP_SSL_DIR="/app/ssl/production"
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
production_safety_checks() {
  info "Running production safety checks..."
  warn "⚠️  You are about to obtain REAL certificates for ${DOMAIN}"

  if [[ -z "${STAGING}" ]] && [[ -z "${FORCE_RENEW}" ]]; then
    if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
      info "NON_INTERACTIVE mode — skipping confirmation prompt"
    else
      read -p "Proceed with PRODUCTION issuance for ${DOMAIN}? (yes/no): " confirm
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
    backup_path="${BACKUP_DIR}/production-${stamp}"
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

# =======================
# Cert deployment to app
# =======================
copy_certificates() {
  if [[ -n "${DRY_RUN}" ]]; then
    info "Dry run: skipping copy."
    return 0
  fi
  if [[ ! -d "${CERT_DIR}" ]]; then
    error "Certificate directory missing: ${CERT_DIR}"
    return 1
  fi

  info "Copying certs to ${APP_SSL_DIR} ..."
  cp "${CERT_DIR}/fullchain.pem" "${APP_SSL_DIR}/server.crt"
  cp "${CERT_DIR}/privkey.pem"   "${APP_SSL_DIR}/server.key"
  cp "${CERT_DIR}/chain.pem"     "${APP_SSL_DIR}/chain.pem" || true

  chmod 644 "${APP_SSL_DIR}/server.crt" "${APP_SSL_DIR}/chain.pem" || true
  chmod 600 "${APP_SSL_DIR}/server.key"

  if id "www-data" >/dev/null 2>&1; then
    chown www-data:www-data "${APP_SSL_DIR}"/*
  elif id "nginx" >/dev/null 2>&1; then
    chown nginx:nginx "${APP_SSL_DIR}"/*
  fi

  success "Certificates copied to app directory."
}

validate_certificate() {
  if [[ -n "${DRY_RUN}" ]]; then
    info "Dry run: skipping validation."
    return 0
  fi

  local cert_file="${APP_SSL_DIR}/server.crt"
  if [[ ! -f "${cert_file}" ]]; then
    error "Missing ${cert_file}"
    return 1
  fi

  info "Validating certificate..."
  local expiry_date expiry_epoch current_epoch days_left
  expiry_date=$(openssl x509 -in "${cert_file}" -noout -enddate | cut -d= -f2)
  expiry_epoch=$(date -d "${expiry_date}" +%s)
  current_epoch=$(date +%s)
  days_left=$(( (expiry_epoch - current_epoch) / 86400 ))

  info "Not After: ${expiry_date}  (~${days_left} days left)"
  openssl x509 -in "${cert_file}" -text -noout >/dev/null
  success "x509 parse OK."

  local cert_domain
  cert_domain=$(openssl x509 -in "${cert_file}" -noout -subject | grep -oP 'CN=\K[^,]*' || true)
  if [[ "${cert_domain}" == "${DOMAIN}" ]]; then
    success "CN matches domain: ${cert_domain}"
  else
    warn "CN mismatch: expected ${DOMAIN}, got ${cert_domain:-unknown}"
  fi
}

create_cert_info() {
  if [[ -n "${DRY_RUN}" ]]; then return 0; fi

  info "Writing certificate info file..."
  local info_file="${APP_SSL_DIR}/cert-info.txt"
  local cert_file="${APP_SSL_DIR}/server.crt"

  cat > "${info_file}" << EOF
# SSL Certificate Information for ${DOMAIN} (PRODUCTION)
# Generated: $(date)

Domain: ${DOMAIN}
Certificate Path: ${cert_file}
Private Key Path: ${APP_SSL_DIR}/server.key
Chain Path: ${APP_SSL_DIR}/chain.pem

# Expiry:
$(openssl x509 -in "${cert_file}" -noout -enddate)

# Renewal Command:
sudo $0 --force-renew
EOF
  success "Wrote ${info_file}"
}

test_https() {
  if [[ -n "${DRY_RUN}" ]]; then
    info "Dry run: skipping HTTPS tests."
    return 0
  fi
  info "Testing HTTPS connectivity (best-effort)..."
  sleep 3
  curl -s -k "https://localhost" >/dev/null 2>&1 && success "Local HTTPS reachable" || warn "Local HTTPS failed (may be normal if app not running)"
  curl -s --connect-timeout 10 "https://${DOMAIN}" >/dev/null 2>&1 && success "Domain HTTPS reachable" || warn "Domain HTTPS not reachable yet"
}

# =======================
# Auto-renew setup
# =======================
setup_auto_renewal() {
  info "Installing renewal + deploy-hook scripts..."

  local renewal_script="/usr/local/bin/renew-production-ssl.sh"
  cat > "${renewal_script}" << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/ssl-renewal.log"
log(){ echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "${LOG_FILE}"; }
log "Starting production SSL renewal..."
if /usr/bin/certbot renew --quiet --deploy-hook "/usr/local/bin/deploy-production-certs.sh"; then
  log "Renewal check OK"
else
  log "ERROR: Renewal failed"
  command -v mail >/dev/null 2>&1 && echo "SSL Renewal Failure $(hostname) $(date)" | mail -s "SSL Renewal Failure" admin@beatmap.live || true
fi
EOF
  chmod +x "${renewal_script}"

  local deploy_script="/usr/local/bin/deploy-production-certs.sh"
  cat > "${deploy_script}" << 'EOF'
#!/bin/bash
DOMAIN="beatmap.live"
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
APP_SSL_DIR="/app/ssl/production"
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
    if ! crontab -l 2>/dev/null | grep -q "renew-production-ssl.sh"; then
      (crontab -l 2>/dev/null; echo "${cron_job}") | crontab -
      success "Auto-renewal via cron installed (daily at 03:00)."
    else
      info "Auto-renewal cron already present."
    fi
    return 0
  fi

  # --- Fallback to systemd timer ---
  warn "Cron unavailable — falling back to systemd timer for renewal."
  local svc="/etc/systemd/system/beatmap-ssl-renew.service"
  local tmr="/etc/systemd/system/beatmap-ssl-renew.timer"

  cat > "${svc}" <<EOF
[Unit]
Description=Beatmap SSL renewal

[Service]
Type=oneshot
ExecStart=${renewal_script}
EOF

  cat > "${tmr}" <<EOF
[Unit]
Description=Run Beatmap SSL renewal daily at 03:00
[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now beatmap-ssl-renew.timer
  success "Auto-renewal via systemd timer installed (daily at 03:00)."
}


# =======================
# Main
# =======================
main() {
  info "Starting SSL setup for ${DOMAIN} (PRODUCTION)"

  check_root
  install_prereqs
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
