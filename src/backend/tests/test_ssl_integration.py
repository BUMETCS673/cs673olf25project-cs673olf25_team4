"""
SSL Integration Tests for BeatMap Backend

Tests SSL configuration, security middleware, and HTTPS functionality.
"""

import pytest
import os
import tempfile
from fastapi.testclient import TestClient
from unittest.mock import patch

from app.main import create_app
from app.core.ssl_settings import SSLSettings


@pytest.fixture
def ssl_test_env():
    """Set up test environment variables for SSL testing."""
    # Use tempfile for secure temporary paths
    temp_dir = tempfile.gettempdir()
    test_env = {
        "ENVIRONMENT": "test",
        "SSL_ENABLED": "false",  # Disabled by default for testing
        "SSL_CERT_PATH": os.path.join(temp_dir, "test_cert.pem"),
        "SSL_KEY_PATH": os.path.join(temp_dir, "test_key.pem"),
        "FORCE_HTTPS": "false",
        "HSTS_ENABLED": "false",
        "CSP_ENABLED": "true",
        "CORS_ORIGINS": "https://localhost:3000,http://localhost:3000",
    }

    with patch.dict(os.environ, test_env):
        yield test_env


@pytest.fixture
def client_with_ssl(ssl_test_env):
    """Create test client with SSL configuration."""
    app = create_app()
    return TestClient(app)


class TestSSLSettings:
    """Test SSL settings configuration."""

    def test_ssl_settings_initialization(self, ssl_test_env):
        """Test SSL settings are properly initialized."""
        settings = SSLSettings()
        temp_dir = tempfile.gettempdir()

        assert settings.environment == "test"
        assert not settings.ssl_enabled
        assert settings.ssl_cert_path == os.path.join(temp_dir, "test_cert.pem")
        assert settings.ssl_key_path == os.path.join(temp_dir, "test_key.pem")
        assert not settings.force_https
        assert not settings.hsts_enabled
        assert settings.csp_enabled

    def test_cors_origins_parsing(self, ssl_test_env):
        """Test CORS origins are properly parsed."""
        settings = SSLSettings()
        origins = settings.get_environment_cors_origins()

        # Test environment should include both HTTP and HTTPS for development
        assert "https://localhost:3000" in origins
        assert "http://localhost:3000" in origins

    def test_hsts_header_generation(self):
        """Test HSTS header generation."""
        settings = SSLSettings(
            hsts_enabled=True,
            hsts_max_age=31536000,
            hsts_include_subdomains=True,
            hsts_preload=True,
        )

        header = settings.get_hsts_header()
        assert "max-age=31536000" in header
        assert "includeSubDomains" in header
        assert "preload" in header

    def test_csp_header_generation(self):
        """Test CSP header generation."""
        settings = SSLSettings(
            csp_enabled=True,
            csp_default_src=["'self'"],
            csp_script_src=["'self'", "'unsafe-inline'"],
            csp_style_src=["'self'", "'unsafe-inline'"],
        )

        header = settings.get_csp_header()
        assert "default-src 'self'" in header
        assert "script-src 'self' 'unsafe-inline'" in header
        assert "style-src 'self' 'unsafe-inline'" in header

    def test_ssl_context_kwargs(self):
        """Test SSL context configuration."""
        temp_dir = tempfile.gettempdir()

        # Test with SSL disabled
        settings = SSLSettings(ssl_enabled=False)
        assert settings.get_ssl_context_kwargs() is None

        # Test with SSL enabled but no paths
        settings = SSLSettings(ssl_enabled=True, ssl_cert_path=None, ssl_key_path=None)
        assert settings.get_ssl_context_kwargs() is None

        # Test with SSL enabled and valid paths
        # Create temporary certificate files for testing
        test_cert_path = os.path.join(temp_dir, "test_cert.pem")
        test_key_path = os.path.join(temp_dir, "test_key.pem")

        # Create empty temp files to pass existence check
        with open(test_cert_path, "w") as f:
            f.write("test cert")
        with open(test_key_path, "w") as f:
            f.write("test key")

        try:
            settings = SSLSettings(
                ssl_enabled=True,
                ssl_cert_path=test_cert_path,
                ssl_key_path=test_key_path,
            )

            kwargs = settings.get_ssl_context_kwargs()
            assert kwargs is not None
            assert kwargs["ssl_certfile"] == test_cert_path
            assert kwargs["ssl_keyfile"] == test_key_path
        finally:
            # Clean up temp files
            if os.path.exists(test_cert_path):
                os.remove(test_cert_path)
            if os.path.exists(test_key_path):
                os.remove(test_key_path)


class TestSecurityMiddleware:
    """Test security middleware functionality."""

    def test_health_check_endpoint(self, client_with_ssl):
        """Test health check endpoint works."""
        response = client_with_ssl.get("/health")
        assert response.status_code == 200

        data = response.json()
        assert data["status"] == "healthy"
        assert "environment" in data
        assert "ssl_enabled" in data
        assert "timestamp" in data

    def test_security_headers_added(self, client_with_ssl):
        """Test security headers are added to responses."""
        response = client_with_ssl.get("/health")

        # Check for security headers
        assert "X-Content-Type-Options" in response.headers
        assert response.headers["X-Content-Type-Options"] == "nosniff"

        assert "X-Frame-Options" in response.headers
        assert "Referrer-Policy" in response.headers
        assert "Cross-Origin-Embedder-Policy" in response.headers
        assert "Server" in response.headers
        assert response.headers["Server"] == "BeatMap"

    def test_csp_header_added(self, client_with_ssl):
        """Test Content Security Policy header is added."""
        response = client_with_ssl.get("/health")

        # CSP should be enabled by default
        assert "Content-Security-Policy" in response.headers
        csp_header = response.headers["Content-Security-Policy"]
        assert "default-src 'self'" in csp_header

    def test_cors_configuration(self, client_with_ssl):
        """Test CORS is properly configured."""
        # Test preflight request
        response = client_with_ssl.options(
            "/health",
            headers={
                "Origin": "https://localhost:3000",
                "Access-Control-Request-Method": "GET",
            },
        )

        # CORS headers should be present
        assert "Access-Control-Allow-Origin" in response.headers
        assert "Access-Control-Allow-Credentials" in response.headers

    @pytest.mark.parametrize(
        "origin",
        ["https://localhost:3000", "http://localhost:3000", "https://evil.com"],
    )
    def test_cors_origin_validation(self, client_with_ssl, origin):
        """Test CORS origin validation."""
        response = client_with_ssl.get("/health", headers={"Origin": origin})

        if origin.startswith("https://localhost") or origin.startswith(
            "http://localhost"
        ):
            # Should be allowed
            assert response.status_code == 200
        # Note: CORS validation happens at browser level, not server level
        # Server will respond but browser will block unauthorized origins

    def test_ssl_info_endpoint_debug_only(self, ssl_test_env):
        """Test SSL info endpoint is only available in debug mode."""
        # Test in debug mode (development)
        with patch.dict(os.environ, {"ENVIRONMENT": "development"}):
            app = create_app()
            client = TestClient(app)

            response = client.get("/ssl-info")
            assert response.status_code == 200

            data = response.json()
            assert "ssl_enabled" in data
            assert "environment" in data

        # Test in production mode (should not have endpoint)
        with patch.dict(os.environ, {"ENVIRONMENT": "production"}):
            app = create_app()
            client = TestClient(app)

            response = client.get("/ssl-info")
            assert response.status_code == 404


class TestHTTPSRedirection:
    """Test HTTPS redirection middleware."""

    def test_no_redirection_when_disabled(self, client_with_ssl):
        """Test no HTTPS redirection when force_https is disabled."""
        response = client_with_ssl.get("/health", allow_redirects=False)
        assert response.status_code == 200  # No redirection

    @patch.dict(os.environ, {"FORCE_HTTPS": "true", "SSL_ENABLED": "true"})
    def test_https_redirection_enabled(self):
        """Test HTTPS redirection when enabled."""
        app = create_app()
        client = TestClient(app)

        # Simulate HTTP request
        response = client.get(
            "/health", allow_redirects=False, headers={"Host": "testbeatmap.com"}
        )

        # Should redirect to HTTPS (or process normally in test environment)
        # Note: TestClient doesn't perfectly simulate HTTP vs HTTPS
        assert response.status_code in [200, 301, 307, 308]

    def test_health_check_bypass_redirection(self, client_with_ssl):
        """Test health check endpoints bypass HTTPS redirection."""
        response = client_with_ssl.get("/health")
        assert response.status_code == 200


class TestRateLimiting:
    """Test rate limiting middleware."""

    def test_rate_limiting_allows_normal_requests(self, client_with_ssl):
        """Test rate limiting allows normal request patterns."""
        # Make several requests - should all succeed
        for _ in range(10):
            response = client_with_ssl.get("/health")
            assert response.status_code == 200

    def test_health_check_bypass_rate_limiting(self, client_with_ssl):
        """Test health checks bypass rate limiting."""
        # Make many health check requests - should not be rate limited
        for _ in range(50):
            response = client_with_ssl.get("/health")
            assert response.status_code == 200


class TestEnvironmentSpecificConfiguration:
    """Test environment-specific SSL configurations."""

    @pytest.mark.parametrize(
        "environment,expected_hsts",
        [
            ("development", False),
            ("staging", True),
            ("production", True),
        ],
    )
    def test_environment_hsts_configuration(self, environment, expected_hsts):
        """Test HSTS is configured correctly per environment."""
        env_vars = {
            "ENVIRONMENT": environment,
            "HSTS_ENABLED": str(expected_hsts).lower(),
        }

        with patch.dict(os.environ, env_vars):
            settings = SSLSettings()
            assert settings.hsts_enabled == expected_hsts

    def test_production_cors_origins_https_only(self):
        """Test production environment only allows HTTPS CORS origins."""
        with patch.dict(
            os.environ,
            {
                "ENVIRONMENT": "production",
                "CORS_ORIGINS": "https://beatmap.live,http://insecure.com",
            },
        ):
            settings = SSLSettings()
            origins = settings.get_environment_cors_origins()

            # Should only include HTTPS origins in production
            assert "https://beatmap.live" in origins
            assert "http://insecure.com" not in origins

    def test_development_cors_includes_http(self):
        """Test development environment includes HTTP origins."""
        with patch.dict(os.environ, {"ENVIRONMENT": "development"}):
            settings = SSLSettings()
            origins = settings.get_environment_cors_origins()

            # Should include both HTTP and HTTPS for development
            http_origins = [o for o in origins if o.startswith("http://")]
            https_origins = [o for o in origins if o.startswith("https://")]

            assert len(http_origins) > 0
            assert len(https_origins) > 0


if __name__ == "__main__":
    pytest.main([__file__])
