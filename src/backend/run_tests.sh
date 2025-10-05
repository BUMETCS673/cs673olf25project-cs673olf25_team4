#!/bin/bash

# Simple SSL TDD/BDD Test Runner
# Minimal script for running SSL tests

set -e

echo "🧪 Running Simple SSL TDD/BDD Tests"
echo "===================================="

# Navigate to backend directory
cd "$(dirname "$0")"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt > /dev/null 2>&1

# Set PYTHONPATH
export PYTHONPATH="$(pwd)"

# Run tests based on argument
TEST_TYPE=${1:-all}

case $TEST_TYPE in
    tdd)
        echo "🔴🟢♻️ Running TDD Tests..."
        python -m pytest tests/test_ssl_simple.py -v
        ;;
    bdd)
        echo "📝 Running BDD Tests..."
        python -m pytest tests/step_definitions/test_ssl_simple_steps.py -v
        ;;
    all)
        echo "🔴🟢♻️ Running TDD Tests..."
        python -m pytest tests/test_ssl_simple.py -v
        echo ""
        echo "📝 Running BDD Tests..."
        python -m pytest tests/step_definitions/test_ssl_simple_steps.py -v
        ;;
    *)
        echo "Usage: $0 [tdd|bdd|all]"
        echo "  tdd - Run TDD unit tests"
        echo "  bdd - Run BDD feature tests"
        echo "  all - Run both (default)"
        exit 1
        ;;
esac

echo ""
echo "✅ SSL Tests Complete!"