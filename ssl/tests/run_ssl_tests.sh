#!/bin/bash

# SSL Test Suite Runner
# Demonstrates TDD and BDD practices for SSL certificate management
# For CS673 Software Engineering Assignment Demonstration

set -euo pipefail

# Import test framework and test suites
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ssl_test_framework.sh"
source "$SCRIPT_DIR/bdd_certificate_scenarios.sh"
source "$SCRIPT_DIR/tdd_ssl_functions.sh"

# Configuration
DEMO_MODE=false
VERBOSE=false
GENERATE_REPORT=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --demo)
            DEMO_MODE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --no-report)
            GENERATE_REPORT=false
            shift
            ;;
        --help|-h)
            cat << EOF
SSL Test Suite Runner - TDD/BDD Demonstration

Usage: $0 [OPTIONS]

Options:
    --demo          Run in demonstration mode with explanations
    --verbose, -v   Show verbose output
    --no-report     Skip HTML report generation
    --help, -h      Show this help message

Test Types:
    TDD (Test-Driven Development):
        - Unit tests for individual SSL functions
        - Isolated testing of certificate validation logic
        - Red-Green-Refactor methodology demonstration

    BDD (Behavior-Driven Development):
        - Given/When/Then scenario testing
        - User behavior focused test cases
        - Certificate management workflow testing

Examples:
    $0                  # Run all tests with report
    $0 --demo           # Run with educational explanations
    $0 --verbose        # Show detailed test output
    $0 --demo --verbose # Full demonstration mode

This test suite demonstrates software engineering best practices
for the CS673 Software Engineering course assignment.
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Demonstration mode explanations
demo_explain() {
    if [[ "$DEMO_MODE" == "true" ]]; then
        echo -e "${YELLOW}📚 DEMO:${NC} $*"
        sleep 1
    fi
}

demo_pause() {
    if [[ "$DEMO_MODE" == "true" ]]; then
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read -r
    fi
}

# Main test execution function
main() {
    echo -e "${BLUE}🎓 CS673 Software Engineering Assignment${NC}"
    echo -e "${BLUE}SSL Certificate Management - TDD/BDD Demonstration${NC}"
    echo "============================================================"
    echo ""

    demo_explain "This demonstration shows Test-Driven Development (TDD) and Behavior-Driven Development (BDD) practices applied to SSL certificate management infrastructure."
    demo_pause

    # Initialize test framework
    init_test_framework

    demo_explain "TDD focuses on writing tests first, then implementing code to make tests pass. We'll test individual functions in isolation."
    demo_explain "BDD focuses on behavior and user scenarios using Given/When/Then format to describe expected system behavior."
    demo_pause

    # Phase 1: TDD Demonstration
    echo -e "\n${GREEN}======================================================================================================${NC}"
    echo -e "${GREEN}🔧 PHASE 1: TEST-DRIVEN DEVELOPMENT (TDD) DEMONSTRATION${NC}"
    echo -e "${GREEN}======================================================================================================${NC}"

    demo_explain "TDD follows the Red-Green-Refactor cycle:"
    demo_explain "1. RED: Write a failing test"
    demo_explain "2. GREEN: Write minimal code to make the test pass"
    demo_explain "3. REFACTOR: Improve the code while keeping tests passing"
    demo_explain ""
    demo_explain "We're demonstrating this with SSL certificate validation functions that were extracted and unit tested."
    demo_pause

    # Run TDD tests
    run_tdd_ssl_tests

    demo_explain "TDD benefits demonstrated:"
    demo_explain "✅ Individual functions tested in isolation"
    demo_explain "✅ Edge cases and error conditions covered"
    demo_explain "✅ Refactoring safety through comprehensive test coverage"
    demo_explain "✅ Clear function contracts and expected behavior"
    demo_pause

    # Phase 2: BDD Demonstration
    echo -e "\n${PURPLE}======================================================================================================${NC}"
    echo -e "${PURPLE}🎭 PHASE 2: BEHAVIOR-DRIVEN DEVELOPMENT (BDD) DEMONSTRATION${NC}"
    echo -e "${PURPLE}======================================================================================================${NC}"

    demo_explain "BDD uses Given/When/Then scenarios to describe system behavior from a user perspective:"
    demo_explain "• GIVEN: The initial context or state"
    demo_explain "• WHEN: The action or event that triggers the behavior"
    demo_explain "• THEN: The expected outcome or result"
    demo_explain ""
    demo_explain "We're testing SSL certificate management workflows that users would perform."
    demo_pause

    # Run BDD tests
    run_bdd_certificate_tests

    demo_explain "BDD benefits demonstrated:"
    demo_explain "✅ Tests written in business-readable language"
    demo_explain "✅ Focus on user behavior and system interactions"
    demo_explain "✅ Clear specification of expected system behavior"
    demo_explain "✅ Better communication between technical and non-technical stakeholders"
    demo_pause

    # Phase 3: Integration and End-to-End Testing
    echo -e "\n${BLUE}======================================================================================================${NC}"
    echo -e "${BLUE}🔗 PHASE 3: INTEGRATION TESTING DEMONSTRATION${NC}"
    echo -e "${BLUE}======================================================================================================${NC}"

    demo_explain "Integration tests verify that different components work together correctly."
    demo_explain "We're testing the complete SSL certificate generation and validation pipeline."
    demo_pause

    run_test_suite "SSL Infrastructure Integration" test_ssl_infrastructure_integration

    # Summary and methodology explanation
    echo -e "\n${YELLOW}======================================================================================================${NC}"
    echo -e "${YELLOW}📋 METHODOLOGY SUMMARY AND EDUCATIONAL VALUE${NC}"
    echo -e "${YELLOW}======================================================================================================${NC}"

    demo_explain "Software Engineering Methodologies Demonstrated:"
    demo_explain ""
    demo_explain "1. TEST-DRIVEN DEVELOPMENT (TDD):"
    demo_explain "   • Write tests before implementation"
    demo_explain "   • Focus on function-level correctness"
    demo_explain "   • Ensure code coverage and quality"
    demo_explain "   • Enable safe refactoring"
    demo_explain ""
    demo_explain "2. BEHAVIOR-DRIVEN DEVELOPMENT (BDD):"
    demo_explain "   • Describe behavior in business terms"
    demo_explain "   • Focus on user scenarios and workflows"
    demo_explain "   • Bridge communication between stakeholders"
    demo_explain "   • Validate system meets requirements"
    demo_explain ""
    demo_explain "3. CONTINUOUS TESTING:"
    demo_explain "   • Automated test execution"
    demo_explain "   • Immediate feedback on changes"
    demo_explain "   • Prevention of regression bugs"
    demo_explain "   • Improved code quality and reliability"
    demo_pause

    # Show test summary
    show_test_summary

    # Generate reports
    if [[ "$GENERATE_REPORT" == "true" ]]; then
        echo -e "\n${BLUE}📊 Generating Test Reports...${NC}"
        generate_test_report
        generate_demo_documentation
    fi

    # Cleanup
    cleanup_test_framework

    echo -e "\n${GREEN}🎉 TDD/BDD Demonstration Complete!${NC}"
    echo -e "${GREEN}This demonstration shows practical application of software engineering testing methodologies.${NC}"

    if [[ "$GENERATE_REPORT" == "true" ]]; then
        echo -e "\n${BLUE}📁 Generated Files for Assignment Submission:${NC}"
        echo "• Test Report: $TEST_RESULTS_DIR/test_report.html"
        echo "• Demo Documentation: $TEST_RESULTS_DIR/methodology_demo.md"
        echo "• Test Results Log: $TEST_RESULTS_DIR/results.log"
    fi
}

# Integration test function
test_ssl_infrastructure_integration() {
    echo -e "\n${BLUE}🔗 Integration Testing: Complete SSL Infrastructure${NC}"

    # Test 1: End-to-end certificate generation and validation
    given "a clean project environment"
    when "I generate certificates and validate the complete pipeline"
    then_step "all SSL infrastructure components should work together"

    local temp_project="$TEST_TEMP_DIR/integration_test"
    mkdir -p "$temp_project"
    cd "$temp_project"

    # Copy SSL scripts to test environment
    cp -r "$SSL_DIR"/*.sh .
    mkdir -p ssl

    # Test complete pipeline
    local pipeline_success=true

    # Step 1: Generate certificates
    if ! ./generate-dev-certs.sh &>/dev/null; then
        pipeline_success=false
        test_fail "SSL Pipeline Step 1" "Certificate generation failed"
    fi

    # Step 2: Validate certificates
    if $pipeline_success && [[ -f "ssl/dev/server.crt" && -f "ssl/dev/server.key" ]]; then
        # Test certificate validation
        if validate_certificate_file "ssl/dev/server.crt" && validate_private_key_file "ssl/dev/server.key"; then
            test_pass "SSL Pipeline Step 2" "Certificate validation successful"
        else
            pipeline_success=false
            test_fail "SSL Pipeline Step 2" "Certificate validation failed"
        fi
    else
        pipeline_success=false
        test_fail "SSL Pipeline Step 2" "Certificate files not generated"
    fi

    # Step 3: Test certificate matching
    if $pipeline_success && certificate_key_match "ssl/dev/server.crt" "ssl/dev/server.key"; then
        test_pass "SSL Pipeline Step 3" "Certificate and key matching verification successful"
    else
        pipeline_success=false
        test_fail "SSL Pipeline Step 3" "Certificate and key matching failed"
    fi

    # Step 4: Test deployment validation
    if $pipeline_success; then
        # Create minimal environment configuration
        cat > .env.ssl << EOF
SSL_ENABLED=true
SSL_CERT_PATH=./ssl/dev/server.crt
SSL_KEY_PATH=./ssl/dev/server.key
EOF

        if LOG_FILE="/tmp/integration_deploy.log" ./deploy-certificates.sh --environment development &>/dev/null; then
            test_pass "SSL Pipeline Step 4" "Certificate deployment validation successful"
        else
            pipeline_success=false
            test_fail "SSL Pipeline Step 4" "Certificate deployment validation failed"
        fi
    fi

    # Overall integration test result
    if $pipeline_success; then
        test_pass "SSL Infrastructure Integration" "Complete SSL pipeline working correctly"
    else
        test_fail "SSL Infrastructure Integration" "SSL pipeline has integration issues"
    fi
}

# Generate demonstration documentation
generate_demo_documentation() {
    local doc_file="$TEST_RESULTS_DIR/methodology_demo.md"

    cat > "$doc_file" << EOF
# CS673 Software Engineering Assignment
## TDD/BDD Methodology Demonstration

### SSL Certificate Management Implementation

**Student:** [Your Name]
**Course:** CS673 Software Engineering
**Date:** $(date '+%Y-%m-%d')

---

## Overview

This document demonstrates the practical application of Test-Driven Development (TDD) and Behavior-Driven Development (BDD) methodologies in the implementation of SSL certificate management infrastructure for the BeatMap application.

## Methodologies Demonstrated

### 1. Test-Driven Development (TDD)

**Principles Applied:**
- **Red-Green-Refactor Cycle:** Write failing tests first, implement minimal code to pass, then refactor
- **Unit Testing:** Individual functions tested in isolation
- **Code Coverage:** Comprehensive testing of edge cases and error conditions
- **Refactoring Safety:** Tests enable safe code improvements

**Implementation Examples:**
- \`validate_certificate_file()\` - Tests certificate format validation
- \`certificate_key_match()\` - Tests certificate/key pair matching
- \`check_file_permissions()\` - Tests security permission validation
- \`get_certificate_expiry_days()\` - Tests certificate expiration calculations

**Files:**
- \`ssl/tests/tdd_ssl_functions.sh\` - Unit tests for SSL validation functions
- \`ssl/tests/ssl_test_framework.sh\` - Testing framework infrastructure

### 2. Behavior-Driven Development (BDD)

**Principles Applied:**
- **Given/When/Then Scenarios:** Clear specification of system behavior
- **User-Focused Testing:** Tests written from user perspective
- **Business-Readable Language:** Tests serve as living documentation
- **Stakeholder Communication:** Bridge between technical and business requirements

**Implementation Examples:**
- **Certificate Generation Scenarios:** User workflow for generating SSL certificates
- **Certificate Validation Scenarios:** System behavior for certificate validation
- **Security Scenarios:** Security-focused user requirements
- **Deployment Scenarios:** Certificate deployment workflows

**Files:**
- \`ssl/tests/bdd_certificate_scenarios.sh\` - BDD scenarios for certificate management

### 3. Integration Testing

**Principles Applied:**
- **End-to-End Testing:** Complete system workflow validation
- **Component Integration:** Verify components work together correctly
- **Pipeline Testing:** Test complete certificate generation and validation pipeline

## Test Results Summary

**Total Tests Executed:** $TOTAL_TESTS
**Passed:** $PASSED_TESTS
**Failed:** $FAILED_TESTS
**Skipped:** $SKIPPED_TESTS
**Success Rate:** $(( TOTAL_TESTS > 0 ? (PASSED_TESTS * 100) / TOTAL_TESTS : 0 ))%

## Software Engineering Benefits Demonstrated

### Quality Assurance
- Automated testing prevents regression bugs
- Comprehensive test coverage ensures reliability
- Continuous validation of system behavior

### Maintainability
- Tests serve as living documentation
- Safe refactoring through test protection
- Clear specification of expected behavior

### Communication
- BDD scenarios bridge technical and business stakeholders
- Tests document system requirements
- Clear specification of user workflows

### Security
- Security-focused testing scenarios
- Validation of certificate handling procedures
- File permission and access control testing

## Code Quality Practices

1. **Modular Design:** Functions extracted for individual testing
2. **Error Handling:** Comprehensive edge case coverage
3. **Security First:** Security scenarios integrated throughout
4. **Documentation:** Self-documenting code through tests

## Assignment Learning Outcomes

This implementation demonstrates:

✅ **Understanding of TDD/BDD Methodologies**
✅ **Practical Application of Testing Frameworks**
✅ **Integration of Security Testing**
✅ **Professional Development Practices**
✅ **Quality Assurance Processes**

## Conclusion

The implementation showcases how TDD and BDD methodologies can be practically applied to real-world software development challenges, specifically in the context of SSL certificate management. The comprehensive testing approach ensures both functional correctness and security compliance while maintaining code quality and enabling future enhancements.

---

*Generated by SSL Testing Framework - CS673 Assignment Demonstration*
EOF

    echo -e "${GREEN}📝 Demo documentation generated: $doc_file${NC}"
}

# Export functions
export -f test_ssl_infrastructure_integration
export -f demo_explain
export -f demo_pause

# Run main function
main "$@"