"""
ticketmaster_service.py

Acts as the main entry point for Ticketmaster provider.
Encapsulates routes inside TicketmasterService for consistency
with other providers (e.g., JamBase).
"""

from datetime import datetime
import os
from typing import List, Optional

import httpx
import uvicorn
from fastapi import FastAPI, HTTPException, APIRouter
from pydantic import BaseModel
from dotenv import load_dotenv
from zoneinfo import ZoneInfo
import logging

logging.basicConfig(
    level=logging.INFO,  # or DEBUG if you want more detail
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

logger = logging.getLogger(__name__)


# Load .env file from the project root directory
load_dotenv(
    dotenv_path=os.path.join(
        os.path.dirname(__file__),
        "..",
        "..",
        ".env",
    )
)

TM_BASE = os.getenv(
    "TM_BASE_URL",
    "https://app.ticketmaster.com/discovery/v2",
)
TM_KEY = os.getenv("TM_API_KEY")


# ---------- Models ----------
class PriceRange(BaseModel):
    currency: Optional[str] = None
    min: Optional[float] = None
    max: Optional[float] = None


class Venue(BaseModel):
    id: Optional[str] = None
    name: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None


class EventItem(BaseModel):
    id: str
    name: Optional[str] = None
    url: Optional[str] = None
    startDateTime: Optional[str] = None
    segment: Optional[str] = None
    genre: Optional[str] = None
    venue: Optional[Venue] = None
    priceRanges: Optional[List[PriceRange]] = None


class EventSearchResponse(BaseModel):
    totalElements: int
    page: int
    size: int
    data: List[EventItem]
    next: Optional[str] = None


# ---------- Helpers ----------
async def _tm_get(path: str, params: dict) -> dict:
    if not TM_KEY:
        raise HTTPException(500, "TM_API_KEY not configured")

    clean = {k: v for k, v in params.items() if v is not None}
    clean["apikey"] = TM_KEY

    timeout = httpx.Timeout(10.0, read=20.0)
    logger.info("Ticketmaster GET %s with params: %s", path, clean)
    async with httpx.AsyncClient(timeout=timeout) as c:
        r = await c.get(f"{TM_BASE}{path}", params=clean)

    if r.status_code == 401:
        raise HTTPException(401, "Unauthorized to Ticketmaster")
    if r.status_code == 404:
        raise HTTPException(404, "Not found")
    if r.status_code == 429:
        raise HTTPException(429, "Rate limited by Ticketmaster")
    if r.status_code >= 500:
        raise HTTPException(502, "Ticketmaster upstream error")
    return r.json()


def _parse_event(e: dict) -> EventItem:
    start = (e.get("dates") or {}).get("start", {}).get("dateTime")
    cls = (e.get("classifications") or [{}])[0]
    seg = (cls.get("segment") or {}).get("name")
    gen = (cls.get("genre") or {}).get("name")

    v0 = (e.get("_embedded", {}).get("venues") or [{}])[0]
    venue = Venue(
        id=v0.get("id"),
        name=v0.get("name"),
        city=(v0.get("city") or {}).get("name"),
        country=(v0.get("country") or {}).get("countryCode"),
    )

    prices = [
        PriceRange(
            currency=p.get("currency"),
            min=p.get("min"),
            max=p.get("max"),
        )
        for p in (e.get("priceRanges") or [])
    ] or None

    return EventItem(
        id=e["id"],
        name=e.get("name"),
        url=e.get("url"),
        startDateTime=start,
        segment=seg,
        genre=gen,
        venue=venue,
        priceRanges=prices,
    )


# ---------- Ticketmaster Service ----------
class TicketmasterService:
    def __init__(self):
        self.router = APIRouter()

        self.router.add_api_route("/", self.root, methods=["GET"], tags=["meta"])
        self.router.add_api_route(
            "/search",
            self.search_events,
            methods=["GET"],
            response_model=EventSearchResponse,
            tags=["events"],
        )
        self.router.add_api_route(
            "/events/{event_id}",
            self.get_event,
            methods=["GET"],
            response_model=EventItem,
            tags=["events"],
        )

    async def root(self):
        return {
            "status": "ok",
            "message": "Ticketmaster service is running.",
        }

    async def search_events(
        self,
        keyword: Optional[str] = None,
        city: Optional[str] = None,
        country_code: Optional[str] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        page: int = 0,
        size: int = 20,
        sort: Optional[str] = None,
    ):
        params = {
            "keyword": None if keyword == "unknown" else keyword,
            "city": None if city == "unknown" else city,
            "countryCode": country_code,
            "startDateTime": None if start_date == "unknown" else start_date,
            "endDateTime": None if end_date == "unknown" else end_date,
            "page": page,
            "size": size,
            "sort": sort,
            "classificationName": "Music",
        }

        logger.info("Raw search params: %s", params)

        if params.get("startDateTime") is not None:
            try:
                dt = datetime.fromisoformat(params["startDateTime"])
            except ValueError:
                try:
                    dt = datetime.strptime(params["startDateTime"], "%Y-%m-%d")
                except ValueError:
                    try:
                        dt = datetime.strptime(
                            params["startDateTime"], "%Y-%m-%dT%H:%M"
                        )
                    except ValueError:
                        try:
                            dt = datetime.strptime(params["startDateTime"], "%d%m%Y")
                        except ValueError:
                            raise HTTPException(400, "Invalid startDateTime format")

            params["startDateTime"] = dt.replace(
                tzinfo=ZoneInfo("America/New_York")
            ).isoformat()

        if params.get("endDateTime") is not None:
            try:
                dt = datetime.fromisoformat(params["endDateTime"])
            except ValueError:
                try:
                    dt = datetime.strptime(params["endDateTime"], "%Y-%m-%d")
                except ValueError:
                    try:
                        dt = datetime.strptime(params["endDateTime"], "%Y-%m-%dT%H:%M")
                    except ValueError:
                        try:
                            dt = datetime.strptime(params["endDateTime"], "%d%m%Y")
                        except ValueError:
                            raise HTTPException(400, "Invalid endDateTime format")

            params["endDateTime"] = dt.replace(
                tzinfo=ZoneInfo("America/New_York")
            ).isoformat()

        clean_params = {k: v for k, v in params.items() if v is not None}

        logger.info("Ticketmaster search with params: %s", clean_params)

        all_items = []
        total_elements = 0
        page_info = {}
        next_link = None

        # Handle multiple comma-separated keywords
        keywords = (
            [
                kw.strip()
                for kw in clean_params.get("keyword", "").split(",")
                if kw.strip()
            ]
            if "keyword" in clean_params
            else [None]
        )

        for kw in keywords:
            # Create a copy of params with this keyword
            query_params = dict(clean_params)
            if kw:
                query_params["keyword"] = kw

            raw = await _tm_get("/events.json", query_params)
            page_info = raw.get(
                "page", {}
            )  # overwritten, but fine if you just need last call
            events = raw.get("_embedded", {}).get("events") or []

            all_items.extend(_parse_event(e) for e in events)
            total_elements += page_info.get("totalElements", 0)

            # Keep next link if exists (from last keyword call)
            next_link = (raw.get("_links", {}) or {}).get("next", {}).get("href")

        return EventSearchResponse(
            totalElements=total_elements,
            page=page_info.get("number", page),
            size=page_info.get("size", size),
            data=all_items,
            next=next_link,
        )

    async def get_event(self, event_id: str):
        raw = await _tm_get(f"/events/{event_id}.json", {})
        return _parse_event(raw)


def create_app() -> FastAPI:
    """Factory to build the FastAPI app with TicketmasterService routes."""
    app = FastAPI(title="Ticketmaster Provider")
    ticketmaster_service = TicketmasterService()
    app.include_router(ticketmaster_service.router)
    return app


app = create_app()


def main():
    """Entry point for running the Ticketmaster service directly."""
    # Default to loopback to avoid accidental binding to all interfaces.
    host = os.getenv("TM_HOST", "127.0.0.1")
    port = int(os.getenv("TM_PORT", "8001"))

    allow_all = os.getenv("TM_ALLOW_BIND_ALL", "false").lower() in ("1", "true", "yes")

    # Fail safe: don't bind to all interfaces unless explicitly allowed
    if not allow_all and host in ("0.0.0.0", "::"):  # nosec B104
        logger.warning(
            "Binding to '%s' (all interfaces) is disabled by default. "
            "Set TM_ALLOW_BIND_ALL=true to override. "
            "Falling back to localhost (127.0.0.1).",
            host,
        )
        host = "127.0.0.1"

    # SSL/HTTPS Configuration
    ssl_enabled = os.getenv("TM_SSL_ENABLED", "false").lower() in ("1", "true", "yes")
    ssl_config = {}

    if ssl_enabled:
        ssl_certfile = os.getenv("TM_SSL_CERT_PATH")
        ssl_keyfile = os.getenv("TM_SSL_KEY_PATH")

        if ssl_certfile and ssl_keyfile:
            if os.path.exists(ssl_certfile) and os.path.exists(ssl_keyfile):
                ssl_config = {
                    "ssl_certfile": ssl_certfile,
                    "ssl_keyfile": ssl_keyfile,
                }
                logger.info("HTTPS enabled for Ticketmaster service")
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
        "ticketmaster_service:create_app",
        host=host,
        port=port,
        reload=True,
        factory=True,
        **ssl_config,
    )


if __name__ == "__main__":
    main()
