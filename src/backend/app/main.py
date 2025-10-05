"""Entry point for BeatMap backend with comprehensive HTTPS support.

Includes SSL configuration, security middleware, and enhanced CORS.
"""

import uvicorn
import os
import logging
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.concerts import ConcertsService
from app.core.ssl_settings import get_ssl_settings
from app.core.middleware import (
    HTTPSRedirectMiddleware,
    SecurityHeadersMiddleware,
    RequestLoggingMiddleware,
    RateLimitingMiddleware,
)
from app.core.config import APP_NAME, APP_VERSION, DEBUG, ENVIRONMENT

logger = logging.getLogger(__name__)


def create_app() -> FastAPI:
    """Create FastAPI application with SSL and security configuration."""
    # Load SSL settings
    ssl_settings = get_ssl_settings()
    ssl_settings.log_configuration()

    # Create FastAPI app
    app = FastAPI(
        title=APP_NAME,
        version=APP_VERSION,
        debug=DEBUG,
        docs_url="/docs",
        redoc_url="/redoc",
    )

    # Add security middleware (order matters!)
    # 1. Rate limiting (first to block excessive requests)
    app.add_middleware(RateLimitingMiddleware, ssl_settings=ssl_settings)

    # 2. Request logging (for security monitoring)
    app.add_middleware(RequestLoggingMiddleware, ssl_settings=ssl_settings)

    # 3. HTTPS redirection (before other processing)
    app.add_middleware(HTTPSRedirectMiddleware, ssl_settings=ssl_settings)

    # 4. Security headers (after HTTPS redirect)
    app.add_middleware(SecurityHeadersMiddleware, ssl_settings=ssl_settings)

    # 5. CORS middleware (environment-aware origins)
    cors_origins = ssl_settings.get_environment_cors_origins()
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_credentials=ssl_settings.cors_credentials,
        allow_methods=ssl_settings.cors_methods,
        allow_headers=ssl_settings.cors_headers,
        expose_headers=["X-Request-ID"],  # Allow frontend to see custom headers
    )

    # Health check endpoint
    @app.get("/health")
    async def health_check(request: Request):
        """Health check endpoint for load balancers and monitoring."""
        return JSONResponse(
            {
                "status": "healthy",
                "environment": ENVIRONMENT,
                "version": APP_VERSION,
                "ssl_enabled": ssl_settings.ssl_enabled,
                "timestamp": __import__("datetime").datetime.utcnow().isoformat(),
            }
        )

    # SSL configuration info endpoint (development only)
    if DEBUG:

        @app.get("/ssl-info")
        async def ssl_info():
            """SSL configuration information (development only)."""
            return JSONResponse(
                {
                    "ssl_enabled": ssl_settings.ssl_enabled,
                    "ssl_port": ssl_settings.ssl_port,
                    "force_https": ssl_settings.force_https,
                    "hsts_enabled": ssl_settings.hsts_enabled,
                    "environment": ssl_settings.environment,
                    "cors_origins": cors_origins,
                }
            )

    # Register ConcertsService
    concerts_service = ConcertsService()
    app.include_router(concerts_service.router)

    logger.info(f"FastAPI application created for environment: {ENVIRONMENT}")
    logger.info(f"CORS origins: {cors_origins}")

    return app


# Expose app instance for uvicorn CLI
app = create_app()


def main():
    """Run the backend with uvicorn directly, including SSL support."""
    # Load SSL settings
    ssl_settings = get_ssl_settings()

    # Basic server configuration
    host = os.getenv("BEATMAP_HOST", "127.0.0.1")
    port = int(os.getenv("BEATMAP_PORT", "8000"))

    # SSL configuration
    ssl_config = {}
    if ssl_settings.ssl_enabled:
        ssl_context_kwargs = ssl_settings.get_ssl_context_kwargs()
        if ssl_context_kwargs:
            ssl_config.update(ssl_context_kwargs)
            port = ssl_settings.ssl_port
            logger.info(f"SSL enabled - server will run on port {port}")
        else:
            logger.warning("SSL enabled but no valid SSL context configuration found")

    # Uvicorn configuration
    uvicorn_config = {
        "app": "app.main:create_app",
        "host": host,
        "port": port,
        "reload": DEBUG,
        "factory": True,
        "log_level": "info" if not DEBUG else "debug",
        "access_log": True,
    }

    # Add SSL configuration if available
    if ssl_config:
        uvicorn_config.update(ssl_config)

    logger.info("Starting BeatMap backend server:")
    logger.info(f"  Host: {host}")
    logger.info(f"  Port: {port}")
    logger.info(f"  Environment: {ENVIRONMENT}")
    logger.info(f"  SSL Enabled: {ssl_settings.ssl_enabled}")
    logger.info(f"  Debug Mode: {DEBUG}")

    try:
        uvicorn.run(**uvicorn_config)
    except Exception as e:
        logger.error(f"Failed to start server: {e}")
        if ssl_settings.ssl_enabled:
            logger.error(
                "If SSL is enabled, ensure certificate files exist and are readable"
            )
        raise


if __name__ == "__main__":
    main()
