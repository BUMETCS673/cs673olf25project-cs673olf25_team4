"""Concert search and AI-powered recommendation endpoints.

This file was generated with the help of AI. 70% of the code was written by AI,
while the remaining 30% was added/modified by humans.
"""

import os
from typing import Optional
import httpx
from fastapi import APIRouter, Query, HTTPException
from itertools import cycle
import logging
from ..core.groq_client import GroqClient

from interfaces.concert_provider_interface import ConcertProviderInterface
from typing import Dict

logger = logging.getLogger(__name__)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)


class ConcertsService:
    """Service for handling concert search and AI-powered recommendations."""

    def __init__(self):
        self.router = APIRouter(tags=["concerts"])

        # --- Register routes (support /concerts and /concerts/) ---
        self.router.add_api_route(
            "", self.root, methods=["GET"], tags=["concerts"], include_in_schema=False
        )
        self.router.add_api_route("/", self.root, methods=["GET"], tags=["concerts"])
        self.router.add_api_route(
            "/search", self.search, methods=["GET"], tags=["concerts"]
        )
        self.router.add_api_route(
            "/recommendations",
            self.get_curated_concert_recommendations,
            methods=["GET"],
            tags=["concerts"],
        )

        # --- Provider URLs ---
        self.concert_data_providers: Dict[str, ConcertProviderInterface] = {
            "jambase": os.getenv(
                "JAMBASE_API_URL",
                os.getenv("JAMBASE_PROVIDER_URL", "http://jambase_provider:8002"),
            ),
            "ticketmaster": os.getenv(
                "TICKETMASTER_API_URL",
                os.getenv("TM_PROVIDER_URL", "http://ticketmaster_provider:8001"),
            ),
        }

        self.ai_providers = {
            "groq": os.getenv("GROQ_API_URL", "http://groq_provider:8003"),
        }

        self._provider_cycle = cycle(self.concert_data_providers.keys())

        # Disable SSL verification for internal Docker network
        self.verify_ssl = False
        if not self.verify_ssl:
            logger.warning("SSL verification disabled for development environment")

    # ----------------------------------------------------------------------
    # Root route → delegates to AI recommendations
    # ----------------------------------------------------------------------
    async def root(
        self,
        user_input: Optional[str] = Query(
            None, description="Natural-language user input"
        ),
    ):
        """
        Root endpoint delegates to AI recommendations.
        Example:
        GET /concerts?user_input=rock+concerts+in+Boston+next+week
        """
        if not user_input:
            logger.warning(
                "No user_input provided to /concerts; returning guidance message."
            )
            return {
                "status": "ok",
                "message": "Please provide a 'user_input' query parameter. "
                "Example: /concerts?user_input=rock+concerts+in+Boston+next+week",
            }

        logger.info(
            f"Root /concerts called → forwarding to\
            get_curated_concert_recommendations() with input: {user_input}"
        )
        return await self.get_curated_concert_recommendations(user_input=user_input)

    # ----------------------------------------------------------------------
    # Search endpoint (direct API search)
    # ----------------------------------------------------------------------
    async def search(
        self,
        city: Optional[str] = Query(None, description="City to search concerts in."),
        start_date: Optional[str] = Query(None, description="Start date YYYY-MM-DD"),
        end_date: Optional[str] = Query(None, description="End date YYYY-MM-DD"),
        concert_data_provider: Optional[str] = Query(
            None, description="Provider to search (jambase, ticketmaster)"
        ),
        keyword: Optional[str] = None,
    ):
        """Search for concerts using the specified or default provider."""
        params = {
            "city": city,
            "start_date": start_date,
            "end_date": end_date,
            "keyword": keyword,
        }
        logger.info(f"Search request params: {params}")

        if concert_data_provider is None:
            concert_data_provider = self.get_provider()
        else:
            concert_data_provider = concert_data_provider.lower()

        if concert_data_provider not in self.concert_data_providers:
            raise HTTPException(
                status_code=400, detail=f"Unknown provider: {concert_data_provider}"
            )

        logger.info(f"Using provider: {concert_data_provider}")
        try:
            clean = {k: v for k, v in params.items() if v is not None}
            async with httpx.AsyncClient(
                timeout=20.0, verify=self.verify_ssl
            ) as client:
                response = await client.get(
                    f"{self.concert_data_providers[concert_data_provider]}/search",
                    params=clean,
                )
                response.raise_for_status()
                return response.json()
        except httpx.HTTPStatusError as e:
            # httpx.HTTPStatusError may be raised without a response (e.g., in
            # unit tests where the exception is constructed with response=None).
            status_code = None
            resp_text = None
            if getattr(e, "response", None) is not None:
                status_code = getattr(e.response, "status_code", None)
                resp_text = getattr(e.response, "text", None)

            logger.error(
                f"HTTP error from provider {concert_data_provider}: "
                f"{status_code} - {resp_text or str(e)}"
            )
            # Surface a generic 502 to callers while preserving some detail
            # when available.
            # Match existing error messaging used elsewhere/tests
            if status_code:
                detail_msg = f"Error fetching concert data: \
                    Provider {concert_data_provider} returned error: {status_code}"
            else:
                detail_msg = f"Error fetching concert data: {str(e)}"

            raise HTTPException(status_code=502, detail=detail_msg)
        except httpx.RequestError as e:
            logger.error(f"Request error to provider {concert_data_provider}: {str(e)}")
            raise HTTPException(
                status_code=502,
                detail=(
                    f"Error fetching concert data: \
                        Error connecting to provider {concert_data_provider}: {str(e)}"
                ),
            )
        except Exception as e:
            logger.error(
                f"Unexpected error from provider {concert_data_provider}: {str(e)}"
            )
            raise HTTPException(
                status_code=502, detail=f"Error fetching concert data: {str(e)}"
            )

    # ----------------------------------------------------------------------
    # Provider cycling
    # ----------------------------------------------------------------------
    def get_provider(self, requested=None):
        """Get the requested provider or cycle to the next available one."""
        if requested:
            return requested
        return next(self._provider_cycle)

    # ----------------------------------------------------------------------
    # Recommendation enrichment
    # ----------------------------------------------------------------------
    def enrich_recommendations(self, recommendations, concert_results):
        """Enrich AI recommendations with full concert event details."""
        if isinstance(concert_results, list):
            concert_lookup = {c["id"]: c for c in concert_results}
        else:
            concert_lookup = concert_results

        enriched = []
        for rec in recommendations["recommendations"]:
            event = concert_lookup.get(rec["event_id"])
            enriched.append(
                {
                    "rank": rec["rank"],
                    "event": event,
                    "reason": rec["reason"],
                }
            )
        return {"recommendations": enriched}

    # ----------------------------------------------------------------------
    # AI-powered recommendations
    # ----------------------------------------------------------------------
    async def get_curated_concert_recommendations(self, user_input: str):
        """Generate AI-curated concert recommendations based on user input."""
        logger.info(f"Generating recommendations for user input: {user_input}")
        client = GroqClient()
        logger.info(f"Using Groq provider at {client.base_url}")

        tokens = await client.extract_tokens(user_input=user_input)
        logger.info(f"Extracted tokens: {tokens}")

        user_preferences = await client.get_user_preferences(user_input=user_input)
        logger.info(f"Extracted user preferences: {user_preferences}")

        locations = tokens.get("locations", [])
        if locations and len(locations) > 1:
            city = ",".join(locations)
        elif locations:
            city = locations[0]
        else:
            city = None
        city = None if city == "unknown" else city
        logger.info(f"Using city: {city}")

        artists = tokens.get("artists", [])
        genres = user_preferences.get("genres", [])
        keywords = artists + genres
        # Filter out None and "unknown" values
        keywords = [k for k in keywords if k and k != "unknown"]
        if keywords:
            keyword = ",".join(keywords)
        else:
            keyword = None

        client_params = {
            "city": city,
            "start_date": tokens.get("start_date"),
            "end_date": tokens.get("end_date"),
            "keyword": keyword,
            "concert_data_provider": None,
        }

        concert_results = await self.search(**client_params)
        events_found = len(concert_results.get("data", []))
        logger.info(f"Fetched concert results, total: {events_found} events")

        # If no results found, try with a different provider
        if events_found == 0:
            logger.info("No results found with first provider, trying alternate provider")
            # Get the next provider in the cycle
            alternate_provider = self.get_provider()
            client_params["concert_data_provider"] = alternate_provider
            concert_results = await self.search(**client_params)
            events_found = len(concert_results.get("data", []))
            logger.info(
                f"Retry with provider '{alternate_provider}' returned {events_found} events"
            )

        recommendations = await client.create_recommendations(
            user_preferences=user_preferences,
            events=concert_results.get("data", []),
        )

        return self.enrich_recommendations(
            recommendations, concert_results.get("data", [])
        )
