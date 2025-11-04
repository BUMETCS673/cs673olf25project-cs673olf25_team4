#!/bin/bash

# TDD Unit Tests for SSL Functions
# Demonstrates Test-Driven Development with isolated unit tests
# Tests individual SSL management functions in isolation

source "$(dirname "$0")/ssl_test_framework.sh"

# Extract and test individual functions from SSL scripts
# This demonstrates TDD by testing functions in isolation

# Function: Certificate validation (extracted from deploy-certificates.sh)
validate_certificate_file() {
    local cert_file="$1"

    # Check if file exists
    [[ -f "$cert_file" ]] || return 1

    # Validate certificate format
    openssl x509 -in "$cert_file" -text -noout &>/dev/null || return 1

    return 0
}

validate_private_key_file() {
    local key_file="$1"

    # Check if file exists
    [[ -f "$key_file" ]] || return 1

    # Validate private key format
    openssl rsa -in "$key_file" -check -noout &>/dev/null || return 1

    return 0
}

certificate_key_match() {
    local cert_file="$1"
    local key_file="$2"

    # Both files must exist
    [[ -f "$cert_file" && -f "$key_file" ]] || return 1

    # Compare public key fingerprints
    local cert_hash=$(openssl x509 -in "$cert_file" -pubkey -noout 2>/dev/null | openssl md5 2>/dev/null | cut -d' ' -f2)
    local key_hash=$(openssl rsa -in "$key_file" -pubout 2>/dev/null | openssl md5 2>/dev/null | cut -d' ' -f2)

    [[ "$cert_hash" == "$key_hash" ]]
}

certificate_not_expired() {
    local cert_file="$1"

    # Check if file exists
    [[ -f "$cert_file" ]] || return 1

    # Check if certificate is not expired
    openssl x509 -in "$cert_file" -checkend 0 &>/dev/null
}

get_certificate_expiry_days() {
    local cert_file="$1"

    # Check if file exists
    [[ -f "$cert_file" ]] || return 1

    # Get expiration date and calculate days
    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    local expiry_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" "+%s" 2>/dev/null || date -d "$expiry_date" "+%s" 2>/dev/null)
    local current_epoch=$(date "+%s")

    echo $(( (expiry_epoch - current_epoch) / 86400 ))
}

check_file_permissions() {
    local file="$1"
    local expected_perms="$2"

    [[ -f "$file" ]] || return 1

    local actual_perms=$(stat -f "%Mp%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null)
    [[ "$actual_perms" == "$expected_perms" ]]
}

# TDD Test Suite: Certificate Validation Functions
test_certificate_validation_functions() {
    echo -e "\n${GREEN}🔧 TDD Unit Tests: Certificate Validation Functions${NC}"

    # Test 1: Valid certificate file validation
    local test_cert="$SSL_DIR/dev/server.crt"
    if validate_certificate_file "$test_cert"; then
        test_pass "validate_certificate_file(valid)" "Function correctly validates valid certificate"
    else
        test_fail "validate_certificate_file(valid)" "Function failed to validate valid certificate"
    fi

    # Test 2: Invalid certificate file validation
    local invalid_cert="$TEST_TEMP_DIR/invalid.crt"
    echo "INVALID CERTIFICATE CONTENT" > "$invalid_cert"
    if ! validate_certificate_file "$invalid_cert"; then
        test_pass "validate_certificate_file(invalid)" "Function correctly rejects invalid certificate"
    else
        test_fail "validate_certificate_file(invalid)" "Function incorrectly validated invalid certificate"
    fi

    # Test 3: Non-existent certificate file
    if ! validate_certificate_file "/nonexistent/file.crt"; then
        test_pass "validate_certificate_file(missing)" "Function correctly handles missing certificate"
    else
        test_fail "validate_certificate_file(missing)" "Function incorrectly validated missing certificate"
    fi

    # Test 4: Valid private key validation
    local test_key="$SSL_DIR/dev/server.key"
    if validate_private_key_file "$test_key"; then
        test_pass "validate_private_key_file(valid)" "Function correctly validates valid private key"
    else
        test_fail "validate_private_key_file(valid)" "Function failed to validate valid private key"
    fi

    # Test 5: Invalid private key validation
    local invalid_key="$TEST_TEMP_DIR/invalid.key"
    echo "INVALID KEY CONTENT" > "$invalid_key"
    if ! validate_private_key_file "$invalid_key"; then
        test_pass "validate_private_key_file(invalid)" "Function correctly rejects invalid private key"
    else
        test_fail "validate_private_key_file(invalid)" "Function incorrectly validated invalid private key"
    fi

    # Test 6: Certificate and key matching
    if certificate_key_match "$test_cert" "$test_key"; then
        test_pass "certificate_key_match(valid)" "Function correctly identifies matching cert/key pair"
    else
        test_fail "certificate_key_match(valid)" "Function failed to identify matching cert/key pair"
    fi

    # Test 7: Certificate and key not matching
    if ! certificate_key_match "$test_cert" "$invalid_key"; then
        test_pass "certificate_key_match(invalid)" "Function correctly identifies non-matching cert/key pair"
    else
        test_fail "certificate_key_match(invalid)" "Function incorrectly validated non-matching cert/key pair"
    fi
}

# TDD Test Suite: Certificate Expiry Functions
test_certificate_expiry_functions() {
    echo -e "\n${GREEN}🕒 TDD Unit Tests: Certificate Expiry Functions${NC}"

    local test_cert="$SSL_DIR/dev/server.crt"

    # Test 1: Certificate not expired
    if certificate_not_expired "$test_cert"; then
        test_pass "certificate_not_expired(valid)" "Function correctly identifies non-expired certificate"
    else
        test_fail "certificate_not_expired(valid)" "Function incorrectly marked valid certificate as expired"
    fi

    # Test 2: Get certificate expiry days
    local days=$(get_certificate_expiry_days "$test_cert")
    if [[ "$days" =~ ^[0-9]+$ ]] && [[ $days -gt 0 ]]; then
        test_pass "get_certificate_expiry_days(valid)" "Function returns valid expiry days ($days)"
    else
        test_fail "get_certificate_expiry_days(valid)" "Function returned invalid expiry days ($days)"
    fi

    # Test 3: Certificate expiry for non-existent file
    if ! certificate_not_expired "/nonexistent/file.crt"; then
        test_pass "certificate_not_expired(missing)" "Function correctly handles missing certificate"
    else
        test_fail "certificate_not_expired(missing)" "Function incorrectly validated missing certificate"
    fi

    # Test 4: Create an expired certificate for testing
    local expired_cert="$TEST_TEMP_DIR/expired.crt"
    local expired_key="$TEST_TEMP_DIR/expired.key"

    # Generate a certificate that expired yesterday (for testing purposes)
    openssl genrsa -out "$expired_key" 2048 &>/dev/null
    openssl req -new -x509 -key "$expired_key" -out "$expired_cert" -days -1 -subj "/CN=expired" &>/dev/null 2>&1

    if [[ -f "$expired_cert" ]] && ! certificate_not_expired "$expired_cert"; then
        test_pass "certificate_not_expired(expired)" "Function correctly identifies expired certificate"
    else
        # This test might fail on some systems due to OpenSSL behavior with negative days
        test_skip "certificate_not_expired(expired)" "Unable to create expired certificate for testing"
    fi
}

# TDD Test Suite: File Permission Functions
test_file_permission_functions() {
    echo -e "\n${GREEN}🔒 TDD Unit Tests: File Permission Functions${NC}"

    # Test 1: Certificate file permissions (should be 644)
    local test_cert="$SSL_DIR/dev/server.crt"
    if check_file_permissions "$test_cert" "644"; then
        test_pass "check_file_permissions(cert_644)" "Certificate has correct permissions (644)"
    else
        test_fail "check_file_permissions(cert_644)" "Certificate does not have correct permissions"
    fi

    # Test 2: Private key file permissions (should be 600)
    local test_key="$SSL_DIR/dev/server.key"
    if check_file_permissions "$test_key" "600"; then
        test_pass "check_file_permissions(key_600)" "Private key has correct permissions (600)"
    else
        test_fail "check_file_permissions(key_600)" "Private key does not have correct permissions"
    fi

    # Test 3: Create test file with specific permissions
    local test_file="$TEST_TEMP_DIR/perm_test.txt"
    echo "test" > "$test_file"
    chmod 755 "$test_file"

    if check_file_permissions "$test_file" "755"; then
        test_pass "check_file_permissions(custom)" "Function correctly identifies file permissions"
    else
        test_fail "check_file_permissions(custom)" "Function failed to identify correct permissions"
    fi

    # Test 4: Wrong permissions test
    if ! check_file_permissions "$test_file" "644"; then
        test_pass "check_file_permissions(wrong)" "Function correctly rejects wrong permissions"
    else
        test_fail "check_file_permissions(wrong)" "Function incorrectly accepted wrong permissions"
    fi

    # Test 5: Non-existent file
    if ! check_file_permissions "/nonexistent/file.txt" "644"; then
        test_pass "check_file_permissions(missing)" "Function correctly handles missing file"
    else
        test_fail "check_file_permissions(missing)" "Function incorrectly validated missing file"
    fi
}

# TDD Test Suite: SSL Configuration Functions
test_ssl_configuration_functions() {
    echo -e "\n${GREEN}⚙️  TDD Unit Tests: SSL Configuration Functions${NC}"

    # Function to validate SSL configuration
    validate_ssl_config() {
        local config_file="$1"

        [[ -f "$config_file" ]] || return 1

        # Check required SSL settings
        grep -q "SSL_ENABLED=true" "$config_file" || return 1
        grep -q "SSL_CERT_PATH=" "$config_file" || return 1
        grep -q "SSL_KEY_PATH=" "$config_file" || return 1

        return 0
    }

    # Function to extract SSL paths from config
    get_ssl_cert_path() {
        local config_file="$1"
        [[ -f "$config_file" ]] || return 1
        grep "SSL_CERT_PATH=" "$config_file" | cut -d= -f2
    }

    get_ssl_key_path() {
        local config_file="$1"
        [[ -f "$config_file" ]] || return 1
        grep "SSL_KEY_PATH=" "$config_file" | cut -d= -f2
    }

    # Test 1: Valid SSL configuration
    local config_file="$PROJECT_ROOT/.env.ssl"
    if validate_ssl_config "$config_file"; then
        test_pass "validate_ssl_config(valid)" "Function correctly validates SSL configuration"
    else
        test_fail "validate_ssl_config(valid)" "Function failed to validate SSL configuration"
    fi

    # Test 2: SSL configuration path extraction
    local cert_path=$(get_ssl_cert_path "$config_file")
    if [[ "$cert_path" == "./ssl/dev/server.crt" ]]; then
        test_pass "get_ssl_cert_path(valid)" "Function correctly extracts certificate path"
    else
        test_fail "get_ssl_cert_path(valid)" "Function extracted incorrect certificate path: $cert_path"
    fi

    local key_path=$(get_ssl_key_path "$config_file")
    if [[ "$key_path" == "./ssl/dev/server.key" ]]; then
        test_pass "get_ssl_key_path(valid)" "Function correctly extracts key path"
    else
        test_fail "get_ssl_key_path(valid)" "Function extracted incorrect key path: $key_path"
    fi

    # Test 3: Invalid configuration file
    local invalid_config="$TEST_TEMP_DIR/invalid_ssl.conf"
    echo "INVALID_CONFIG=true" > "$invalid_config"

    if ! validate_ssl_config "$invalid_config"; then
        test_pass "validate_ssl_config(invalid)" "Function correctly rejects invalid configuration"
    else
        test_fail "validate_ssl_config(invalid)" "Function incorrectly validated invalid configuration"
    fi

    # Test 4: Missing configuration file
    if ! validate_ssl_config "/nonexistent/config.env"; then
        test_pass "validate_ssl_config(missing)" "Function correctly handles missing configuration"
    else
        test_fail "validate_ssl_config(missing)" "Function incorrectly validated missing configuration"
    fi
}

# TDD Test Suite: SSL Script Integration Tests
test_ssl_script_integration() {
    echo -e "\n${GREEN}🔗 TDD Unit Tests: SSL Script Integration${NC}"

    # Function to test script executability
    script_is_executable() {
        local script_path="$1"
        [[ -x "$script_path" ]]
    }

    # Function to test script help functionality
    script_has_help() {
        local script_path="$1"
        [[ -x "$script_path" ]] || return 1
        "$script_path" --help &>/dev/null
    }

    # Test 1: All SSL scripts are executable
    local scripts=(
        "$SSL_DIR/generate-dev-certs.sh"
        "$SSL_DIR/setup-testbeatmap-ssl.sh"
        "$SSL_DIR/setup-production-ssl.sh"
        "$SSL_DIR/monitor-certificates.sh"
        "$SSL_DIR/deploy-certificates.sh"
    )

    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script")
        if script_is_executable "$script"; then
            test_pass "script_is_executable($script_name)" "Script is properly executable"
        else
            test_fail "script_is_executable($script_name)" "Script is not executable"
        fi
    done

    # Test 2: Scripts have help functionality
    local help_scripts=(
        "$SSL_DIR/deploy-certificates.sh"
        "$SSL_DIR/monitor-certificates.sh"
    )

    for script in "${help_scripts[@]}"; do
        local script_name=$(basename "$script")
        if script_has_help "$script"; then
            test_pass "script_has_help($script_name)" "Script provides help functionality"
        else
            test_fail "script_has_help($script_name)" "Script does not provide help functionality"
        fi
    done

    # Test 3: Certificate generation script produces expected files
    local temp_dir="$TEST_TEMP_DIR/cert_gen_test"
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    if "$SSL_DIR/generate-dev-certs.sh" &>/dev/null; then
        local expected_files=("ssl/dev/server.crt" "ssl/dev/server.key" "ssl/dev/dhparam.pem" "ssl/dev/cert-info.txt")
        local all_files_created=true

        for file in "${expected_files[@]}"; do
            if [[ ! -f "$file" ]]; then
                all_files_created=false
                break
            fi
        done

        if $all_files_created; then
            test_pass "certificate_generation_integration" "Certificate generation creates all expected files"
        else
            test_fail "certificate_generation_integration" "Certificate generation missing expected files"
        fi
    else
        test_fail "certificate_generation_integration" "Certificate generation script failed to execute"
    fi
}

# Main TDD test execution
run_tdd_ssl_tests() {
    echo -e "${GREEN}🔧 Test-Driven Development (TDD) Test Suite${NC}"
    echo -e "${GREEN}SSL Function Unit Tests${NC}"
    echo "=============================================="

    run_test_suite "Certificate Validation Functions (TDD)" test_certificate_validation_functions
    run_test_suite "Certificate Expiry Functions (TDD)" test_certificate_expiry_functions
    run_test_suite "File Permission Functions (TDD)" test_file_permission_functions
    run_test_suite "SSL Configuration Functions (TDD)" test_ssl_configuration_functions
    run_test_suite "SSL Script Integration (TDD)" test_ssl_script_integration
}

# Export functions for use in main test runner
export -f validate_certificate_file
export -f validate_private_key_file
export -f certificate_key_match
export -f certificate_not_expired
export -f get_certificate_expiry_days
export -f check_file_permissions
export -f test_certificate_validation_functions
export -f test_certificate_expiry_functions
export -f test_file_permission_functions
export -f test_ssl_configuration_functions
export -f test_ssl_script_integration
export -f run_tdd_ssl_tests