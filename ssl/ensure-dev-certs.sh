#!/bin/bash

# Ensure Development SSL Certificates Exist
# Checks for existing certificates and generates them if missing

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/dev"
CERT_FILE="$CERT_DIR/server.crt"
KEY_FILE="$CERT_DIR/server.key"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}INFO:${NC} $*"; }
success() { echo -e "${GREEN}SUCCESS:${NC} $*"; }
warn() { echo -e "${YELLOW}WARNING:${NC} $*"; }
error() { echo -e "${RED}ERROR:${NC} $*"; }

main() {
    info "Checking for development SSL certificates..."

    # Check if certificates exist
    if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
        # Verify certificates are valid
        if openssl x509 -in "$CERT_FILE" -noout -checkend 86400 2>/dev/null; then
            success "Valid development certificates found"

            # Show expiration info
            EXPIRY=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
            info "Certificate expires: $EXPIRY"
            return 0
        else
            warn "Certificates exist but are invalid or expiring soon"
            info "Regenerating certificates..."
        fi
    else
        info "No certificates found, generating new ones..."
    fi

    # Generate certificates
    cd "$SCRIPT_DIR/.."
    if bash "$SCRIPT_DIR/generate-dev-certs.sh"; then
        success "Development certificates generated successfully"
        return 0
    else
        error "Failed to generate certificates"
        return 1
    fi
}

main "$@"
