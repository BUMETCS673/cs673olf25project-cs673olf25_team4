"""
Simple BDD Step Definitions for SSL Configuration
Minimal implementation for pytest-bdd.
"""

import pytest
import os
from unittest.mock import patch
from pytest_bdd import scenarios, given, when, then

from ...app.core.ssl_settings import SSLSettings


# Load scenarios from the simple feature file
scenarios('../features/ssl_simple.feature')


# Test context fixture
@pytest.fixture
def ssl_context():
    """Simple context for SSL tests."""
    return {}


# ==================== GIVEN Steps ====================

@given('SSL settings are initialized')
def ssl_settings_initialized(ssl_context):
    """Given SSL settings are initialized."""
    ssl_context['initialized'] = True


@given('the environment is set to production')
def environment_production(ssl_context):
    """Given the environment is set to production."""
    ssl_context['env'] = {
        'ENVIRONMENT': 'production',
        'SSL_ENABLED': 'true',
        'FORCE_HTTPS': 'true'
    }


# ==================== WHEN Steps ====================

@when('no SSL configuration is provided')
def no_ssl_configuration(ssl_context):
    """When no SSL configuration is provided."""
    with patch.dict(os.environ, {}, clear=True):
        ssl_context['settings'] = SSLSettings()


@when('SSL is enabled')
def ssl_enabled(ssl_context):
    """When SSL is enabled."""
    env = ssl_context.get('env', {})
    with patch.dict(os.environ, env):
        ssl_context['settings'] = SSLSettings()


# ==================== THEN Steps ====================

@then('SSL should be disabled')
def ssl_should_be_disabled(ssl_context):
    """Then SSL should be disabled."""
    assert not ssl_context['settings'].ssl_enabled


@then('the environment should be development')
def environment_should_be_development(ssl_context):
    """Then the environment should be development."""
    assert ssl_context['settings'].environment == 'development'


@then('SSL should be enabled')
def ssl_should_be_enabled(ssl_context):
    """Then SSL should be enabled."""
    assert ssl_context['settings'].ssl_enabled


@then('HTTPS should be enforced')
def https_should_be_enforced(ssl_context):
    """Then HTTPS should be enforced."""
    assert ssl_context['settings'].force_https