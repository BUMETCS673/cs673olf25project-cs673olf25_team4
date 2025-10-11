"""Main entry point for JamBase concert data provider.

Encapsulates routes inside JambaseService for consistency with other providers.

This file was generated with the help of AI. 70% of the code was written by AI,
while the remaining 30% was added/modified by humans.
"""

from datetime import datetime
import os
from typing import List, Dict, Any, Optional

import httpx
import uvicorn
from fastapi import FastAPI, HTTPException, Query, APIRouter
from pydantic import BaseModel

import logging

from interfaces.concert_provider_interface import ConcertProviderInterface

logging.basicConfig(
    level=logging.INFO,  # or DEBUG if you want more detail
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

logger = logging.getLogger(__name__)


# ---------- Models ----------
class ConcertResponse(BaseModel):
    """Response model for concert search results."""

    source: str
    parameters: List[Optional[str]]
    results: List[Dict[str, Any]]


class PriceRange(BaseModel):
    """Price range information for an event."""

    currency: Optional[str] = None
    min: Optional[float] = None
    max: Optional[float] = None


class Venue(BaseModel):
    """Venue information for an event."""

    id: Optional[str] = None
    name: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None


class EventItem(BaseModel):
    """Individual event information."""

    id: str
    name: Optional[str] = None
    url: Optional[str] = None
    startDateTime: Optional[str] = None
    segment: Optional[str] = None
    genre: Optional[str] = None
    venue: Optional[Venue] = None
    priceRanges: Optional[List[PriceRange]] = None


class EventSearchResponse(BaseModel):
    """Paginated event search results."""

    totalElements: int
    page: int
    size: int
    data: List[EventItem]
    next: Optional[str] = None


# ---------- Helpers ----------
async def get_events(city_str, start_date, end_date, keyword=None):
    """Queries the JamBase /events endpoint."""
    jambase_city_id = await get_city_id(city_str)
    logger.info("jambase_city_id: %s", jambase_city_id)

    url = "https://www.jambase.com/jb-api/v1/events"
    query_string = {
        "apikey": get_api_key(),
        "eventDateFrom": start_date,
        "eventDateTo": end_date,
        "geoCityId": jambase_city_id,
        "keyword": keyword,
        "@type": "concert",
    }
    logger.info("JamBase query params: %s", query_string)

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.get(url, params=query_string)
        return response.json()


async def get_city_id(city_str):
    """Lookup JamBase city id from /geographies/cities."""
    if city_str is None:
        return None

    url = "https://www.jambase.com/jb-api/v1/geographies/cities"
    query_string = {"apikey": get_api_key(), "geoCityName": city_str}

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.get(url, params=query_string)
        return response.json().get("cities")[0].get("identifier")


def get_api_key():
    """Return JamBase API key from env, or raise if not set."""
    api_key = os.getenv("JAMBASE_API_KEY")
    if not api_key:
        raise RuntimeError(
            "JAMBASE_API_KEY environment variable is not set."
            " Please configure your JamBase API key."
        )
    return api_key


def jambase_parse_performers(performer_list):
    """Extract headliner + lineup from performer list."""
    artist = ""
    lineup = []
    for performer in performer_list:
        if performer.get("x-isHeadliner"):
            artist = performer.get("name")
        lineup.append(performer.get("name"))
    return [artist, lineup]


def process_date(value: str) -> str:
    """
    Convert a ddMMyyyy string (e.g. 01012026) into yyyy-MM-dd.
    Enforces dates can't be in past.
    """
    try:
        dt = datetime.strptime(value, "%d%m%Y")
        if dt < datetime.now():
            dt = datetime.now()
        return dt.strftime("%Y-%m-%d")
    except ValueError:
        raise HTTPException(400, f"Invalid date format: {value}, expected ddMMyyyy")


# ---------- Service ----------
class JambaseService(ConcertProviderInterface):
    """JamBase concert data provider service."""

    def __init__(self):
        """Initialize JamBase service with API routes."""
        self.router = APIRouter()

        self.router.add_api_route("/", self.root, methods=["GET"], tags=["meta"])
        self.router.add_api_route(
            "/search",
            self.search,
            methods=["GET"],
            response_model=EventSearchResponse,
            tags=["events"],
        )

    def get_source_name(self) -> str:
        return "jambase"

    async def root(self):
        """Health check endpoint."""
        return {"status": "ok", "message": "Jambase service is running."}

    async def search(
        self,
        city: Optional[str] = Query(None, description="City to search concerts for"),
        start_date: Optional[str] = Query(
            None, description="Search start date (ddMMyyyy)"
        ),
        end_date: Optional[str] = Query(None, description="Search end date (ddMMyyyy)"),
        keyword: Optional[str] = Query(None, description="Search keyword"),
        page: int = 0,
        size: int = 50,
    ):

        params = {
            "keyword": None if keyword == "unknown" else keyword,
            "city": None if city == "unknown" else city,
            "startDateTime": (
                None
                if (start_date == "unknown" or start_date is None)
                else process_date(start_date)
            ),
            "endDateTime": (
                None
                if (end_date == "unknown" or end_date is None)
                else process_date(end_date)
            ),
            "page": page,
            "size": size,
        }

        logger.info("***********Raw search params: %s", params)

        """Query JamBase and return results in shared EventSearchResponse format."""
        try:
            raw = await get_events(
                params["city"],
                params["startDateTime"],
                params["endDateTime"],
                params["keyword"],
            )
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"JamBase upstream error: {e}")

        events = raw.get("events", []) if isinstance(raw, dict) else []
        items: List[EventItem] = []

        for ev in events:
            try:
                loc = ev.get("location") or ev.get("venue") or {}
                addr = loc.get("address", {}) if isinstance(loc, dict) else {}

                venue = Venue(
                    id=str(loc.get("identifier") or loc.get("id")) if loc else None,
                    name=loc.get("name"),
                    city=addr.get("addressLocality") or loc.get("city"),
                    country=(
                        addr.get("addressCountry", {}).get("name")
                        if isinstance(addr.get("addressCountry"), dict)
                        else addr.get("addressCountry")
                    )
                    or loc.get("country"),
                )

                start_dt = (
                    ev.get("startDate")
                    or ev.get("startDateTime")
                    or ev.get("datetime")
                    or ev.get("datePublished")
                )
                if isinstance(start_dt, datetime):
                    start_dt = start_dt.isoformat()

                segment = ev.get("segment") or ev.get("eventType") or ev.get("@type")

                genres = []
                for p in ev.get("performer", []) or []:
                    g = p.get("genre")
                    if isinstance(g, list):
                        for gg in g:
                            if gg and gg not in genres:
                                genres.append(gg)
                    elif g and g not in genres:
                        genres.append(g)
                genre_val = ", ".join(genres) if genres else None

                prices = [
                    PriceRange(
                        currency=p.get("currency"), min=p.get("min"), max=p.get("max")
                    )
                    for p in (ev.get("priceRanges") or [])
                ] or None

                item = EventItem(
                    id=str(
                        ev.get("id") or ev.get("event_id") or ev.get("identifier") or ""
                    ),
                    name=ev.get("name") or ev.get("title"),
                    url=ev.get("url"),
                    startDateTime=start_dt,
                    segment=segment,
                    genre=genre_val,
                    venue=venue,
                    priceRanges=prices,
                )
                items.append(item)
            except Exception:
                logger.info(f"Failed to parse event: {ev}")
                continue

        total = len(items)
        start = page * size
        paged = items[start : start + size]

        return EventSearchResponse(
            totalElements=total,
            page=page,
            size=len(paged),
            data=paged,
            next=None,
        )


def create_app() -> FastAPI:
    """Factory to build the FastAPI app with JambaseService routes."""
    app = FastAPI(title="JamBase Provider", version="1.0.0")
    jambase_service = JambaseService()
    app.include_router(jambase_service.router)
    return app


app = create_app()


def main():
    """Entry point for running the Jambase service directly."""
    # Read host/port from env with safe defaults
    host = os.getenv("JAMBASE_HOST", "127.0.0.1")
    port = int(os.getenv("JAMBASE_PORT", "8002"))

    # Check if binding to all interfaces was explicitly allowed
    allow_all = os.getenv("JAMBASE_ALLOW_BIND_ALL", "false").lower() in (
        "1",
        "true",
        "yes",
    )

    if not allow_all and host in ("0.0.0.0", "::"):  # nosec B104
        logger.warning(
            "Binding to '%s' (all interfaces) is disabled by default. "
            "Override by setting JAMBASE_ALLOW_BIND_ALL=true. "
            "Falling back to localhost (127.0.0.1).",
            host,
        )
        host = "127.0.0.1"

    # SSL/HTTPS Configuration
    ssl_enabled = os.getenv("JAMBASE_SSL_ENABLED", "false").lower() in (
        "1",
        "true",
        "yes",
    )
    ssl_config = {}

    if ssl_enabled:
        ssl_certfile = os.getenv("JAMBASE_SSL_CERT_PATH")
        ssl_keyfile = os.getenv("JAMBASE_SSL_KEY_PATH")

        if ssl_certfile and ssl_keyfile:
            if os.path.exists(ssl_certfile) and os.path.exists(ssl_keyfile):
                ssl_config = {
                    "ssl_certfile": ssl_certfile,
                    "ssl_keyfile": ssl_keyfile,
                }
                logger.info("HTTPS enabled for Jambase service")
            else:
                logger.warning(
                    "SSL certificates not found. Running without HTTPS. "
                    "Expected cert: %s, key: %s",
                    ssl_certfile,
                    ssl_keyfile,
                )
        else:
            logger.warning("SSL enabled but certificate paths not configured")

    uvicorn.run(
        "jambase_service:create_app",
        host=host,
        port=port,
        reload=True,
        factory=True,
        **ssl_config,
    )


if __name__ == "__main__":
    main()
