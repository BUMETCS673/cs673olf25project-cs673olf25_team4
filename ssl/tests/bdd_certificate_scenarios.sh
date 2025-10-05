#!/bin/bash

# BDD Test Scenarios for SSL Certificate Management
# Demonstrates Behavior-Driven Development with Given/When/Then scenarios
# Tests certificate generation, validation, and deployment behaviors

source "$(dirname "$0")/ssl_test_framework.sh"

# BDD Test Suite: Certificate Generation Scenarios
test_certificate_generation_bdd() {
    echo -e "\n${PURPLE}🎭 BDD Scenario Testing: Certificate Generation${NC}"

    # Scenario 1: Generate development certificates from scratch
    echo -e "\n${BLUE}Scenario 1: Generate development certificates for new project${NC}"
    given "a new project without any SSL certificates"
    when "I run the development certificate generation script"
    then_step "self-signed certificates should be created with proper structure"

    # Setup test environment
    local test_cert_dir="$TEST_TEMP_DIR/dev_certs_test"
    mkdir -p "$test_cert_dir"

    # Test certificate generation
    cd "$test_cert_dir"
    if "$SSL_DIR/generate-dev-certs.sh" &>/dev/null; then
        assert_file_exists "ssl/dev/server.crt" "Development certificate file created"
        assert_file_exists "ssl/dev/server.key" "Development private key created"
        assert_file_exists "ssl/dev/dhparam.pem" "Diffie-Hellman parameters created"
        assert_file_exists "ssl/dev/cert-info.txt" "Certificate info file created"

        # Test certificate structure
        if openssl x509 -in ssl/dev/server.crt -noout -text | grep -q "CN=localhost"; then
            test_pass "Certificate Common Name" "Certificate correctly configured for localhost"
        else
            test_fail "Certificate Common Name" "Certificate not configured for localhost"
        fi

        # Test certificate validity period
        if openssl x509 -in ssl/dev/server.crt -checkend 0 &>/dev/null; then
            test_pass "Certificate Validity" "Certificate is currently valid"
        else
            test_fail "Certificate Validity" "Certificate is not valid"
        fi
    else
        test_fail "Certificate Generation" "Failed to generate development certificates"
    fi

    # Scenario 2: Regenerate existing certificates
    echo -e "\n${BLUE}Scenario 2: Regenerate certificates when they already exist${NC}"
    given "existing SSL certificates in the project"
    when "I run the certificate generation script again"
    then_step "new certificates should replace the old ones"

    # Store old certificate serial
    local old_serial=""
    if [[ -f "$test_cert_dir/ssl/dev/server.crt" ]]; then
        old_serial=$(openssl x509 -in "$test_cert_dir/ssl/dev/server.crt" -noout -serial | cut -d= -f2)
    fi

    # Regenerate certificates
    sleep 1 # Ensure different timestamp
    if "$SSL_DIR/generate-dev-certs.sh" &>/dev/null; then
        local new_serial=$(openssl x509 -in "$test_cert_dir/ssl/dev/server.crt" -noout -serial | cut -d= -f2)
        if [[ "$old_serial" != "$new_serial" ]]; then
            test_pass "Certificate Regeneration" "New certificate generated with different serial"
        else
            test_fail "Certificate Regeneration" "Certificate was not regenerated"
        fi
    else
        test_fail "Certificate Regeneration" "Failed to regenerate certificates"
    fi

    # Scenario 3: Certificate and key matching
    echo -e "\n${BLUE}Scenario 3: Verify certificate and private key match${NC}"
    given "a generated certificate and private key"
    when "I compare their public key fingerprints"
    then_step "they should match perfectly"

    if [[ -f "$test_cert_dir/ssl/dev/server.crt" && -f "$test_cert_dir/ssl/dev/server.key" ]]; then
        local cert_hash=$(openssl x509 -in "$test_cert_dir/ssl/dev/server.crt" -pubkey -noout | openssl md5 2>/dev/null | cut -d' ' -f2)
        local key_hash=$(openssl rsa -in "$test_cert_dir/ssl/dev/server.key" -pubout 2>/dev/null | openssl md5 2>/dev/null | cut -d' ' -f2)

        if [[ "$cert_hash" == "$key_hash" ]]; then
            test_pass "Certificate Key Matching" "Certificate and private key match"
        else
            test_fail "Certificate Key Matching" "Certificate and private key do not match"
        fi
    else
        test_fail "Certificate Key Matching" "Certificate or key file missing"
    fi
}

# BDD Test Suite: Certificate Validation Scenarios
test_certificate_validation_bdd() {
    echo -e "\n${PURPLE}🔍 BDD Scenario Testing: Certificate Validation${NC}"

    # Scenario 1: Validate certificate structure
    echo -e "\n${BLUE}Scenario 1: Validate development certificate structure${NC}"
    given "a self-signed development certificate"
    when "I examine its structure and properties"
    then_step "it should have all required fields and extensions"

    local cert_file="$SSL_DIR/dev/server.crt"
    if [[ -f "$cert_file" ]]; then
        # Test certificate version
        if openssl x509 -in "$cert_file" -noout -text | grep -q "Version: 3"; then
            test_pass "Certificate Version" "Certificate is X.509 v3"
        else
            test_fail "Certificate Version" "Certificate is not X.509 v3"
        fi

        # Test subject alternative names
        if openssl x509 -in "$cert_file" -noout -text | grep -q "Subject Alternative Name"; then
            test_pass "Subject Alternative Names" "Certificate includes SAN extension"
        else
            test_fail "Subject Alternative Names" "Certificate missing SAN extension"
        fi

        # Test key usage
        if openssl x509 -in "$cert_file" -noout -text | grep -q "Key Usage"; then
            test_pass "Key Usage Extension" "Certificate includes Key Usage extension"
        else
            test_fail "Key Usage Extension" "Certificate missing Key Usage extension"
        fi
    else
        test_skip "Certificate Structure Validation" "Development certificate not found"
    fi

    # Scenario 2: Validate certificate expiration
    echo -e "\n${BLUE}Scenario 2: Check certificate expiration timeframe${NC}"
    given "a newly generated development certificate"
    when "I check its expiration date"
    then_step "it should be valid for approximately one year"

    if [[ -f "$cert_file" ]]; then
        local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        local expiry_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" "+%s" 2>/dev/null || date -d "$expiry_date" "+%s" 2>/dev/null)
        local current_epoch=$(date "+%s")
        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

        if [[ $days_until_expiry -ge 360 && $days_until_expiry -le 370 ]]; then
            test_pass "Certificate Expiration Period" "Certificate valid for ~1 year ($days_until_expiry days)"
        else
            test_fail "Certificate Expiration Period" "Certificate validity period unexpected ($days_until_expiry days)"
        fi
    else
        test_skip "Certificate Expiration Check" "Development certificate not found"
    fi
}

# BDD Test Suite: Certificate Security Scenarios
test_certificate_security_bdd() {
    echo -e "\n${PURPLE}🔐 BDD Scenario Testing: Certificate Security${NC}"

    # Scenario 1: File permissions security
    echo -e "\n${BLUE}Scenario 1: Verify secure file permissions${NC}"
    given "generated SSL certificate files"
    when "I check their file permissions"
    then_step "certificates should be readable but private keys should be restricted"

    local cert_file="$SSL_DIR/dev/server.crt"
    local key_file="$SSL_DIR/dev/server.key"

    if [[ -f "$cert_file" ]]; then
        local cert_perms=$(stat -f "%Mp%Lp" "$cert_file" 2>/dev/null || stat -c "%a" "$cert_file" 2>/dev/null)
        if [[ "$cert_perms" == "644" || "$cert_perms" == "0644" ]]; then
            test_pass "Certificate File Permissions" "Certificate has correct permissions (644)"
        else
            test_fail "Certificate File Permissions" "Certificate has incorrect permissions ($cert_perms)"
        fi
    fi

    if [[ -f "$key_file" ]]; then
        local key_perms=$(stat -f "%Mp%Lp" "$key_file" 2>/dev/null || stat -c "%a" "$key_file" 2>/dev/null)
        if [[ "$key_perms" == "600" || "$key_perms" == "0600" ]]; then
            test_pass "Private Key File Permissions" "Private key has correct permissions (600)"
        else
            test_fail "Private Key File Permissions" "Private key has incorrect permissions ($key_perms)"
        fi
    fi

    # Scenario 2: Git security exclusion
    echo -e "\n${BLUE}Scenario 2: Verify certificates are excluded from version control${NC}"
    given "SSL certificates in the project"
    when "I check the git status"
    then_step "certificate files should not be tracked by git"

    cd "$PROJECT_ROOT"
    local git_status=$(git status --porcelain ssl/dev/ 2>/dev/null || echo "")

    if [[ -z "$git_status" ]] || ! echo "$git_status" | grep -q "server.crt\|server.key"; then
        test_pass "Git Security Exclusion" "Certificate files properly excluded from git"
    else
        test_fail "Git Security Exclusion" "Certificate files are being tracked by git"
    fi

    # Scenario 3: Certificate algorithm strength
    echo -e "\n${BLUE}Scenario 3: Verify cryptographic strength${NC}"
    given "a generated SSL certificate"
    when "I examine its cryptographic properties"
    then_step "it should use strong algorithms and key sizes"

    if [[ -f "$cert_file" ]]; then
        # Check key size
        local key_size=$(openssl x509 -in "$cert_file" -noout -text | grep "Public-Key:" | grep -o "[0-9]\+" | head -1)
        if [[ "$key_size" -ge 2048 ]]; then
            test_pass "Key Size Security" "Certificate uses strong key size ($key_size bits)"
        else
            test_fail "Key Size Security" "Certificate uses weak key size ($key_size bits)"
        fi

        # Check signature algorithm
        if openssl x509 -in "$cert_file" -noout -text | grep -q "sha256WithRSAEncryption"; then
            test_pass "Signature Algorithm Security" "Certificate uses SHA-256 signature algorithm"
        else
            test_fail "Signature Algorithm Security" "Certificate uses weak signature algorithm"
        fi
    fi
}

# BDD Test Suite: Certificate Deployment Scenarios
test_certificate_deployment_bdd() {
    echo -e "\n${PURPLE}🚀 BDD Scenario Testing: Certificate Deployment${NC}"

    # Scenario 1: Environment configuration
    echo -e "\n${BLUE}Scenario 1: Environment configuration setup${NC}"
    given "SSL certificates are generated"
    when "I set up the environment configuration"
    then_step "the configuration should point to the correct certificate paths"

    local env_file="$PROJECT_ROOT/.env.ssl"
    if [[ -f "$env_file" ]]; then
        if grep -q "SSL_CERT_PATH=./ssl/dev/server.crt" "$env_file"; then
            test_pass "Environment Certificate Path" "SSL_CERT_PATH correctly configured"
        else
            test_fail "Environment Certificate Path" "SSL_CERT_PATH not correctly configured"
        fi

        if grep -q "SSL_KEY_PATH=./ssl/dev/server.key" "$env_file"; then
            test_pass "Environment Key Path" "SSL_KEY_PATH correctly configured"
        else
            test_fail "Environment Key Path" "SSL_KEY_PATH not correctly configured"
        fi

        if grep -q "SSL_ENABLED=true" "$env_file"; then
            test_pass "Environment SSL Enabled" "SSL is enabled in configuration"
        else
            test_fail "Environment SSL Enabled" "SSL is not enabled in configuration"
        fi
    else
        test_fail "Environment Configuration" "Environment file not found"
    fi

    # Scenario 2: Certificate validation in deployment
    echo -e "\n${BLUE}Scenario 2: Certificate validation during deployment${NC}"
    given "certificates are ready for deployment"
    when "I run the deployment validation"
    then_step "all certificate checks should pass"

    # Test using the deployment script's validation
    cd "$PROJECT_ROOT"
    if LOG_FILE="/tmp/bdd_deploy_test.log" "$SSL_DIR/deploy-certificates.sh" --environment development &>/dev/null; then
        test_pass "Deployment Validation" "Certificate deployment validation passed"
    else
        test_fail "Deployment Validation" "Certificate deployment validation failed"
    fi
}

# Main BDD test execution
run_bdd_certificate_tests() {
    echo -e "${PURPLE}🎭 Behavior-Driven Development (BDD) Test Suite${NC}"
    echo -e "${PURPLE}SSL Certificate Management Scenarios${NC}"
    echo "================================================="

    run_test_suite "Certificate Generation (BDD)" test_certificate_generation_bdd
    run_test_suite "Certificate Validation (BDD)" test_certificate_validation_bdd
    run_test_suite "Certificate Security (BDD)" test_certificate_security_bdd
    run_test_suite "Certificate Deployment (BDD)" test_certificate_deployment_bdd
}

# Export functions for use in main test runner
export -f test_certificate_generation_bdd
export -f test_certificate_validation_bdd
export -f test_certificate_security_bdd
export -f test_certificate_deployment_bdd
export -f run_bdd_certificate_tests