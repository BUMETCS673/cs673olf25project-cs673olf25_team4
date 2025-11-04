#!/bin/bash

# SSL Testing Framework
# Provides TDD/BDD testing infrastructure for SSL certificate management
# Demonstrates Test-Driven Development and Behavior-Driven Development practices

set -euo pipefail

# Test framework configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$(dirname "$TEST_DIR")"
PROJECT_ROOT="$(dirname "$SSL_DIR")"
TEST_RESULTS_DIR="$TEST_DIR/results"
TEST_TEMP_DIR="$TEST_DIR/temp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Initialize test framework
init_test_framework() {
    echo -e "${BLUE}🧪 SSL Testing Framework Initialized${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo "Test Directory: $TEST_DIR"
    echo "SSL Directory: $SSL_DIR"
    echo "Results Directory: $TEST_RESULTS_DIR"
    echo ""

    # Create test directories
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$TEST_TEMP_DIR"

    # Clean previous results
    rm -f "$TEST_RESULTS_DIR"/*.log
    rm -rf "$TEST_TEMP_DIR"/*
}

# Test result functions
test_pass() {
    local test_name="$1"
    local message="${2:-}"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
    echo -e "${GREEN}✅ PASS${NC}: $test_name ${message:+- $message}"
    echo "PASS: $test_name - $message" >> "$TEST_RESULTS_DIR/results.log"
}

test_fail() {
    local test_name="$1"
    local message="${2:-}"
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
    echo -e "${RED}❌ FAIL${NC}: $test_name ${message:+- $message}"
    echo "FAIL: $test_name - $message" >> "$TEST_RESULTS_DIR/results.log"
}

test_skip() {
    local test_name="$1"
    local reason="${2:-}"
    ((SKIPPED_TESTS++))
    ((TOTAL_TESTS++))
    echo -e "${YELLOW}⏭️  SKIP${NC}: $test_name ${reason:+- $reason}"
    echo "SKIP: $test_name - $reason" >> "$TEST_RESULTS_DIR/results.log"
}

# BDD helper functions
given() {
    echo -e "${PURPLE}Given${NC}: $*"
}

when() {
    echo -e "${BLUE}When${NC}: $*"
}

then_step() {
    echo -e "${GREEN}Then${NC}: $*"
}

# Test assertion functions
assert_file_exists() {
    local file="$1"
    local test_name="${2:-File existence check}"

    if [[ -f "$file" ]]; then
        test_pass "$test_name" "File exists: $file"
        return 0
    else
        test_fail "$test_name" "File does not exist: $file"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local test_name="${2:-File non-existence check}"

    if [[ ! -f "$file" ]]; then
        test_pass "$test_name" "File correctly does not exist: $file"
        return 0
    else
        test_fail "$test_name" "File unexpectedly exists: $file"
        return 1
    fi
}

assert_directory_exists() {
    local dir="$1"
    local test_name="${2:-Directory existence check}"

    if [[ -d "$dir" ]]; then
        test_pass "$test_name" "Directory exists: $dir"
        return 0
    else
        test_fail "$test_name" "Directory does not exist: $dir"
        return 1
    fi
}

assert_command_succeeds() {
    local command="$1"
    local test_name="${2:-Command execution check}"

    if eval "$command" &>/dev/null; then
        test_pass "$test_name" "Command succeeded: $command"
        return 0
    else
        test_fail "$test_name" "Command failed: $command"
        return 1
    fi
}

assert_command_fails() {
    local command="$1"
    local test_name="${2:-Command failure check}"

    if ! eval "$command" &>/dev/null; then
        test_pass "$test_name" "Command correctly failed: $command"
        return 0
    else
        test_fail "$test_name" "Command unexpectedly succeeded: $command"
        return 1
    fi
}

assert_file_permissions() {
    local file="$1"
    local expected_perms="$2"
    local test_name="${3:-File permissions check}"

    if [[ -f "$file" ]]; then
        local actual_perms=$(stat -f "%Mp%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null)
        if [[ "$actual_perms" == "$expected_perms" ]]; then
            test_pass "$test_name" "Correct permissions $expected_perms for $file"
            return 0
        else
            test_fail "$test_name" "Expected $expected_perms, got $actual_perms for $file"
            return 1
        fi
    else
        test_fail "$test_name" "File does not exist: $file"
        return 1
    fi
}

assert_string_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="${3:-String contains check}"

    if [[ "$haystack" == *"$needle"* ]]; then
        test_pass "$test_name" "String contains expected content"
        return 0
    else
        test_fail "$test_name" "String does not contain '$needle'"
        return 1
    fi
}

# Test execution wrapper
run_test_suite() {
    local suite_name="$1"
    local test_function="$2"

    echo -e "\n${PURPLE}📋 Test Suite: $suite_name${NC}"
    echo "----------------------------------------"

    # Run the test function
    $test_function

    echo "----------------------------------------"
}

# Generate test report
generate_test_report() {
    local report_file="$TEST_RESULTS_DIR/test_report.html"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SSL Infrastructure Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .pass { color: green; }
        .fail { color: red; }
        .skip { color: orange; }
        .summary { background: #f9f9f9; padding: 15px; margin: 20px 0; border-left: 4px solid #007cba; }
        pre { background: #f4f4f4; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔒 SSL Infrastructure Test Report</h1>
        <p><strong>Generated:</strong> $timestamp</p>
        <p><strong>Framework:</strong> TDD/BDD SSL Testing Framework</p>
    </div>

    <div class="summary">
        <h2>📊 Test Summary</h2>
        <ul>
            <li><strong>Total Tests:</strong> $TOTAL_TESTS</li>
            <li class="pass"><strong>Passed:</strong> $PASSED_TESTS</li>
            <li class="fail"><strong>Failed:</strong> $FAILED_TESTS</li>
            <li class="skip"><strong>Skipped:</strong> $SKIPPED_TESTS</li>
            <li><strong>Success Rate:</strong> $(( TOTAL_TESTS > 0 ? (PASSED_TESTS * 100) / TOTAL_TESTS : 0 ))%</li>
        </ul>
    </div>

    <h2>📝 Detailed Results</h2>
    <pre>
EOF

    if [[ -f "$TEST_RESULTS_DIR/results.log" ]]; then
        cat "$TEST_RESULTS_DIR/results.log" >> "$report_file"
    fi

    cat >> "$report_file" << EOF
    </pre>

    <h2>🏗️ TDD/BDD Methodology Demonstration</h2>
    <p>This test suite demonstrates:</p>
    <ul>
        <li><strong>Test-Driven Development (TDD):</strong> Unit tests for SSL validation functions</li>
        <li><strong>Behavior-Driven Development (BDD):</strong> Given/When/Then scenarios for certificate management</li>
        <li><strong>Continuous Testing:</strong> Automated validation of SSL infrastructure</li>
        <li><strong>Security Testing:</strong> Certificate validation and permission checks</li>
    </ul>

    <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ccc; color: #666;">
        <p>Generated by SSL Testing Framework - BeatMap HTTPS Implementation</p>
    </footer>
</body>
</html>
EOF

    echo -e "\n${GREEN}📊 Test report generated: $report_file${NC}"
}

# Final test summary
show_test_summary() {
    echo -e "\n${BLUE}📊 Test Execution Summary${NC}"
    echo "=========================="
    echo -e "Total Tests: ${TOTAL_TESTS}"
    echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
    echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"
    echo -e "${YELLOW}Skipped: ${SKIPPED_TESTS}${NC}"

    if [[ $TOTAL_TESTS -gt 0 ]]; then
        local success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
        echo -e "Success Rate: ${success_rate}%"

        if [[ $FAILED_TESTS -eq 0 ]]; then
            echo -e "\n${GREEN}🎉 All tests passed!${NC}"
            return 0
        else
            echo -e "\n${RED}❌ Some tests failed. Check the results above.${NC}"
            return 1
        fi
    else
        echo -e "\n${YELLOW}⚠️  No tests were executed.${NC}"
        return 1
    fi
}

# Cleanup test framework
cleanup_test_framework() {
    echo -e "\n${BLUE}🧹 Cleaning up test framework...${NC}"

    # Keep results but clean temp files
    rm -rf "$TEST_TEMP_DIR"

    echo -e "${GREEN}✅ Cleanup complete${NC}"
}