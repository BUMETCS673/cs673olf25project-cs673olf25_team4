"""SSL/TLS Configuration Settings for BeatMap Backend.

Provides comprehensive SSL configuration including:
- Certificate and key path management
- Security headers configuration
- HTTPS enforcement settings
- Environment-aware SSL configuration
"""

from pathlib import Path
from typing import Optional, Dict, Any, List, Union
from pydantic import Field, field_validator, ConfigDict
from pydantic_settings import BaseSettings
import logging

logger = logging.getLogger(__name__)


class SSLSettings(BaseSettings):
    """SSL/TLS configuration settings for the BeatMap backend."""

    model_config = ConfigDict(
        env_file=".env", env_file_encoding="utf-8", case_sensitive=False, extra="ignore"
    )

    # Environment
    environment: str = Field(default="development")

    # SSL Certificate Configuration
    ssl_enabled: bool = Field(default=False)
    ssl_cert_path: Optional[str] = Field(default=None)
    ssl_key_path: Optional[str] = Field(default=None)
    ssl_port: int = Field(default=8443)

    # HTTPS Enforcement
    force_https: bool = Field(default=False)
    https_port: int = Field(default=443)

    # Security Headers Configuration
    hsts_enabled: bool = Field(default=True)
    hsts_max_age: int = Field(default=31536000)  # 1 year
    hsts_include_subdomains: bool = Field(default=True)
    hsts_preload: bool = Field(default=False)

    # Content Security Policy
    csp_enabled: bool = Field(default=True)
    csp_default_src: List[str] = Field(default=["'self'"])
    csp_script_src: List[str] = Field(default=["'self'", "'unsafe-inline'"])
    csp_style_src: List[str] = Field(default=["'self'", "'unsafe-inline'"])
    csp_connect_src: List[str] = Field(default=["'self'"])
    csp_report_uri: Optional[str] = Field(default=None)

    # Security Headers
    x_frame_options: str = Field(default="DENY")
    x_content_type_options: bool = Field(default=True)
    x_xss_protection: str = Field(default="1; mode=block")
    referrer_policy: str = Field(default="strict-origin-when-cross-origin")
    permissions_policy_enabled: bool = Field(default=True)

    # CORS Configuration
    cors_origins: Union[str, List[str]] = Field(default=["http://localhost:3000"])
    cors_credentials: bool = Field(default=True)
    cors_methods: Union[str, List[str]] = Field(
        default=["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    )
    cors_headers: Union[str, List[str]] = Field(default=["*"])

    # Server Configuration
    server_name: str = Field(default="BeatMap")

    @field_validator("ssl_cert_path", "ssl_key_path")
    @classmethod
    def validate_ssl_paths(cls, v: Optional[str]) -> Optional[str]:
        """Validate SSL certificate and key paths exist if SSL is enabled."""
        if v and not Path(v).exists():
            logger.warning(f"SSL file path does not exist: {v}")
        return v

    @field_validator("cors_origins", "cors_methods", "cors_headers", mode="before")
    @classmethod
    def parse_cors_lists(cls, v):
        """Parse CORS configuration from string or list."""
        if isinstance(v, str):
            return [item.strip() for item in v.split(",") if item.strip()]
        if isinstance(v, list):
            return v
        return [str(v)]

    @field_validator(
        "csp_default_src",
        "csp_script_src",
        "csp_style_src",
        "csp_connect_src",
        mode="before",
    )
    @classmethod
    def parse_csp_directives(cls, v):
        """Parse CSP directives from string or list."""
        if isinstance(v, str):
            return [
                directive.strip() for directive in v.split(",") if directive.strip()
            ]
        if isinstance(v, list):
            return v
        return [str(v)]

    def get_ssl_context_kwargs(self) -> Optional[Dict[str, Any]]:
        """Get SSL context configuration for uvicorn."""
        if not self.ssl_enabled or not self.ssl_cert_path or not self.ssl_key_path:
            return None

        cert_path = Path(self.ssl_cert_path)
        key_path = Path(self.ssl_key_path)

        if not cert_path.exists() or not key_path.exists():
            logger.warning("SSL certificate or key file not found")
            return None

        return {
            "ssl_certfile": str(cert_path),
            "ssl_keyfile": str(key_path),
        }

    def get_hsts_header(self) -> str:
        """Generate HSTS header value."""
        header_parts = [f"max-age={self.hsts_max_age}"]

        if self.hsts_include_subdomains:
            header_parts.append("includeSubDomains")

        if self.hsts_preload:
            header_parts.append("preload")

        return "; ".join(header_parts)

    def get_csp_header(self) -> str:
        """Generate Content Security Policy header value."""
        if not self.csp_enabled:
            return ""

        directives = []

        if self.csp_default_src:
            directives.append(f"default-src {' '.join(self.csp_default_src)}")

        if self.csp_script_src:
            directives.append(f"script-src {' '.join(self.csp_script_src)}")

        if self.csp_style_src:
            directives.append(f"style-src {' '.join(self.csp_style_src)}")

        if self.csp_connect_src:
            directives.append(f"connect-src {' '.join(self.csp_connect_src)}")

        if self.csp_report_uri:
            directives.append(f"report-uri {self.csp_report_uri}")

        return "; ".join(directives)

    def get_permissions_policy_header(self) -> str:
        """Generate Permissions Policy header value."""
        if not self.permissions_policy_enabled:
            return ""

        # Basic permissions policy for security
        policies = [
            "geolocation=()",
            "microphone=()",
            "camera=()",
            "payment=()",
            "usb=()",
            "magnetometer=()",
            "gyroscope=()",
            "accelerometer=()",
        ]

        return ", ".join(policies)

    def get_environment_cors_origins(self) -> List[str]:
        """Get CORS origins filtered by environment."""
        if self.environment == "production":
            # Production should only allow HTTPS origins
            return [
                origin for origin in self.cors_origins if origin.startswith("https://")
            ]
        elif self.environment == "staging":
            # Staging allows both HTTP and HTTPS but filters localhost
            return [
                origin
                for origin in self.cors_origins
                if not (
                    origin.startswith("http://localhost")
                    or origin.startswith("http://127.0.0.1")
                )
            ]
        else:
            # Development allows all configured origins
            return self.cors_origins

    def is_development(self) -> bool:
        """Check if running in development environment."""
        return self.environment.lower() in ["development", "dev", "local"]

    def is_production(self) -> bool:
        """Check if running in production environment."""
        return self.environment.lower() in ["production", "prod"]

    def should_enforce_https(self) -> bool:
        """Determine if HTTPS should be enforced based on environment."""
        return self.ssl_enabled and self.force_https and not self.is_development()

    def log_configuration(self) -> None:
        """Log the current SSL configuration for debugging."""
        logger.info("SSL Configuration Summary:")
        logger.info(f"  Environment: {self.environment}")
        logger.info(f"  SSL Enabled: {self.ssl_enabled}")
        logger.info(f"  Force HTTPS: {self.force_https}")
        logger.info(f"  HSTS Enabled: {self.hsts_enabled}")
        logger.info(f"  CSP Enabled: {self.csp_enabled}")
        logger.info(f"  CORS Origins: {len(self.cors_origins)} configured")

        if self.ssl_enabled:
            logger.info(f"  SSL Certificate: {self.ssl_cert_path}")
            logger.info(f"  SSL Key: {self.ssl_key_path}")
            logger.info(f"  SSL Port: {self.ssl_port}")

        if self.is_development():
            logger.debug("Running in development mode - SSL enforcement relaxed")
        elif self.is_production():
            logger.info("Running in production mode - Full SSL enforcement")


# Global SSL settings instance
_ssl_settings: Optional[SSLSettings] = None


def get_ssl_settings() -> SSLSettings:
    """Get or create the global SSL settings instance."""
    global _ssl_settings
    if _ssl_settings is None:
        _ssl_settings = SSLSettings()
    return _ssl_settings


def reload_ssl_settings() -> SSLSettings:
    """Reload SSL settings from environment."""
    global _ssl_settings
    _ssl_settings = SSLSettings()
    return _ssl_settings
