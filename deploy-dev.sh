#!/bin/bash

# Development Environment Deployment Script
# Deploys BeatMap application with self-signed SSL certificates for local development

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$SCRIPT_DIR/ssl"
SRC_DIR="$SCRIPT_DIR/src"
COMPOSE_FILE="$SRC_DIR/docker-compose.dev.yml"
ENV_FILE="$SRC_DIR/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
info() { echo -e "${BLUE}INFO:${NC} $*"; }
success() { echo -e "${GREEN}SUCCESS:${NC} $*"; }
warn() { echo -e "${YELLOW}WARNING:${NC} $*"; }
error() { echo -e "${RED}ERROR:${NC} $*"; }
step() { echo -e "${CYAN}▶${NC} $*"; }

# Error handler
trap 'error "Deployment failed at line $LINENO"' ERR

# Display banner
banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║   BeatMap Development Deployment (HTTPS)      ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
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

    # Check OpenSSL
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL is not installed. Please install OpenSSL first."
        exit 1
    fi

    success "All prerequisites met"
}

# Check and generate SSL certificates
check_ssl_certificates() {
    step "Checking SSL certificates..."

    if [[ ! -f "$SSL_DIR/dev/server.crt" ]] || [[ ! -f "$SSL_DIR/dev/server.key" ]]; then
        warn "Development SSL certificates not found. Generating..."

        if [[ -f "$SSL_DIR/generate-dev-certs.sh" ]]; then
            cd "$SCRIPT_DIR"
            bash "$SSL_DIR/generate-dev-certs.sh"
            success "SSL certificates generated"
        else
            error "SSL certificate generation script not found at $SSL_DIR/generate-dev-certs.sh"
            exit 1
        fi
    else
        # Check certificate expiration
        EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$SSL_DIR/dev/server.crt" | cut -d= -f2)
        EXPIRY_EPOCH=$(date -j -f "%b %d %T %Y %Z" "$EXPIRY_DATE" "+%s" 2>/dev/null || date -d "$EXPIRY_DATE" "+%s" 2>/dev/null)
        CURRENT_EPOCH=$(date "+%s")
        DAYS_UNTIL_EXPIRY=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))

        if [[ $DAYS_UNTIL_EXPIRY -lt 30 ]]; then
            warn "SSL certificate expires in $DAYS_UNTIL_EXPIRY days. Consider regenerating."
        else
            info "SSL certificates valid for $DAYS_UNTIL_EXPIRY days"
        fi
    fi
}

# Check environment file
check_environment() {
    step "Checking environment configuration..."

    if [[ ! -f "$ENV_FILE" ]]; then
        error "Environment file not found at $ENV_FILE"
        info "Please create .env file with required API keys:"
        info "  - JAMBASE_API_KEY"
        info "  - TM_API_KEY"
        info "  - TM_API_SECRET"
        info "  - GROQ_API_KEY"
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

# Stop existing containers
stop_containers() {
    step "Stopping existing containers..."

    cd "$SRC_DIR"

    # Try to stop containers using docker-compose.dev.yml
    if docker compose -f docker-compose.dev.yml ps -q &> /dev/null; then
        docker compose -f docker-compose.dev.yml down
        success "Existing containers stopped"
    elif docker-compose -f docker-compose.dev.yml ps -q &> /dev/null; then
        docker-compose -f docker-compose.dev.yml down
        success "Existing containers stopped"
    else
        info "No existing containers to stop"
    fi
}

# Build and start containers
deploy_containers() {
    step "Building and starting containers..."

    cd "$SRC_DIR"

    # Build images
    info "Building Docker images..."
    if command -v docker compose &> /dev/null; then
        docker compose -f docker-compose.dev.yml build --no-cache
    else
        docker-compose -f docker-compose.dev.yml build --no-cache
    fi

    # Start containers
    info "Starting containers..."
    if command -v docker compose &> /dev/null; then
        docker compose -f docker-compose.dev.yml up -d
    else
        docker-compose -f docker-compose.dev.yml up -d
    fi

    success "Containers started"
}

# Health check
health_check() {
    step "Performing health checks..."

    info "Waiting for services to start (30 seconds)..."
    sleep 30

    # Check backend health
    info "Checking backend service..."
    if curl -k -f https://localhost:8443/health &> /dev/null || curl -f http://localhost:8000/health &> /dev/null; then
        success "Backend service is healthy"
    else
        warn "Backend service health check failed (may still be starting)"
    fi

    # Check frontend
    info "Checking frontend service..."
    if curl -k -f https://localhost &> /dev/null || curl -f http://localhost &> /dev/null; then
        success "Frontend service is healthy"
    else
        warn "Frontend service health check failed (may still be starting)"
    fi

    # Check provider services
    info "Checking provider services..."
    PROVIDERS=("ticketmaster:8001" "jambase:8002" "groq:8003")
    for PROVIDER in "${PROVIDERS[@]}"; do
        NAME=$(echo "$PROVIDER" | cut -d: -f1)
        PORT=$(echo "$PROVIDER" | cut -d: -f2)
        if curl -k -f "https://localhost:$PORT/health" &> /dev/null 2>&1; then
            success "$NAME provider is healthy"
        else
            warn "$NAME provider health check failed (may still be starting)"
        fi
    done
}

# Display deployment information
display_info() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Development Deployment Successful!        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Access Points:${NC}"
    echo "  🌐 Frontend (HTTPS): https://localhost"
    echo "  🌐 Frontend (HTTP):  http://localhost"
    echo "  🔧 Backend (HTTPS):  https://localhost:8443"
    echo "  🔧 Backend (HTTP):   http://localhost:8000"
    echo ""
    echo -e "${CYAN}Provider Services:${NC}"
    echo "  🎫 Ticketmaster: https://localhost:8001"
    echo "  🎵 JamBase:      https://localhost:8002"
    echo "  🤖 Groq:         https://localhost:8003"
    echo ""
    echo -e "${YELLOW}Note:${NC} Self-signed certificates are used. Your browser will show a security warning."
    echo "      This is expected for development. Click 'Advanced' and proceed to the site."
    echo ""
    echo -e "${CYAN}Useful Commands:${NC}"
    echo "  📊 View logs:        docker compose -f src/docker-compose.dev.yml logs -f"
    echo "  🔍 Check status:     docker compose -f src/docker-compose.dev.yml ps"
    echo "  ⏹️  Stop services:    docker compose -f src/docker-compose.dev.yml down"
    echo "  🔄 Restart:          bash deploy-dev.sh"
    echo ""
}

# Cleanup on failure
cleanup_on_failure() {
    error "Deployment failed. Cleaning up..."
    cd "$SRC_DIR"
    if command -v docker compose &> /dev/null; then
        docker compose -f docker-compose.dev.yml down
    else
        docker-compose -f docker-compose.dev.yml down
    fi
}

# Main deployment flow
main() {
    banner

    # Set up error handling
    trap cleanup_on_failure ERR

    # Execute deployment steps
    check_prerequisites
    check_ssl_certificates
    check_environment
    stop_containers
    deploy_containers
    health_check
    display_info

    success "Development deployment complete!"
}

# Run main function
main "$@"