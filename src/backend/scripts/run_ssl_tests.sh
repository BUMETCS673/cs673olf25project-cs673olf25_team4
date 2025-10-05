#!/bin/bash

# SSL/HTTPS TDD/BDD Test Runner Script
# Comprehensive test execution for BeatMap Backend SSL Support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}\")\" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$(dirname "$BACKEND_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 BeatMap SSL/HTTPS TDD/BDD Test Runner${NC}"
echo "=========================================="

# Default values
TEST_TYPE=${1:-all}
ENVIRONMENT=${2:-test}
PARALLEL=${3:-false}

show_usage() {
    echo "Usage: $0 [test_type] [environment] [parallel]"
    echo ""
    echo "Test Types:"
    echo "  all         - Run all SSL tests (default)"
    echo "  tdd         - Run TDD unit tests only"
    echo "  bdd         - Run BDD feature tests only"
    echo "  integration - Run integration tests only"
    echo "  coverage    - Run tests with coverage report"
    echo "  security    - Run security-focused tests"
    echo "  smoke       - Run quick smoke tests"
    echo "  docker      - Run all tests in Docker containers"
    echo ""
    echo "Environments:"
    echo "  test        - Test environment (default)"
    echo "  development - Development environment"
    echo "  staging     - Staging environment"
    echo "  production  - Production environment"
    echo ""
    echo "Examples:"
    echo "  $0 tdd test"
    echo "  $0 bdd production"
    echo "  $0 coverage test true"
    echo "  $0 docker"
}

run_local_tests() {
    echo -e "${YELLOW}Setting up local test environment...${NC}"
    cd "$BACKEND_DIR"

    # Check if virtual environment exists
    if [ ! -d "venv" ]; then
        echo -e "${YELLOW}Creating virtual environment...${NC}"
        python3 -m venv venv
    fi

    # Activate virtual environment
    echo -e "${YELLOW}Activating virtual environment...${NC}"
    source venv/bin/activate

    # Install dependencies
    echo -e "${YELLOW}Installing dependencies...${NC}"
    pip install -r requirements.txt > /dev/null 2>&1

    # Set environment variables
    export ENVIRONMENT=$ENVIRONMENT
    export PYTHONPATH="$BACKEND_DIR"

    case $TEST_TYPE in
        tdd)
            echo -e "${PURPLE}Running TDD Unit Tests...${NC}"
            if [ "$PARALLEL" = "true" ]; then
                python -m pytest tests/test_ssl_tdd.py -v -n auto --tb=short -m "tdd"
            else
                python -m pytest tests/test_ssl_tdd.py -v --tb=short -m "tdd"
            fi
            ;;

        bdd)
            echo -e "${PURPLE}Running BDD Feature Tests...${NC}"
            if [ "$PARALLEL" = "true" ]; then
                python -m pytest tests/step_definitions/ -v -n auto --tb=short -m "bdd"
            else
                python -m pytest tests/step_definitions/ -v --tb=short -m "bdd"
            fi
            ;;

        integration)
            echo -e "${PURPLE}Running Integration Tests...${NC}"
            if [ "$PARALLEL" = "true" ]; then
                python -m pytest tests/test_ssl_integration.py -v -n auto --tb=short -m "integration"
            else
                python -m pytest tests/test_ssl_integration.py -v --tb=short -m "integration"
            fi
            ;;

        coverage)
            echo -e "${PURPLE}Running Tests with Coverage...${NC}"
            python -m pytest tests/ --cov=app --cov-report=html --cov-report=term-missing --cov-fail-under=80 -v
            echo -e "${GREEN}Coverage report generated in htmlcov/index.html${NC}"
            ;;

        security)
            echo -e "${PURPLE}Running Security Tests...${NC}"
            if [ "$PARALLEL" = "true" ]; then
                python -m pytest tests/ -v -n auto --tb=short -m "security-headers or https-redirection or cors"
            else
                python -m pytest tests/ -v --tb=short -m "security-headers or https-redirection or cors"
            fi
            ;;

        smoke)
            echo -e "${PURPLE}Running Smoke Tests...${NC}"
            python -m pytest tests/ -v --tb=short -m "smoke" -x
            ;;

        all)
            echo -e "${PURPLE}Running All SSL Tests...${NC}"
            if [ "$PARALLEL" = "true" ]; then
                python -m pytest tests/ -v -n auto --tb=short
            else
                python -m pytest tests/ -v --tb=short
            fi
            ;;

        *)
            echo -e "${RED}❌ Invalid test type: $TEST_TYPE${NC}"
            show_usage
            exit 1
            ;;
    esac
}

run_docker_tests() {
    echo -e "${YELLOW}Running SSL tests in Docker containers...${NC}"
    cd "$SRC_DIR"

    case $TEST_TYPE in
        tdd)
            echo -e "${PURPLE}Running TDD Tests in Docker...${NC}"
            docker-compose -f docker-compose.test.yml up --build tdd-tests
            ;;

        bdd)
            echo -e "${PURPLE}Running BDD Tests in Docker...${NC}"
            docker-compose -f docker-compose.test.yml up --build bdd-tests
            ;;

        integration)
            echo -e "${PURPLE}Running Integration Tests in Docker...${NC}"
            docker-compose -f docker-compose.test.yml up --build integration-tests
            ;;

        coverage)
            echo -e "${PURPLE}Running Coverage Tests in Docker...${NC}"
            docker-compose -f docker-compose.test.yml up --build coverage-tests
            ;;

        security)
            echo -e "${PURPLE}Running Security Tests in Docker...${NC}"
            docker-compose -f docker-compose.test.yml up --build security-tests
            ;;

        smoke)
            echo -e "${PURPLE}Running Smoke Tests in Docker...${NC}"
            docker-compose -f docker-compose.test.yml up --build smoke-tests
            ;;

        all|docker)
            echo -e "${PURPLE}Running All Test Suites in Docker...${NC}"
            docker-compose -f docker-compose.test.yml up --build \
                ssl-tests bdd-tests tdd-tests integration-tests coverage-tests
            ;;

        environments)
            echo -e "${PURPLE}Running Environment-Specific Tests...${NC}"
            docker-compose -f docker-compose.test.yml up --build \
                ssl-test-dev ssl-test-staging ssl-test-production
            ;;

        *)
            echo -e "${RED}❌ Invalid Docker test type: $TEST_TYPE${NC}"
            show_usage
            exit 1
            ;;
    esac

    echo -e "${YELLOW}Cleaning up Docker containers...${NC}"
    docker-compose -f docker-compose.test.yml down --volumes --remove-orphans
}

# Main execution logic
case $TEST_TYPE in
    docker|environments)
        run_docker_tests
        ;;
    help|-h|--help)
        show_usage
        exit 0
        ;;
    *)
        run_local_tests
        ;;
esac

echo ""
echo -e "${GREEN}🎉 SSL/HTTPS Test Execution Complete!${NC}"
echo ""
echo -e "${BLUE}Test Reports Available:${NC}"
echo "  • HTML Coverage: htmlcov/index.html"
echo "  • XML Coverage: coverage.xml"
echo "  • Test Reports: test-reports/"
echo ""
echo -e "${BLUE}Quick Commands:${NC}"
echo "  • Run all tests: $0 all"
echo "  • Run with coverage: $0 coverage"
echo "  • Run in Docker: $0 docker"
echo "  • Run parallel: $0 all test true"