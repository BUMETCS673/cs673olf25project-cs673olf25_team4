#!/bin/bash

# Production Environment Deployment Script
# Deploys BeatMap application with Let's Encrypt SSL certificates for production

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$SCRIPT_DIR/ssl"
SRC_DIR="$SCRIPT_DIR/src"
COMPOSE_FILE="$SRC_DIR/docker-compose.prod.yml"
ENV_FILE="$SRC_DIR/.env"
DOMAIN="${PRODUCTION_DOMAIN:-beatmap.live}"
LETSENCRYPT_DIR="/etc/letsencrypt/live/$DOMAIN"
BACKUP_DIR="$SCRIPT_DIR/backups/$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Logging functions
info() { echo -e "${BLUE}INFO:${NC} $*"; }
success() { echo -e "${GREEN}SUCCESS:${NC} $*"; }
warn() { echo -e "${YELLOW}WARNING:${NC} $*"; }
error() { echo -e "${RED}ERROR:${NC} $*"; }
step() { echo -e "${CYAN}▶${NC} $*"; }
critical() { echo -e "${MAGENTA}CRITICAL:${NC} $*"; }

# Error handler
trap 'error "Deployment failed at line $LINENO"' ERR

# Display banner
banner() {
    echo -e "${MAGENTA}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║   BeatMap Production Deployment (HTTPS)       ║"
    echo "║              Domain: $DOMAIN              ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running as root or with sudo
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
        info "Usage: sudo bash deploy-prod.sh"
        exit 1
    fi
}

# Production safety confirmation
production_confirmation() {
    critical "⚠️  PRODUCTION DEPLOYMENT WARNING ⚠️"
    echo ""
    echo "You are about to deploy to PRODUCTION environment:"
    echo "  Domain: $DOMAIN"
    echo "  Environment: Production"
    echo "  SSL: Let's Encrypt (Production)"
    echo ""
    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Stop all running containers"
    echo "  2. Build and deploy new containers"
    echo "  3. Potentially cause brief downtime"
    echo ""

    read -p "Are you sure you want to continue? (type 'DEPLOY' to confirm): " CONFIRMATION
    if [[ "$CONFIRMATION" != "DEPLOY" ]]; then
        warn "Deployment cancelled by user"
        exit 0
    fi

    success "Production deployment confirmed"
}

# Check prerequisites
check_prerequisites() {
    step "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker."
        exit 1
    fi

    # Check certbot
    if ! command -v certbot &> /dev/null; then
        error "Certbot is not installed. Please install certbot first."
        info "Install with: sudo apt install certbot"
        exit 1
    fi

    # Check OpenSSL
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL is not installed. Please install OpenSSL first."
        exit 1
    fi

    success "All prerequisites met"
}

# Verify DNS configuration
verify_dns() {
    step "Verifying DNS configuration for $DOMAIN..."

    # Get server's public IP
    SERVER_IP=$(curl -s http://checkip.amazonaws.com || curl -s http://ifconfig.me)
    info "Server public IP: $SERVER_IP"

    # Check DNS A record
    DNS_IP=$(dig +short "$DOMAIN" | tail -n1)

    if [[ -z "$DNS_IP" ]]; then
        error "DNS A record not found for $DOMAIN"
        error "Please configure DNS before deploying to production"
        exit 1
    fi

    info "DNS A record points to: $DNS_IP"

    if [[ "$SERVER_IP" != "$DNS_IP" ]]; then
        warn "DNS IP ($DNS_IP) does not match server IP ($SERVER_IP)"
        warn "SSL certificate validation may fail"
        read -p "Continue anyway? (y/N): " CONTINUE
        if [[ "$CONTINUE" != "y" ]]; then
            exit 1
        fi
    else
        success "DNS configuration verified"
    fi
}

# Check SSL certificates
check_ssl_certificates() {
    step "Checking SSL certificates for $DOMAIN..."

    if [[ ! -f "$LETSENCRYPT_DIR/fullchain.pem" ]] || [[ ! -f "$LETSENCRYPT_DIR/privkey.pem" ]]; then
        warn "Let's Encrypt certificates not found for $DOMAIN"
        info "Running SSL setup script..."

        if [[ -f "$SSL_DIR/setup-production-ssl.sh" ]]; then
            bash "$SSL_DIR/setup-production-ssl.sh"

            # Verify certificates were created
            if [[ ! -f "$LETSENCRYPT_DIR/fullchain.pem" ]]; then
                error "SSL certificate generation failed"
                exit 1
            fi
            success "SSL certificates generated"
        else
            error "SSL setup script not found at $SSL_DIR/setup-production-ssl.sh"
            exit 1
        fi
    else
        # Check certificate expiration
        EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$LETSENCRYPT_DIR/fullchain.pem" | cut -d= -f2)
        EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" "+%s")
        CURRENT_EPOCH=$(date "+%s")
        DAYS_UNTIL_EXPIRY=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))

        if [[ $DAYS_UNTIL_EXPIRY -lt 7 ]]; then
            warn "SSL certificate expires in $DAYS_UNTIL_EXPIRY days"
            info "Renewing certificate..."
            certbot renew --force-renewal
        elif [[ $DAYS_UNTIL_EXPIRY -lt 30 ]]; then
            warn "SSL certificate expires in $DAYS_UNTIL_EXPIRY days"
        else
            info "SSL certificate valid for $DAYS_UNTIL_EXPIRY days"
        fi

        success "SSL certificates valid"
    fi
}

# Check environment file
check_environment() {
    step "Checking environment configuration..."

    if [[ ! -f "$ENV_FILE" ]]; then
        error "Environment file not found at $ENV_FILE"
        info "Please create .env file with required API keys"
        exit 1
    fi

    # Check for required environment variables
    REQUIRED_VARS=("JAMBASE_API_KEY" "TM_API_KEY" "TM_API_SECRET" "GROQ_API_KEY")
    MISSING_VARS=()

    for VAR in "${REQUIRED_VARS[@]}"; do
        if ! grep -q "^${VAR}=" "$ENV_FILE"; then
            MISSING_VARS+=("$VAR")
        fi
    done

    if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
        error "Missing required environment variables in $ENV_FILE:"
        for VAR in "${MISSING_VARS[@]}"; do
            echo "  - $VAR"
        done
        exit 1
    fi

    success "Environment configuration valid"
}

# Create backup of current deployment
create_backup() {
    step "Creating backup of current deployment..."

    mkdir -p "$BACKUP_DIR"

    # Backup Docker images
    cd "$SRC_DIR"
    if docker compose -f docker-compose.prod.yml ps -q &> /dev/null 2>&1; then
        info "Backing up container configurations..."
        docker compose -f docker-compose.prod.yml config > "$BACKUP_DIR/docker-compose.backup.yml"
        success "Backup created at $BACKUP_DIR"
    else
        info "No existing deployment to backup"
    fi
}

# Stop existing containers
stop_containers() {
    step "Stopping existing containers..."

    cd "$SRC_DIR"

    # Try to stop containers gracefully
    if docker compose -f docker-compose.prod.yml ps -q &> /dev/null 2>&1; then
        info "Stopping containers gracefully (30 second timeout)..."
        docker compose -f docker-compose.prod.yml down --timeout 30
        success "Existing containers stopped"
    elif docker-compose -f docker-compose.prod.yml ps -q &> /dev/null 2>&1; then
        info "Stopping containers gracefully (30 second timeout)..."
        docker-compose -f docker-compose.prod.yml down --timeout 30
        success "Existing containers stopped"
    else
        info "No existing containers to stop"
    fi
}

# Build and start containers
deploy_containers() {
    step "Building and starting production containers..."

    cd "$SRC_DIR"

    # Build images
    info "Building Docker images (this may take several minutes)..."
    if command -v docker compose &> /dev/null; then
        docker compose -f docker-compose.prod.yml build --no-cache
    else
        docker-compose -f docker-compose.prod.yml build --no-cache
    fi

    # Start containers
    info "Starting containers in production mode..."
    if command -v docker compose &> /dev/null; then
        docker compose -f docker-compose.prod.yml up -d
    else
        docker-compose -f docker-compose.prod.yml up -d
    fi

    success "Containers deployed"
}

# Health check
health_check() {
    step "Performing health checks..."

    info "Waiting for services to start (60 seconds)..."
    sleep 60

    HEALTH_FAILED=false

    # Check backend health
    info "Checking backend service..."
    if curl -f --max-time 10 "https://$DOMAIN:8443/health" &> /dev/null; then
        success "Backend service is healthy"
    else
        warn "Backend service health check failed"
        HEALTH_FAILED=true
    fi

    # Check frontend
    info "Checking frontend service..."
    if curl -f --max-time 10 "https://$DOMAIN" &> /dev/null; then
        success "Frontend service is healthy"
    else
        warn "Frontend service health check failed"
        HEALTH_FAILED=true
    fi

    # Check provider services
    info "Checking provider services..."
    PROVIDERS=("ticketmaster:8001" "jambase:8002" "groq:8003")
    for PROVIDER in "${PROVIDERS[@]}"; do
        NAME=$(echo "$PROVIDER" | cut -d: -f1)
        PORT=$(echo "$PROVIDER" | cut -d: -f2)
        if curl -f --max-time 10 "https://$DOMAIN:$PORT/health" &> /dev/null 2>&1; then
            success "$NAME provider is healthy"
        else
            warn "$NAME provider health check failed"
            HEALTH_FAILED=true
        fi
    done

    if [[ "$HEALTH_FAILED" == "true" ]]; then
        warn "Some health checks failed. Check logs for details:"
        info "docker compose -f src/docker-compose.prod.yml logs"
    fi
}

# Verify HTTPS connectivity
verify_https() {
    step "Verifying HTTPS connectivity..."

    # Test SSL certificate
    info "Testing SSL certificate..."
    if echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null | grep -q "Verify return code: 0"; then
        success "SSL certificate is valid and trusted"
    else
        warn "SSL certificate validation failed"
        info "Check certificate with: openssl s_client -connect $DOMAIN:443 -servername $DOMAIN"
    fi

    # Test HTTPS redirect
    info "Testing HTTP to HTTPS redirect..."
    REDIRECT=$(curl -sI "http://$DOMAIN" | grep -i "location:" | awk '{print $2}' | tr -d '\r')
    if [[ "$REDIRECT" == https://* ]]; then
        success "HTTP to HTTPS redirect is working"
    else
        warn "HTTP to HTTPS redirect may not be configured correctly"
    fi
}

# Display deployment information
display_info() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║    Production Deployment Successful!          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Access Points:${NC}"
    echo "  🌐 Frontend:  https://$DOMAIN"
    echo "  🔧 Backend:   https://$DOMAIN:8443"
    echo ""
    echo -e "${CYAN}Provider Services:${NC}"
    echo "  🎫 Ticketmaster: https://$DOMAIN:8001"
    echo "  🎵 JamBase:      https://$DOMAIN:8002"
    echo "  🤖 Groq:         https://$DOMAIN:8003"
    echo ""
    echo -e "${CYAN}SSL Certificate Info:${NC}"
    echo "  📜 Certificate:  $LETSENCRYPT_DIR/fullchain.pem"
    echo "  🔑 Private Key:  $LETSENCRYPT_DIR/privkey.pem"
    echo "  🔄 Auto-renewal: Enabled via certbot"
    echo ""
    echo -e "${CYAN}Backup Location:${NC}"
    echo "  💾 $BACKUP_DIR"
    echo ""
    echo -e "${CYAN}Useful Commands:${NC}"
    echo "  📊 View logs:        docker compose -f src/docker-compose.prod.yml logs -f"
    echo "  🔍 Check status:     docker compose -f src/docker-compose.prod.yml ps"
    echo "  ⏹️  Stop services:    docker compose -f src/docker-compose.prod.yml down"
    echo "  🔄 Restart service:  docker compose -f src/docker-compose.prod.yml restart <service>"
    echo "  📜 SSL info:         certbot certificates"
    echo "  🔄 Renew SSL:        certbot renew"
    echo ""
    echo -e "${CYAN}Monitoring:${NC}"
    echo "  📈 Monitor certs:    bash ssl/monitor-certificates.sh"
    echo "  🔍 SSL Labs test:    https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
    echo ""
}

# Rollback on failure
rollback_deployment() {
    error "Deployment failed. Attempting rollback..."

    cd "$SRC_DIR"

    if [[ -f "$BACKUP_DIR/docker-compose.backup.yml" ]]; then
        info "Rolling back to previous deployment..."
        if command -v docker compose &> /dev/null; then
            docker compose -f docker-compose.prod.yml down
            docker compose -f "$BACKUP_DIR/docker-compose.backup.yml" up -d
        else
            docker-compose -f docker-compose.prod.yml down
            docker-compose -f "$BACKUP_DIR/docker-compose.backup.yml" up -d
        fi
        warn "Rollback completed. Please check logs."
    else
        warn "No backup found. Manual intervention required."
        info "To stop failed deployment: docker compose -f src/docker-compose.prod.yml down"
    fi
}

# Main deployment flow
main() {
    banner

    # Production safeguards
    check_permissions
    production_confirmation

    # Set up error handling
    trap rollback_deployment ERR

    # Execute deployment steps
    check_prerequisites
    verify_dns
    check_ssl_certificates
    check_environment
    create_backup
    stop_containers
    deploy_containers
    health_check
    verify_https
    display_info

    success "Production deployment complete!"
}

# Run main function
main "$@"