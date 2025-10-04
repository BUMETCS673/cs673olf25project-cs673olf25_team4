"""
Security Middleware for BeatMap Backend.

Provides comprehensive middleware including:
- HTTPS redirection
- Security headers
- Request logging
- Basic rate limiting
"""

import logging
import time
from typing import Callable
from fastapi import Request, Response, HTTPException
from fastapi.responses import RedirectResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

from .ssl_settings import SSLSettings

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# HTTPS Redirect Middleware
# ---------------------------------------------------------------------------

class HTTPSRedirectMiddleware(BaseHTTPMiddleware):
    """Middleware to redirect HTTP requests to HTTPS."""

    def __init__(self, app: ASGIApp, ssl_settings: SSLSettings):
        super().__init__(app)
        self.ssl_settings = ssl_settings

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Redirect HTTP to HTTPS if force_https is enabled."""
        if not self.ssl_settings.ssl_enabled or not self.ssl_settings.force_https:
            return await call_next(request)

        if request.url.path in ["/health", "/metrics", "/favicon.ico"]:
            return await call_next(request)

        is_https = (
            request.url.scheme == "https"
            or request.headers.get("x-forwarded-proto") == "https"
            or request.headers.get("x-forwarded-ssl") == "on"
        )

        if not is_https:
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


# ---------------------------------------------------------------------------
# Security Headers Middleware
# ---------------------------------------------------------------------------

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Middleware to add standard security headers to responses."""

    def __init__(self, app: ASGIApp, ssl_settings: SSLSettings):
        super().__init__(app)
        self.ssl_settings = ssl_settings

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Add security headers to response."""
        response = await call_next(request)

        # --- HTTPS Strict Transport Security ---
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

        # --- Content Security Policy (CSP) ---
        # Relaxed CSP for FastAPI docs & OpenAPI JSON
        if any(path in str(request.url) for path in ["/docs", "/openapi.json"]):
            response.headers["Content-Security-Policy"] = (
                "default-src 'self'; "
                "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
                "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
                "img-src 'self' data: https://fastapi.tiangolo.com; "
                "font-src 'self' data:;"
            )
        else:
            csp_header = self.ssl_settings.get_csp_header()
            if csp_header:
                response.headers["Content-Security-Policy"] = csp_header

        # --- Other standard security headers ---
        if self.ssl_settings.x_frame_options:
            response.headers["X-Frame-Options"] = self.ssl_settings.x_frame_options

        if self.ssl_settings.x_content_type_options:
            response.headers["X-Content-Type-Options"] = "nosniff"

        if self.ssl_settings.x_xss_protection:
            response.headers["X-XSS-Protection"] = self.ssl_settings.x_xss_protection

        if self.ssl_settings.referrer_policy:
            response.headers["Referrer-Policy"] = self.ssl_settings.referrer_policy

        permissions_policy = self.ssl_settings.get_permissions_policy_header()
        if permissions_policy:
            response.headers["Permissions-Policy"] = permissions_policy

        # --- Cross-origin protection headers ---
        response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
        response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
        response.headers["Cross-Origin-Resource-Policy"] = "same-site"

        # --- Misc security & privacy headers ---
        response.headers["X-Permitted-Cross-Domain-Policies"] = "none"
        response.headers["X-DNS-Prefetch-Control"] = "off"

        # --- Mask server header ---
        if "Server" in response.headers:
            del response.headers["Server"]
        response.headers["Server"] = "BeatMap"

        return response


# ---------------------------------------------------------------------------
# Request Logging Middleware
# ---------------------------------------------------------------------------

class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware to log requests for security monitoring."""

    def __init__(self, app: ASGIApp, ssl_settings: SSLSettings):
        super().__init__(app)
        self.ssl_settings = ssl_settings

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        client_ip = self.get_client_ip(request)
        user_agent = request.headers.get("user-agent", "Unknown")
        is_https = (
            request.url.scheme == "https"
            or request.headers.get("x-forwarded-proto") == "https"
            or request.headers.get("x-forwarded-ssl") == "on"
        )

        logger.info(
            f"Request: {request.method} {request.url.path} "
            f"from {client_ip} via {'HTTPS' if is_https else 'HTTP'} "
            f"User-Agent: {user_agent[:100]}"
        )

        try:
            response = await call_next(request)
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
        """Extract client IP address from headers."""
        for header in [
            "x-forwarded-for",
            "x-real-ip",
            "x-client-ip",
            "cf-connecting-ip",
        ]:
            value = request.headers.get(header)
            if value:
                return value.split(",")[0].strip()

        if hasattr(request, "client") and request.client:
            return request.client.host

        return "unknown"


# ---------------------------------------------------------------------------
# Basic Rate Limiting Middleware
# ---------------------------------------------------------------------------

class RateLimitingMiddleware(BaseHTTPMiddleware):
    """Simple in-memory rate limiting middleware."""

    def __init__(
        self,
        app: ASGIApp,
        ssl_settings: SSLSettings,
        requests_per_minute: int = 100,
    ):
        super().__init__(app)
        self.ssl_settings = ssl_settings
        self.requests_per_minute = requests_per_minute
        self.request_counts = {}
        self.last_cleanup = 0

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        if request.url.path in ["/health", "/metrics"]:
            return await call_next(request)

        client_ip = self.get_client_ip(request)
        current_time = int(time.time())

        # Clean old entries
        if current_time - self.last_cleanup > 60:
            self.cleanup_old_entries(current_time)
            self.last_cleanup = current_time

        minute_window = current_time // 60
        key = f"{client_ip}:{minute_window}"

        if key in self.request_counts:
            if self.request_counts[key] >= self.requests_per_minute:
                logger.warning(f"Rate limit exceeded for {client_ip}")
                raise HTTPException(
                    status_code=429,
                    detail="Too many requests. Please try again later.",
                )
            self.request_counts[key] += 1
        else:
            self.request_counts[key] = 1

        return await call_next(request)

    def get_client_ip(self, request: Request) -> str:
        """Extract client IP from headers or fallback to socket."""
        for header in ["x-forwarded-for", "x-real-ip", "x-client-ip"]:
            value = request.headers.get(header)
            if value:
                return value.split(",")[0].strip()

        if hasattr(request, "client") and request.client:
            return request.client.host

        return "unknown"

    def cleanup_old_entries(self, current_time: int):
        """Purge old rate-limit entries."""
        current_minute = current_time // 60
        old_keys = [
            k for k in self.request_counts.keys()
            if int(k.split(":")[1]) < current_minute - 1
        ]
        for k in old_keys:
            del self.request_counts[k]
