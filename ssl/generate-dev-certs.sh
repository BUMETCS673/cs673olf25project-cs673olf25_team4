#!/bin/bash

# Generate Development SSL Certificates
# Creates self-signed certificates for local HTTPS development

set -euo pipefail

# Configuration
DOMAIN="localhost"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CERT_DIR="$PROJECT_ROOT/ssl/dev"
DAYS_VALID=365
KEY_SIZE=2048

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

# Main function
main() {
    info "Generating development SSL certificates for $DOMAIN"

    # Create directory if it doesn't exist
    mkdir -p "$CERT_DIR"

    # Generate private key
    info "Generating private key..."
    openssl genrsa -out "$CERT_DIR/server.key" $KEY_SIZE
    chmod 600 "$CERT_DIR/server.key"

    # Create certificate signing request config
    info "Creating certificate configuration..."
    cat > "$CERT_DIR/cert.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C=US
ST=Massachusetts
L=Boston
O=BeatMap Development
OU=Development Team
CN=$DOMAIN

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
basicConstraints = CA:FALSE

[alt_names]
DNS.1 = localhost
DNS.2 = 127.0.0.1
DNS.3 = ::1
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

    # Generate certificate signing request
    info "Generating certificate signing request..."
    openssl req -new -key "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" -config "$CERT_DIR/cert.conf"

    # Generate self-signed certificate
    info "Generating self-signed certificate..."
    openssl x509 -req -in "$CERT_DIR/server.csr" -signkey "$CERT_DIR/server.key" -out "$CERT_DIR/server.crt" -days $DAYS_VALID -extensions v3_req -extfile "$CERT_DIR/cert.conf"
    chmod 644 "$CERT_DIR/server.crt"

    # Generate Diffie-Hellman parameters
    info "Generating Diffie-Hellman parameters (this may take a while)..."
    openssl dhparam -out "$CERT_DIR/dhparam.pem" 2048
    chmod 644 "$CERT_DIR/dhparam.pem"

    # Clean up temporary files
    rm "$CERT_DIR/server.csr" "$CERT_DIR/cert.conf"

    # Verify certificate
    info "Verifying certificate..."
    if openssl x509 -in "$CERT_DIR/server.crt" -text -noout > /dev/null; then
        success "Certificate generated successfully!"
    else
        error "Certificate verification failed"
        exit 1
    fi

    # Display certificate information
    info "Certificate Information:"
    openssl x509 -in "$CERT_DIR/server.crt" -noout -subject -issuer -dates

    # Create certificate info file
    cat > "$CERT_DIR/cert-info.txt" << EOF
# Development SSL Certificate Information
# Generated on: $(date)

Certificate: $CERT_DIR/server.crt
Private Key: $CERT_DIR/server.key
Diffie-Hellman: $CERT_DIR/dhparam.pem

Valid for: $DAYS_VALID days
Expires: $(openssl x509 -in "$CERT_DIR/server.crt" -noout -enddate | cut -d= -f2)

Usage in application:
SSL_CERT_PATH=./$CERT_DIR/server.crt
SSL_KEY_PATH=./$CERT_DIR/server.key

Note: This is a self-signed certificate for development only.
Browsers will show security warnings - this is expected.
EOF

    success "Development certificates ready!"
    info "Certificate files created in: $CERT_DIR/"
    info "To use in your application:"
    echo "  SSL_CERT_PATH=$PWD/$CERT_DIR/server.crt"
    echo "  SSL_KEY_PATH=$PWD/$CERT_DIR/server.key"
    warn "Note: Browsers will show warnings for self-signed certificates"
}

# Run main function
main "$@"