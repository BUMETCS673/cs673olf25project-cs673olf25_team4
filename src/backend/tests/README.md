# 🧪 SSL/HTTPS TDD/BDD Testing Suite

Comprehensive Test-Driven Development (TDD) and Behavior-Driven Development (BDD) testing framework for BeatMap's SSL/HTTPS Backend Support (Section 2.1).

## 📁 Directory Structure

```
src/backend/
├── app/                          # 🏭 PRODUCTION CODE
│   ├── core/
│   │   ├── ssl_settings.py       # SSL configuration settings
│   │   └── middleware.py         # Security middleware
│   ├── api/
│   └── main.py                   # FastAPI application
├── tests/                        # 🧪 TEST CODE (Separate from production)
│   ├── features/                 # BDD Gherkin feature files
│   │   ├── ssl_configuration.feature
│   │   └── security_middleware.feature
│   ├── step_definitions/         # BDD step implementations
│   │   ├── test_ssl_steps.py
│   │   └── test_middleware_steps.py
│   ├── test_ssl_integration.py   # Integration tests
│   ├── test_ssl_tdd.py          # TDD unit tests
│   └── README.md                # This file
├── scripts/
│   └── run_ssl_tests.sh         # Test execution script
├── pytest.ini                   # Pytest configuration
├── Dockerfile.test              # Docker test container
└── requirements.txt             # Dependencies (includes TDD/BDD tools)
```

## 🎯 Test Types

### 1. **TDD Unit Tests** (`test_ssl_tdd.py`)
- **Red-Green-Refactor** cycle
- Unit tests for SSL settings, middleware components
- Edge case and error handling validation
- Fast execution, isolated tests

### 2. **BDD Feature Tests** (`features/` + `step_definitions/`)
- **Gherkin syntax** (Given/When/Then)
- Business-readable scenarios
- End-to-end behavior validation
- Stakeholder communication

### 3. **Integration Tests** (`test_ssl_integration.py`)
- Component interaction testing
- FastAPI application testing
- Environment-specific configuration

## 🚀 Running Tests

### **Quick Start**
```bash
cd src/backend
./scripts/run_ssl_tests.sh
```

### **Local Testing**
```bash
# All tests
./scripts/run_ssl_tests.sh all

# TDD unit tests only
./scripts/run_ssl_tests.sh tdd

# BDD feature tests only
./scripts/run_ssl_tests.sh bdd

# With coverage report
./scripts/run_ssl_tests.sh coverage

# Parallel execution
./scripts/run_ssl_tests.sh all test true
```

### **Docker Testing**
```bash
# All tests in Docker
./scripts/run_ssl_tests.sh docker

# Specific test types in Docker
cd src/
docker-compose -f docker-compose.test.yml up --build tdd-tests
docker-compose -f docker-compose.test.yml up --build bdd-tests
docker-compose -f docker-compose.test.yml up --build integration-tests

# Environment-specific tests
docker-compose -f docker-compose.test.yml up --build ssl-test-dev
docker-compose -f docker-compose.test.yml up --build ssl-test-staging
docker-compose -f docker-compose.test.yml up --build ssl-test-production
```

### **Direct Pytest Commands**
```bash
cd src/backend
source venv/bin/activate

# TDD tests
python -m pytest tests/test_ssl_tdd.py -v -m "tdd"

# BDD tests
python -m pytest tests/step_definitions/ -v -m "bdd"

# Integration tests
python -m pytest tests/test_ssl_integration.py -v -m "integration"

# All tests with coverage
python -m pytest tests/ --cov=app --cov-report=html --cov-report=term-missing
```

## 🏷️ Test Markers

Tests are categorized using pytest markers:

- `@pytest.mark.ssl` - SSL configuration tests
- `@pytest.mark.middleware` - Security middleware tests
- `@pytest.mark.security_headers` - Security headers tests
- `@pytest.mark.https_redirection` - HTTPS redirection tests
- `@pytest.mark.cors` - CORS configuration tests
- `@pytest.mark.tdd` - TDD unit tests
- `@pytest.mark.bdd` - BDD feature tests
- `@pytest.mark.integration` - Integration tests
- `@pytest.mark.smoke` - Quick smoke tests

### **Running Specific Test Categories**
```bash
# SSL-related tests only
python -m pytest tests/ -m "ssl"

# Security tests only
python -m pytest tests/ -m "security_headers or https_redirection"

# Quick smoke tests
python -m pytest tests/ -m "smoke" -x
```

## 🎨 BDD Feature Examples

### **SSL Configuration Feature**
```gherkin
Feature: SSL Configuration for BeatMap Backend
  As a BeatMap system administrator
  I want to configure SSL/HTTPS settings properly
  So that the application can run securely in different environments

  Scenario: SSL Settings Initialization in Development Environment
    Given the environment is set to "development"
    And SSL is disabled for development
    When the SSL settings are initialized
    Then the SSL should be disabled
    And HTTPS redirection should be disabled
    And HSTS should be disabled
```

### **Security Middleware Feature**
```gherkin
Feature: Security Middleware for HTTPS Support
  As a BeatMap system administrator
  I want security middleware to handle HTTPS redirection and security headers
  So that the application maintains proper security standards

  Scenario: HTTPS Redirection in Production
    Given the environment is "production"
    And HTTPS enforcement is enabled
    When a client makes an HTTP request to "/api/concerts"
    Then the response should redirect to HTTPS
    And the response status should be 307
```

## 🧪 TDD Methodology

### **Red-Green-Refactor Cycle**

1. **🔴 RED**: Write failing tests first
```python
def test_ssl_settings_defaults(self):
    """Test: SSL settings should have secure defaults."""
    # RED: Test that would fail without proper defaults
    settings = SSLSettings()
    assert not settings.ssl_enabled  # This will fail initially
```

2. **🟢 GREEN**: Write minimal code to pass
```python
class SSLSettings(BaseSettings):
    ssl_enabled: bool = Field(default=False)  # Make test pass
```

3. **♻️ REFACTOR**: Improve code while keeping tests passing
```python
class SSLSettings(BaseSettings):
    ssl_enabled: bool = Field(
        default=False,
        description="Enable SSL/TLS encryption"
    )

    @field_validator("ssl_enabled")
    @classmethod
    def validate_ssl_enabled(cls, v):
        # Add validation logic
        return v
```

## 📊 Coverage Reports

Coverage reports are generated in multiple formats:

- **Terminal**: Real-time coverage during test execution
- **HTML**: Detailed coverage report in `htmlcov/index.html`
- **XML**: Machine-readable coverage in `coverage.xml`

### **Coverage Requirements**
- **Minimum Coverage**: 80%
- **Test Coverage**: All SSL/HTTPS functionality
- **Exclusions**: Test files, migrations, virtual environments

## 🐳 Docker Test Containers

Multiple Docker container targets for different test scenarios:

- `test`: Base test container with all dependencies
- `bdd-test`: BDD-specific test runner
- `tdd-test`: TDD-specific test runner
- `integration-test`: Integration test runner
- `coverage-test`: Coverage report generator
- `parallel-test`: Parallel test execution

## 🎯 Test Environment Configuration

### **Environment Variables**
```bash
# Test Environment (Default)
ENVIRONMENT=test
SSL_ENABLED=false
FORCE_HTTPS=false
HSTS_ENABLED=false
CSP_ENABLED=true

# Development Environment
ENVIRONMENT=development
SSL_ENABLED=false
CORS_ORIGINS=https://localhost:3000,http://localhost:3000

# Production Environment
ENVIRONMENT=production
SSL_ENABLED=true
FORCE_HTTPS=true
HSTS_ENABLED=true
HSTS_PRELOAD=true
```

## ✅ Test Validation

### **What We Test**
- ✅ SSL settings initialization and validation
- ✅ Environment-specific configurations
- ✅ Security header generation (HSTS, CSP)
- ✅ HTTPS redirection middleware
- ✅ CORS configuration by environment
- ✅ Rate limiting and request logging
- ✅ Error handling and edge cases
- ✅ Boolean environment variable parsing
- ✅ Certificate path validation

### **TDD vs BDD Coverage**
- **TDD**: Unit-level functionality, edge cases, error conditions
- **BDD**: Business scenarios, user workflows, integration behavior
- **Integration**: Component interaction, FastAPI application testing

## 🔧 Development Workflow

### **Adding New SSL Features**
1. **Write BDD scenario** in `features/` directory
2. **Implement step definitions** in `step_definitions/`
3. **Write failing TDD tests** in `test_ssl_tdd.py`
4. **Implement production code** in `app/core/`
5. **Run tests until green**
6. **Refactor and improve**

### **Test-First Development**
```bash
# 1. Write tests first
./scripts/run_ssl_tests.sh tdd  # Should fail

# 2. Implement feature
# Edit app/core/ssl_settings.py or app/core/middleware.py

# 3. Run tests again
./scripts/run_ssl_tests.sh tdd  # Should pass

# 4. Run full suite
./scripts/run_ssl_tests.sh all
```

---

*This comprehensive TDD/BDD testing framework ensures the reliability and security of BeatMap's SSL/HTTPS Backend Support implementation.*