"""
config.py

Centralized configuration for provider service URLs.
Loads from environment variables with sensible defaults for Docker Compose.
"""

import os

JAMBASE_URL = os.getenv(
    "JAMBASE_API_URL", "http://jambase_provider:8002/jambase/search"
)

TICKETMASTER_URL = os.getenv(
    "TICKETMASTER_API_URL", "http://ticketmaster_provider:8001/search"
)

# Add more providers here as needed
PROVIDERS = {
    "jambase": JAMBASE_URL,
    "ticketmaster": TICKETMASTER_URL,
}
