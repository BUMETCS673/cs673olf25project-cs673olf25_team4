"""Concert search and recommendation API endpoints."""

import os
from typing import Optional

import httpx
from fastapi import APIRouter, Query, HTTPException
from itertools import cycle
import logging
from ..core.groq_client import GroqClient

logger = logging.getLogger(__name__)

logging.basicConfig(
    level=logging.INFO,  # or DEBUG if you want more detail
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)


class ConcertsService:
    """Service for handling concert search and AI-powered recommendations."""

    def __init__(self):
        """Initialize the concerts service with provider configurations."""
        self.router = APIRouter(tags=["concerts"])

        # Register routes
        self.router.add_api_route("/", self.root, methods=["GET"], tags=["meta"])
        self.router.add_api_route(
            "/search", self.search, methods=["GET"], tags=["concerts"]
        )
        self.router.add_api_route(
            "/recommendations",
            self.get_curated_concert_recommendations,
            methods=["GET"],
            tags=["concerts"],
        )

        # Provider URLs from env (support both old and new variable names)
        self.concert_data_providers = {
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

        # Determine if we should verify SSL certificates
        # In development with self-signed certs, we disable verification
        # Left ability in place for future use if when microservices run
        # under different networks/Docker environments
        self.verify_ssl = False

        if not self.verify_ssl:
            logger.warning("SSL verification disabled for development environment")

    async def root(self):
        """Return service health status."""
        return {
            "status": "ok",
            "message": "Backend is running. Main entry point for beatmap.",
        }

    async def search(
        self,
        city: str = Query(None, description="City to search concerts in."),
        start_date: str = Query(None, description="Start date YYYY-MM-DD"),
        end_date: str = Query(None, description="End date YYYY-MM-DD"),
        concert_data_provider: str = Query(
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
            # Create HTTP client with appropriate SSL verification
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
            logger.error(
                f"HTTP error from provider {concert_data_provider}: "
                f"{e.response.status_code} - {e.response.text}"
            )
            detail_msg = (
                f"Provider {concert_data_provider} returned error: "
                f"{e.response.status_code}"
            )
            raise HTTPException(status_code=502, detail=detail_msg)
        except httpx.RequestError as e:
            logger.error(f"Request error to provider {concert_data_provider}: {str(e)}")
            detail_msg = (
                f"Error connecting to provider {concert_data_provider}: {str(e)}"
            )
            raise HTTPException(status_code=502, detail=detail_msg)
        except Exception as e:
            logger.error(
                f"Unexpected error from provider {concert_data_provider}: {str(e)}"
            )
            raise HTTPException(
                status_code=502, detail=f"Error fetching concert data: {e}"
            )

    def get_provider(self, requested=None):
        """Get the requested provider or cycle to the next available one."""
        if requested:
            return requested
        return next(self._provider_cycle)

    def enrich_recommendations(self, recommendations, concert_results):
        """Enrich AI recommendations with full concert event details."""
        # If concert_results is a list of dicts, convert to lookup by id
        if isinstance(concert_results, list):
            concert_lookup = {c["id"]: c for c in concert_results}
        else:
            concert_lookup = concert_results  # assume already a dict

        enriched = []
        for rec in recommendations["recommendations"]:
            event = concert_lookup.get(rec["event_id"])
            enriched.append(
                {
                    "rank": rec["rank"],
                    "event": event,  # replace event_id with actual event object
                    "reason": rec["reason"],
                }
            )
        return {"recommendations": enriched}

    async def get_curated_concert_recommendations(self, user_input: str):
        """Generate AI-curated concert recommendations based on user input."""
        logger.info(f"Generating recommendations for user input: {user_input}")
        client = GroqClient()
        logger.info(f"Using Groq provider at {client.base_url}")

        # get tokens
        tokens = await client.extract_tokens(user_input=user_input)
        logger.info(f"Extracted tokens: {tokens}")

        # get user preferences
        user_preferences = await client.get_user_preferences(user_input=user_input)
        logger.info(f"Extracted user preferences: {user_preferences}")

        locations = tokens.get("locations", [None])
        if locations and len(locations) > 1:
            city = ",".join(locations)
        else:
            city = locations
        city = None if city == "unknown" else city
        logger.info(f"Using city: {city}")

        artists = tokens.get("artists", [None])
        genres = user_preferences.get("genres", [])
        keywords = artists + genres
        if keywords and len(keywords) > 1:
            keywords = ",".join(keywords)
        else:
            keywords = keywords[0]

        client_params = {
            "city": city,
            "start_date": tokens.get("start_date"),
            "end_date": tokens.get("end_date"),
            "keyword": keywords,
            "concert_data_provider": None,
        }
        # get concert data
        concert_results = await self.search(**client_params)
        logger.info(
            f"Fetched concert results, a total of:\
              {len(concert_results.get('data', []))} events"
        )

        # get recommendations
        recommendations = await client.create_recommendations(
            user_preferences=user_preferences,
            events=concert_results.get("data", []),
        )
        return self.enrich_recommendations(
            recommendations, concert_results.get("data", [])
        )
