#!/bin/bash

# Certificate Deployment Automation Script
# Deploys SSL certificates to running application containers and services
#
# Usage: ./deploy-certificates.sh [--environment ENV] [--restart-services] [--backup]
#
# Environments: test, production, development

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-auto}"
RESTART_SERVICES=false
BACKUP_CERTS=false
LOG_FILE="${LOG_FILE:-/var/log/cert-deployment.log}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment|-e)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --restart-services|-r)
            RESTART_SERVICES=true
            shift
            ;;
        --backup|-b)
            BACKUP_CERTS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--environment ENV] [--restart-services] [--backup]"
            echo ""
            echo "Options:"
            echo "  -e, --environment ENV  Target environment (test, production, development, auto)"
            echo "  -r, --restart-services Restart services after certificate deployment"
            echo "  -b, --backup          Backup existing certificates before deployment"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "Environments:"
            echo "  test        Deploy to test environment (testbeatmap.com)"
            echo "  production  Deploy to production environment (beatmap.live)"
            echo "  development Deploy to development environment (localhost)"
            echo "  auto        Auto-detect environment based on available certificates"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
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

# Detect environment automatically
detect_environment() {
    if [[ "$ENVIRONMENT" != "auto" ]]; then
        return 0
    fi

    info "Auto-detecting environment..."

    # Check for production certificates
    if [[ -f "/app/ssl/production/server.crt" ]]; then
        ENVIRONMENT="production"
        info "Detected production environment (beatmap.live)"
        return 0
    fi

    # Check for test certificates
    if [[ -f "/app/ssl/testbeatmap/server.crt" ]]; then
        ENVIRONMENT="test"
        info "Detected test environment (testbeatmap.com)"
        return 0
    fi

    # Check for development certificates
    if [[ -f "ssl/dev/server.crt" ]]; then
        ENVIRONMENT="development"
        info "Detected development environment"
        return 0
    fi

    error "Could not auto-detect environment - no certificates found"
    exit 1
}

# Get environment-specific configuration
get_environment_config() {
    case "$ENVIRONMENT" in
        "test")
            DOMAIN="testbeatmap.com"
            CERT_DIR="/app/ssl/testbeatmap"
            NGINX_CONFIG="/etc/nginx/sites-available/testbeatmap"
            DOCKER_COMPOSE_FILE="/home/ec2-user/cs673olf25project-cs673olf25_team4/src/docker-compose.yml"
            ;;
        "production")
            DOMAIN="beatmap.live"
            CERT_DIR="/app/ssl/production"
            NGINX_CONFIG="/etc/nginx/sites-available/beatmap"
            DOCKER_COMPOSE_FILE="/home/ec2-user/cs673olf25project-cs673olf25_team4/src/docker-compose.prod.yml"
            ;;
        "development")
            DOMAIN="localhost"
            CERT_DIR="ssl/dev"
            NGINX_CONFIG="/etc/nginx/sites-available/default"
            DOCKER_COMPOSE_FILE="/Users/michaellaszlo/Desktop/BU Academics/CSE673_Software_Engineering/cs673olf25project-cs673olf25_team4/src/docker-compose.yml"
            ;;
        *)
            error "Unknown environment: $ENVIRONMENT"
            echo "Valid environments: test, production, development"
            exit 1
            ;;
    esac

    info "Environment: $ENVIRONMENT"
    info "Domain: $DOMAIN"
    info "Certificate directory: $CERT_DIR"
}

# Backup existing certificates
backup_existing_certificates() {
    if [[ "$BACKUP_CERTS" != "true" ]]; then
        return 0
    fi

    info "Backing up existing certificates..."

    local backup_dir="/etc/ssl/backups"
    local backup_name="${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"
    local backup_path="${backup_dir}/${backup_name}"

    mkdir -p "$backup_dir"

    if [[ -d "$CERT_DIR" ]]; then
        cp -r "$CERT_DIR" "$backup_path"
        success "Certificates backed up to: $backup_path"
    else
        info "No existing certificates to backup"
    fi
}

# Validate certificates
validate_certificates() {
    info "Validating certificates in $CERT_DIR..."

    local cert_file="$CERT_DIR/server.crt"
    local key_file="$CERT_DIR/server.key"

    # Check if files exist
    if [[ ! -f "$cert_file" ]]; then
        error "Certificate file not found: $cert_file"
        return 1
    fi

    if [[ ! -f "$key_file" ]]; then
        error "Private key file not found: $key_file"
        return 1
    fi

    # Validate certificate
    if ! openssl x509 -in "$cert_file" -text -noout > /dev/null 2>&1; then
        error "Invalid certificate file: $cert_file"
        return 1
    fi

    # Validate private key
    if ! openssl rsa -in "$key_file" -check -noout > /dev/null 2>&1; then
        error "Invalid private key file: $key_file"
        return 1
    fi

    # Check if certificate and key match
    local cert_hash=$(openssl x509 -in "$cert_file" -pubkey -noout | openssl md5)
    local key_hash=$(openssl rsa -in "$key_file" -pubout 2>/dev/null | openssl md5)

    if [[ "$cert_hash" != "$key_hash" ]]; then
        error "Certificate and private key do not match"
        return 1
    fi

    # Check certificate expiration
    if ! openssl x509 -in "$cert_file" -checkend 0 > /dev/null 2>&1; then
        error "Certificate has expired"
        return 1
    fi

    # Get expiration info
    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local days_until_expiry=$(( ($(date -d "$expiry_date" +%s) - $(date +%s)) / 86400 ))

    success "Certificate validation passed"
    info "Certificate expires: $expiry_date"
    info "Days until expiry: $days_until_expiry"

    if [[ $days_until_expiry -lt 30 ]]; then
        warn "Certificate expires in less than 30 days!"
    fi

    return 0
}

# Deploy certificates to NGINX
deploy_to_nginx() {
    if ! command -v nginx > /dev/null 2>&1; then
        info "NGINX not installed, skipping NGINX deployment"
        return 0
    fi

    info "Deploying certificates to NGINX..."

    # Check if NGINX config exists
    if [[ ! -f "$NGINX_CONFIG" ]]; then
        warn "NGINX config not found: $NGINX_CONFIG"
        return 0
    fi

    # Test NGINX config
    if nginx -t > /dev/null 2>&1; then
        success "NGINX configuration is valid"
    else
        error "NGINX configuration test failed"
        return 1
    fi

    # Reload NGINX if it's running
    if systemctl is-active --quiet nginx; then
        if systemctl reload nginx; then
            success "NGINX reloaded successfully"
        else
            error "Failed to reload NGINX"
            return 1
        fi
    else
        info "NGINX is not running"
    fi

    return 0
}

# Deploy certificates to Docker containers
deploy_to_docker() {
    if ! command -v docker > /dev/null 2>&1; then
        info "Docker not installed, skipping Docker deployment"
        return 0
    fi

    info "Deploying certificates to Docker containers..."

    # Check if docker-compose file exists
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        warn "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
        return 0
    fi

    local compose_dir=$(dirname "$DOCKER_COMPOSE_FILE")
    cd "$compose_dir"

    # Get list of running containers
    local containers=$(docker-compose ps --services --filter status=running 2>/dev/null || echo "")

    if [[ -z "$containers" ]]; then
        info "No running Docker containers found"
        return 0
    fi

    info "Found running containers: $containers"

    if [[ "$RESTART_SERVICES" == "true" ]]; then
        info "Restarting Docker services to apply new certificates..."

        # Restart services that use SSL
        local ssl_services=("frontend" "backend")
        for service in "${ssl_services[@]}"; do
            if echo "$containers" | grep -q "$service"; then
                info "Restarting $service..."
                if docker-compose restart "$service"; then
                    success "$service restarted successfully"
                else
                    warn "Failed to restart $service"
                fi
            fi
        done
    else
        info "Services not restarted (use --restart-services to restart)"
    fi

    return 0
}

# Deploy certificates to application directories
deploy_to_application() {
    info "Ensuring certificates are properly deployed to application..."

    # Set proper file permissions
    chmod 644 "$CERT_DIR/server.crt" 2>/dev/null || true
    chmod 600 "$CERT_DIR/server.key" 2>/dev/null || true
    chmod 644 "$CERT_DIR"/*.pem 2>/dev/null || true

    # Set proper ownership
    if id "www-data" &>/dev/null; then
        chown -R www-data:www-data "$CERT_DIR" 2>/dev/null || true
        info "Set ownership to www-data"
    elif id "nginx" &>/dev/null; then
        chown -R nginx:nginx "$CERT_DIR" 2>/dev/null || true
        info "Set ownership to nginx"
    fi

    success "Certificate permissions updated"
}

# Test certificate deployment
test_deployment() {
    info "Testing certificate deployment..."

    # Test local SSL connection
    if command -v openssl > /dev/null 2>&1; then
        info "Testing SSL handshake..."

        local ssl_test_result
        if ssl_test_result=$(echo | openssl s_client -connect "localhost:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -subject 2>/dev/null); then
            success "SSL handshake test passed"
            info "Certificate subject: $ssl_test_result"
        else
            warn "SSL handshake test failed (this may be normal if services aren't running)"
        fi
    fi

    # Test HTTPS connectivity if not localhost
    if [[ "$DOMAIN" != "localhost" ]]; then
        info "Testing HTTPS connectivity to $DOMAIN..."

        if curl -s --connect-timeout 10 --max-time 30 "https://$DOMAIN" > /dev/null 2>&1; then
            success "HTTPS connectivity test passed"
        else
            warn "HTTPS connectivity test failed"
            info "This may be normal if:"
            info "  - DNS is not configured yet"
            info "  - Services are not running"
            info "  - Firewall is blocking connections"
        fi
    fi
}

# Generate deployment report
generate_deployment_report() {
    info "Generating deployment report..."

    local report_file="/tmp/cert-deployment-report-$(date +%Y%m%d-%H%M%S).txt"

    cat > "$report_file" << EOF
# Certificate Deployment Report
# Generated on: $(date)
# Environment: $ENVIRONMENT
# Domain: $DOMAIN

## Deployment Summary
- Certificate directory: $CERT_DIR
- NGINX config: $NGINX_CONFIG
- Docker Compose file: $DOCKER_COMPOSE_FILE
- Backup created: $BACKUP_CERTS
- Services restarted: $RESTART_SERVICES

## Certificate Information
$(openssl x509 -in "$CERT_DIR/server.crt" -text -noout | head -30 2>/dev/null || echo "Certificate information not available")

## File Permissions
$(ls -la "$CERT_DIR" 2>/dev/null || echo "Certificate directory not accessible")

## Service Status
EOF

    # Add NGINX status
    if command -v nginx > /dev/null 2>&1; then
        echo "### NGINX Status" >> "$report_file"
        if systemctl is-active --quiet nginx; then
            echo "NGINX: Running" >> "$report_file"
        else
            echo "NGINX: Not running" >> "$report_file"
        fi
        echo "" >> "$report_file"
    fi

    # Add Docker status
    if command -v docker > /dev/null 2>&1; then
        echo "### Docker Status" >> "$report_file"
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            cd "$(dirname "$DOCKER_COMPOSE_FILE")"
            echo "Running containers:" >> "$report_file"
            docker-compose ps >> "$report_file" 2>/dev/null || echo "No containers found" >> "$report_file"
        else
            echo "Docker Compose file not found" >> "$report_file"
        fi
        echo "" >> "$report_file"
    fi

    # Add recent logs
    echo "### Recent Deployment Logs" >> "$report_file"
    tail -20 "$LOG_FILE" >> "$report_file" 2>/dev/null || echo "No recent logs found" >> "$report_file"

    success "Deployment report generated: $report_file"

    # Display report summary
    info "Report Summary:"
    cat "$report_file"
}

# Main execution
main() {
    info "Starting certificate deployment..."
    info "Environment: $ENVIRONMENT"
    info "Restart services: $RESTART_SERVICES"
    info "Backup certificates: $BACKUP_CERTS"

    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"

    # Detect environment if auto
    detect_environment

    # Get environment configuration
    get_environment_config

    # Backup existing certificates
    backup_existing_certificates

    # Validate certificates
    if ! validate_certificates; then
        error "Certificate validation failed"
        exit 1
    fi

    # Deploy to various services
    deploy_to_application
    deploy_to_nginx
    deploy_to_docker

    # Test deployment
    test_deployment

    # Generate report
    generate_deployment_report

    success "Certificate deployment completed successfully!"
    info "Environment: $ENVIRONMENT ($DOMAIN)"
    info "Certificate directory: $CERT_DIR"

    if [[ "$DOMAIN" != "localhost" ]]; then
        info "Test your HTTPS setup at: https://$DOMAIN"
    fi
}

# Run main function
main "$@"