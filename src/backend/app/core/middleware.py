"""
Security Middleware for BeatMap Backend

Provides comprehensive security middleware including:
- HTTPS redirection middleware
- Security headers middleware
- Request logging and monitoring
"""

import logging
from typing import Callable
from fastapi import Request, Response, HTTPException
from fastapi.responses import RedirectResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

from .ssl_settings import SSLSettings

logger = logging.getLogger(__name__)


class HTTPSRedirectMiddleware(BaseHTTPMiddleware):
    """Middleware to redirect HTTP requests to HTTPS."""

    def __init__(self, app: ASGIApp, ssl_settings: SSLSettings):
        super().__init__(app)
        self.ssl_settings = ssl_settings

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Redirect HTTP to HTTPS if force_https is enabled."""
        # Skip redirection if SSL is not enabled or force_https is disabled
        if not self.ssl_settings.ssl_enabled or not self.ssl_settings.force_https:
            return await call_next(request)

        # Skip redirection for health checks and internal requests
        if request.url.path in ["/health", "/metrics", "/favicon.ico"]:
            return await call_next(request)

        # Check if request is already HTTPS
        is_https = (
            request.url.scheme == "https"
            or request.headers.get("x-forwarded-proto") == "https"
            or request.headers.get("x-forwarded-ssl") == "on"
        )

        if not is_https:
            # Construct HTTPS URL
            https_url = request.url.replace(
                scheme="https",
                port=(
                    self.ssl_settings.https_port
                    if self.ssl_settings.https_port != 443
                    else None
                ),
            )
            logger.info(f"Redirecting HTTP to HTTPS: {request.url} -> {https_url}")
            return RedirectResponse(url=str(https_url), status_code=301)

        return await call_next(request)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Middleware to add security headers to all responses."""

    def __init__(self, app: ASGIApp, ssl_settings: SSLSettings):
        super().__init__(app)
        self.ssl_settings = ssl_settings

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Add security headers to response."""
        response = await call_next(request)

        # Add HSTS header for HTTPS requests
        if self.ssl_settings.ssl_enabled and self.ssl_settings.hsts_enabled:
            is_https = (
                request.url.scheme == "https"
                or request.headers.get("x-forwarded-proto") == "https"
                or request.headers.get("x-forwarded-ssl") == "on"
            )

            if is_https:
                hsts_header = self.ssl_settings.get_hsts_header()
                if hsts_header:
                    response.headers["Strict-Transport-Security"] = hsts_header

        # Add Content Security Policy
        csp_header = self.ssl_settings.get_csp_header()
        if csp_header:
            response.headers["Content-Security-Policy"] = csp_header

        # Add X-Frame-Options
        if self.ssl_settings.x_frame_options:
            response.headers["X-Frame-Options"] = self.ssl_settings.x_frame_options

        # Add X-Content-Type-Options
        if self.ssl_settings.x_content_type_options:
            response.headers["X-Content-Type-Options"] = "nosniff"

        # Add X-XSS-Protection
        if self.ssl_settings.x_xss_protection:
            response.headers["X-XSS-Protection"] = self.ssl_settings.x_xss_protection

        # Add Referrer-Policy
        if self.ssl_settings.referrer_policy:
            response.headers["Referrer-Policy"] = self.ssl_settings.referrer_policy

        # Add Permissions Policy
        permissions_policy = self.ssl_settings.get_permissions_policy_header()
        if permissions_policy:
            response.headers["Permissions-Policy"] = permissions_policy

        # Add Cross-Origin Policies for additional security
        response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
        response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
        response.headers["Cross-Origin-Resource-Policy"] = "same-site"

        # Add security-related headers
        response.headers["X-Permitted-Cross-Domain-Policies"] = "none"
        response.headers["X-DNS-Prefetch-Control"] = "off"

        # Remove server identification headers and replace with custom
        if "Server" in response.headers:
            del response.headers["Server"]
        response.headers["Server"] = "BeatMap"

        return response


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware to log requests for security monitoring."""

    def __init__(self, app: ASGIApp, ssl_settings: SSLSettings):
        super().__init__(app)
        self.ssl_settings = ssl_settings

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Log request details for security monitoring."""
        # Log security-relevant request information
        client_ip = self.get_client_ip(request)
        user_agent = request.headers.get("user-agent", "Unknown")
        is_https = (
            request.url.scheme == "https"
            or request.headers.get("x-forwarded-proto") == "https"
            or request.headers.get("x-forwarded-ssl") == "on"
        )

        # Log request start
        logger.info(
            f"Request: {request.method} {request.url.path} "
            f"from {client_ip} via {'HTTPS' if is_https else 'HTTP'} "
            f"User-Agent: {user_agent[:100]}"
        )

        # Process request
        try:
            response = await call_next(request)

            # Log response status
            logger.info(
                f"Response: {response.status_code} for "
                f"{request.method} {request.url.path} to {client_ip}"
            )

            return response

        except Exception as e:
            logger.error(
                f"Request failed: {request.method} {request.url.path} "
                f"from {client_ip} - Error: {str(e)}"
            )
            raise

    def get_client_ip(self, request: Request) -> str:
        """Extract client IP address from request headers."""
        # Check various headers for client IP (in order of preference)
        for header in [
            "x-forwarded-for",
            "x-real-ip",
            "x-client-ip",
            "cf-connecting-ip",  # Cloudflare
        ]:
            value = request.headers.get(header)
            if value:
                # Handle comma-separated IPs (take first one)
                return value.split(",")[0].strip()

        # Fallback to direct connection IP
        if hasattr(request, "client") and request.client:
            return request.client.host

        return "unknown"


class RateLimitingMiddleware(BaseHTTPMiddleware):
    """Basic rate limiting middleware for security."""

    def __init__(
        self, app: ASGIApp, ssl_settings: SSLSettings, requests_per_minute: int = 100
    ):
        super().__init__(app)
        self.ssl_settings = ssl_settings
        self.requests_per_minute = requests_per_minute
        self.request_counts = {}  # In production, use Redis or similar
        self.last_cleanup = 0

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Apply basic rate limiting."""
        # Skip rate limiting for health checks
        if request.url.path in ["/health", "/metrics"]:
            return await call_next(request)

        client_ip = self.get_client_ip(request)
        current_time = int(__import__("time").time())

        # Cleanup old entries every minute
        if current_time - self.last_cleanup > 60:
            self.cleanup_old_entries(current_time)
            self.last_cleanup = current_time

        # Check rate limit
        minute_window = current_time // 60
        key = f"{client_ip}:{minute_window}"

        if key in self.request_counts:
            if self.request_counts[key] >= self.requests_per_minute:
                logger.warning(f"Rate limit exceeded for {client_ip}")
                raise HTTPException(
                    status_code=429, detail="Too many requests. Please try again later."
                )
            self.request_counts[key] += 1
        else:
            self.request_counts[key] = 1

        return await call_next(request)

    def get_client_ip(self, request: Request) -> str:
        """Extract client IP address from request headers."""
        # Check various headers for client IP
        for header in ["x-forwarded-for", "x-real-ip", "x-client-ip"]:
            value = request.headers.get(header)
            if value:
                return value.split(",")[0].strip()

        if hasattr(request, "client") and request.client:
            return request.client.host

        return "unknown"

    def cleanup_old_entries(self, current_time: int):
        """Remove old rate limiting entries."""
        current_minute = current_time // 60
        keys_to_remove = [
            key
            for key in self.request_counts.keys()
            if int(key.split(":")[1]) < current_minute - 1
        ]
        for key in keys_to_remove:
            del self.request_counts[key]
