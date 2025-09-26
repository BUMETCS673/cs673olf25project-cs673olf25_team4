import os
import random
from typing import Optional

import httpx
from fastapi import APIRouter, Query, HTTPException
from itertools import cycle


class ConcertsService:
    def __init__(self):
        self.router = APIRouter(tags=["concerts"])

        # Register routes
        self.router.add_api_route("/", self.root, methods=["GET"], tags=["meta"])
        self.router.add_api_route(
            "/search", self.search, methods=["GET"], tags=["concerts"]
        )

        # Provider URLs from env
        self.providers = {
            "jambase": os.getenv(
                "JAMBASE_PROVIDER_URL", "http://jambase_provider:8000"
            ),
            "ticketmaster": os.getenv(
                "TM_PROVIDER_URL", "http://ticketmaster_provider:8000"
            ),
        }

        self._provider_cycle = cycle(self.providers.keys())

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
        print(f"Search request params: {params}")

        if provider is None:
            provider = self.get_provider()
        else:
            provider = provider.lower()

        if provider not in self.providers:
            raise HTTPException(status_code=400, detail=f"Unknown provider: {provider}")

        try:
            clean = {k: v for k, v in params.items() if v is not None}
            async with httpx.AsyncClient(timeout=20.0) as client:
                response = await client.get(
                    f"{self.providers[provider]}/search", params=clean
                )
                response.raise_for_status()
                return response.json()
        except Exception as e:
            raise HTTPException(
                status_code=502, detail=f"Error fetching concert data: {e}"
            )
        
    def get_provider(self, requested=None):
        if requested:
            return requested
        return next(self._provider_cycle)