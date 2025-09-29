#!/bin/bash

# Test Development SSL Configuration

set -euo pipefail

info() { echo -e "\033[0;34mINFO:\033[0m $*"; }
success() { echo -e "\033[0;32mSUCCESS:\033[0m $*"; }
error() { echo -e "\033[0;31mERROR:\033[0m $*"; }

info "Testing development SSL configuration..."

# Load SSL configuration
if [ -f .env.ssl ]; then
    source .env.ssl
    success "SSL configuration loaded"
else
    error "No .env.ssl file found - run: cp ssl/config-dev.env.template .env.ssl"
    exit 1
fi

# Check certificate files exist
if [ -f "$SSL_CERT_PATH" ] && [ -f "$SSL_KEY_PATH" ]; then
    success "SSL certificate files found"
else
    error "SSL certificate files missing - run: ./ssl/generate-dev-certs.sh"
    exit 1
fi

# Verify certificate
if openssl x509 -in "$SSL_CERT_PATH" -noout -checkend 0; then
    success "SSL certificate is valid"
else
    error "SSL certificate is invalid or expired"
    exit 1
fi

# Test SSL handshake
info "Testing SSL certificate..."
echo | openssl s_client -connect localhost:443 -cert "$SSL_CERT_PATH" -key "$SSL_KEY_PATH" 2>/dev/null | grep "Verify return code" || info "SSL handshake test (this is expected to fail until application is configured)"

success "Development SSL configuration test complete!"