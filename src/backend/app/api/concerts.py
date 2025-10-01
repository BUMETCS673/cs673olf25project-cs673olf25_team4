import os
from typing import Optional

import httpx
from fastapi import APIRouter, Query, HTTPException
from itertools import cycle
import logging

logger = logging.getLogger(__name__)

logging.basicConfig(
    level=logging.INFO,  # or DEBUG if you want more detail
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)


class ConcertsService:
    def __init__(self):
        self.router = APIRouter(tags=["concerts"])

        # Register routes
        self.router.add_api_route("/", self.root, methods=["GET"], tags=["meta"])
        self.router.add_api_route(
            "/search", self.search, methods=["GET"], tags=["concerts"]
        )

        # Provider URLs from env (support both old and new variable names)
        self.providers = {
            "jambase": os.getenv(
                "JAMBASE_API_URL",
                os.getenv("JAMBASE_PROVIDER_URL", "http://jambase_provider:8002"),
            ),
            "ticketmaster": os.getenv(
                "TICKETMASTER_API_URL",
                os.getenv("TM_PROVIDER_URL", "http://ticketmaster_provider:8001"),
            ),
        }

        self._provider_cycle = cycle(self.providers.keys())

        # Determine if we should verify SSL certificates
        # In development with self-signed certs, we disable verification
        environment = os.getenv("ENVIRONMENT", "development").lower()
        self.verify_ssl = environment in ["production", "prod", "staging"]

        if not self.verify_ssl:
            logger.warning("SSL verification disabled for development environment")

    async def root(self):
        return {
            "status": "ok",
            "message": "Backend is running. Main entry point for beatmap.",
        }

    async def search(
        self,
        city: str = Query(None, description="City to search concerts in."),
        start_date: str = Query(None, description="Start date YYYY-MM-DD"),
        end_date: str = Query(None, description="End date YYYY-MM-DD"),
        provider: str = Query(
            None, description="Provider to search (jambase, ticketmaster)"
        ),
        keyword: Optional[str] = None,
    ):
        params = {
            "city": city,
            "start_date": start_date,
            "end_date": end_date,
            "keyword": keyword,
        }
        logger.info(f"Search request params: {params}")

        if provider is None:
            provider = self.get_provider()
        else:
            provider = provider.lower()

        if provider not in self.providers:
            raise HTTPException(status_code=400, detail=f"Unknown provider: {provider}")

        logger.info(f"Using provider: {provider}")
        try:
            clean = {k: v for k, v in params.items() if v is not None}
            # Create HTTP client with appropriate SSL verification
            async with httpx.AsyncClient(
                timeout=20.0, verify=self.verify_ssl
            ) as client:
                response = await client.get(
                    f"{self.providers[provider]}/search", params=clean
                )
                response.raise_for_status()
                return response.json()
        except httpx.HTTPStatusError as e:
            logger.error(
                f"HTTP error from provider {provider}: "
                f"{e.response.status_code} - {e.response.text}"
            )
            raise HTTPException(
                status_code=502,
                detail=f"Provider {provider} returned error: {e.response.status_code}",
            )
        except httpx.RequestError as e:
            logger.error(f"Request error to provider {provider}: {str(e)}")
            raise HTTPException(
                status_code=502,
                detail=f"Error connecting to provider {provider}: {str(e)}",
            )
        except Exception as e:
            logger.error(
                f"Unexpected error fetching from provider {provider}: {str(e)}"
            )
            raise HTTPException(
                status_code=502, detail=f"Error fetching concert data: {e}"
            )

    def get_provider(self, requested=None):
        if requested:
            return requested
        return next(self._provider_cycle)
