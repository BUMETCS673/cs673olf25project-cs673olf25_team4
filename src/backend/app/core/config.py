"""
Configuration management for BeatMap Backend

Loads environment variables and provides configuration classes.
"""

import os
import logging
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables from .env files
load_dotenv()

# Try to load SSL-specific configuration
ssl_env_file = Path(".env.ssl")
if ssl_env_file.exists():
    load_dotenv(ssl_env_file)

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)

logger = logging.getLogger(__name__)

# Environment detection
ENVIRONMENT = os.getenv("ENVIRONMENT", "development").lower()

# Basic application settings
APP_NAME = "BeatMap Backend"
APP_VERSION = "1.0.0"
DEBUG = ENVIRONMENT == "development"

# Host and port configuration
HOST = os.getenv("BEATMAP_HOST", "127.0.0.1")
PORT = int(os.getenv("BEATMAP_PORT", "8000"))

# SSL configuration
SSL_ENABLED = os.getenv("SSL_ENABLED", "false").lower() == "true"
SSL_PORT = int(os.getenv("SSL_PORT", "8443"))

logger.info(f"Configuration loaded for environment: {ENVIRONMENT}")
logger.info(f"SSL enabled: {SSL_ENABLED}")
