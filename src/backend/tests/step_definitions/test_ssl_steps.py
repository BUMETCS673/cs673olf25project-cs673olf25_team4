"""
BDD Step Definitions for SSL Configuration Tests
Using pytest-bdd to implement Given/When/Then steps for SSL feature scenarios.
"""

import pytest
import os
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from pytest_bdd import scenarios, given, when, then, parsers

from app.main import create_app
from app.core.ssl_settings import SSLSettings


# Load all scenarios from feature files
scenarios('../features/ssl_configuration.feature')


# Shared Test Context
@pytest.fixture
def ssl_context():
    """Shared context for SSL test scenarios."""
    return {
        'environment': None,
        'ssl_settings': None,
        'headers': {},
        'test_env': {},
        'warnings': []
    }


# ==================== GIVEN Steps ====================

@given('the BeatMap backend application is initializing')
def backend_initializing(ssl_context):
    """Given the BeatMap backend application is initializing."""
    ssl_context['initializing'] = True


@given('SSL configuration is being loaded')
def ssl_configuration_loading(ssl_context):
    """Given SSL configuration is being loaded."""
    ssl_context['config_loading'] = True


@given(parsers.parse('the environment is set to "{environment}"'))
def environment_is_set(ssl_context, environment):
    """Given the environment is set to a specific value."""
    ssl_context['environment'] = environment
    ssl_context['test_env']['ENVIRONMENT'] = environment


@given('SSL is disabled for development')
def ssl_disabled_for_dev(ssl_context):
    """Given SSL is disabled for development."""
    ssl_context['test_env'].update({
        'SSL_ENABLED': 'false',
        'FORCE_HTTPS': 'false',
        'HSTS_ENABLED': 'false'
    })


@given('SSL is enabled for production')
def ssl_enabled_for_prod(ssl_context):
    """Given SSL is enabled for production."""
    ssl_context['test_env'].update({
        'SSL_ENABLED': 'true',
        'FORCE_HTTPS': 'true',
        'HSTS_ENABLED': 'true',
        'HSTS_PRELOAD': 'true'
    })


@given('SSL settings are configured for production')
def ssl_settings_configured_production(ssl_context):
    """Given SSL settings are configured for production."""
    ssl_context['test_env'].update({
        'ENVIRONMENT': 'production',
        'SSL_ENABLED': 'true',
        'HSTS_ENABLED': 'true',
        'HSTS_MAX_AGE': '31536000',
        'HSTS_INCLUDE_SUBDOMAINS': 'true',
        'HSTS_PRELOAD': 'true'
    })


@given('SSL settings are configured')
def ssl_settings_configured(ssl_context):
    """Given SSL settings are configured."""
    ssl_context['test_env'].update({
        'SSL_ENABLED': 'true',
        'CSP_ENABLED': 'true'
    })


@given(parsers.parse('HSTS is enabled with max age {max_age:d} seconds'))
def hsts_enabled_with_max_age(ssl_context, max_age):
    """Given HSTS is enabled with specific max age."""
    ssl_context['test_env'].update({
        'HSTS_ENABLED': 'true',
        'HSTS_MAX_AGE': str(max_age)
    })


@given('HSTS includes subdomains and preload')
def hsts_includes_subdomains_preload(ssl_context):
    """Given HSTS includes subdomains and preload."""
    ssl_context['test_env'].update({
        'HSTS_INCLUDE_SUBDOMAINS': 'true',
        'HSTS_PRELOAD': 'true'
    })


@given('CSP is enabled')
def csp_enabled(ssl_context):
    """Given CSP is enabled."""
    ssl_context['test_env']['CSP_ENABLED'] = 'true'


@given('SSL is enabled')
def ssl_enabled(ssl_context):
    """Given SSL is enabled."""
    ssl_context['test_env']['SSL_ENABLED'] = 'true'


@given('environment variables are set')
def environment_variables_set(ssl_context):
    """Given environment variables are set."""
    ssl_context['test_env'].update({
        'SSL_ENABLED': 'true',
        'FORCE_HTTPS': 'false',
        'HSTS_ENABLED': '1',
        'CSP_ENABLED': '0'
    })


# ==================== WHEN Steps ====================

@when('the SSL settings are initialized')
def ssl_settings_initialized(ssl_context):
    """When the SSL settings are initialized."""
    with patch.dict(os.environ, ssl_context['test_env']):
        ssl_context['ssl_settings'] = SSLSettings()


@when('the HSTS header is generated')
def hsts_header_generated(ssl_context):
    """When the HSTS header is generated."""
    with patch.dict(os.environ, ssl_context['test_env']):
        settings = SSLSettings()
        ssl_context['hsts_header'] = settings.get_hsts_header()


@when('the CSP header is generated')
def csp_header_generated(ssl_context):
    """When the CSP header is generated."""
    with patch.dict(os.environ, ssl_context['test_env']):
        settings = SSLSettings()
        ssl_context['csp_header'] = settings.get_csp_header()


@when('an invalid certificate path is provided')
def invalid_cert_path_provided(ssl_context):
    """When an invalid certificate path is provided."""
    ssl_context['test_env'].update({
        'SSL_CERT_PATH': '/nonexistent/cert.pem',
        'SSL_KEY_PATH': '/nonexistent/key.pem'
    })

    # Capture warnings
    with patch.dict(os.environ, ssl_context['test_env']):
        with patch('app.core.ssl_settings.logger') as mock_logger:
            ssl_context['ssl_settings'] = SSLSettings()
            ssl_context['mock_logger'] = mock_logger


@when('boolean SSL settings are parsed from strings')
def boolean_settings_parsed(ssl_context):
    """When boolean SSL settings are parsed from strings."""
    test_cases = [
        {'SSL_ENABLED': 'true', 'expected': True},
        {'SSL_ENABLED': 'false', 'expected': False},
        {'SSL_ENABLED': '1', 'expected': True},
        {'SSL_ENABLED': '0', 'expected': False}
    ]

    ssl_context['parsed_results'] = []
    for case in test_cases:
        env = ssl_context['test_env'].copy()
        env.update(case)
        with patch.dict(os.environ, env):
            settings = SSLSettings()
            ssl_context['parsed_results'].append({
                'input': case['SSL_ENABLED'],
                'expected': case['expected'],
                'actual': settings.ssl_enabled
            })


# ==================== THEN Steps ====================

@then('the SSL should be disabled')
def ssl_should_be_disabled(ssl_context):
    """Then the SSL should be disabled."""
    assert not ssl_context['ssl_settings'].ssl_enabled


@then('the SSL should be enabled')
def ssl_should_be_enabled(ssl_context):
    """Then the SSL should be enabled."""
    assert ssl_context['ssl_settings'].ssl_enabled


@then('HTTPS redirection should be disabled')
def https_redirection_disabled(ssl_context):
    """Then HTTPS redirection should be disabled."""
    assert not ssl_context['ssl_settings'].force_https


@then('HTTPS redirection should be enabled')
def https_redirection_enabled(ssl_context):
    """Then HTTPS redirection should be enabled."""
    assert ssl_context['ssl_settings'].force_https


@then('HSTS should be disabled')
def hsts_should_be_disabled(ssl_context):
    """Then HSTS should be disabled."""
    assert not ssl_context['ssl_settings'].hsts_enabled


@then('HSTS should be enabled with preload')
def hsts_enabled_with_preload(ssl_context):
    """Then HSTS should be enabled with preload."""
    settings = ssl_context['ssl_settings']
    assert settings.hsts_enabled
    assert settings.hsts_preload


@then('the CORS origins should include localhost')
def cors_origins_include_localhost(ssl_context):
    """Then the CORS origins should include localhost."""
    origins = ssl_context['ssl_settings'].get_cors_origins()
    localhost_origins = [
        origin for origin in origins
        if 'localhost' in origin
    ]
    assert len(localhost_origins) > 0


@then('the CORS origins should only include secure origins')
def cors_origins_secure_only(ssl_context):
    """Then the CORS origins should only include secure origins."""
    origins = ssl_context['ssl_settings'].get_cors_origins()
    for origin in origins:
        assert origin.startswith('https://') or origin.startswith('wss://')


@then(parsers.parse('the header should contain "{content}"'))
def header_should_contain(ssl_context, content):
    """Then the header should contain specific content."""
    if 'hsts_header' in ssl_context:
        assert content in ssl_context['hsts_header']
    elif 'csp_header' in ssl_context:
        assert content in ssl_context['csp_header']


@then('a warning should be logged')
def warning_should_be_logged(ssl_context):
    """Then a warning should be logged."""
    mock_logger = ssl_context['mock_logger']
    mock_logger.warning.assert_called()


@then('the SSL settings should still be valid')
def ssl_settings_still_valid(ssl_context):
    """Then the SSL settings should still be valid."""
    settings = ssl_context['ssl_settings']
    assert settings is not None
    assert hasattr(settings, 'ssl_enabled')


@then(parsers.parse('"{input_val}" should be parsed as boolean {expected}'))
def string_parsed_as_boolean(ssl_context, input_val, expected):
    """Then string values should be parsed as expected boolean values."""
    expected_bool = expected == 'True'

    matching_result = None
    for result in ssl_context['parsed_results']:
        if result['input'] == input_val:
            matching_result = result
            break

    assert matching_result is not None, f"No result found for input '{input_val}'"
    assert matching_result['actual'] == expected_bool, \
        f"Expected {input_val} -> {expected_bool}, got {matching_result['actual']}"


# ==================== Test Configuration ====================

@pytest.fixture(autouse=True)
def setup_test_environment(ssl_context):
    """Set up clean test environment for each scenario."""
    # Default test environment
    ssl_context['test_env'] = {
        'ENVIRONMENT': 'test',
        'SSL_ENABLED': 'false',
        'FORCE_HTTPS': 'false',
        'HSTS_ENABLED': 'false',
        'CSP_ENABLED': 'true',
        'CORS_ORIGINS': 'https://localhost:3000,http://localhost:3000'
    }

    yield ssl_context

    # Cleanup after each test
    ssl_context.clear()