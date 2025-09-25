"""
main.py

Acts as the main entry point for JamBase provider.
Encapsulates routes inside JambaseService for consistency
with other providers (e.g., Ticketmaster).
"""

from datetime import datetime
import os
from typing import List, Dict, Any, Optional

import httpx
import uvicorn
from fastapi import FastAPI, HTTPException, Query, APIRouter
from pydantic import BaseModel


# ---------- Models ----------
class ConcertResponse(BaseModel):
    source: str
    parameters: List[Optional[str]]
    results: List[Dict[str, Any]]


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
async def get_events(city_str, start_date, end_date, keyword=None):
    """Queries the JamBase /events endpoint."""
    jambase_city_id = await get_city_id(city_str)
    print("jambase_city_id:", jambase_city_id)

    url = "https://www.jambase.com/jb-api/v1/events"
    query_string = {
        "apikey": get_api_key(),
        "eventDateFrom": start_date,
        "eventDateTo": end_date,
        "geoCityId": jambase_city_id,
        "keyword": keyword,
        "@type": "concert",
    }
    print(query_string)

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
    """Return JamBase API key from env, or dummy fallback."""
    return os.getenv("JAMBASE_API_KEY", "dummy-test-key")


def jambase_parse_performers(performer_list):
    """Extract headliner + lineup from performer list."""
    artist = ""
    lineup = []
    for performer in performer_list:
        if performer.get("x-isHeadliner"):
            artist = performer.get("name")
        lineup.append(performer.get("name"))
    return [artist, lineup]


# ---------- Service ----------
class JambaseService:
    def __init__(self):
        self.router = APIRouter()

        self.router.add_api_route(
            "/", self.root, methods=["GET"], tags=["meta"]
        )
        self.router.add_api_route(
            "/search",
            self.search,
            methods=["GET"],
            response_model=EventSearchResponse,
            tags=["events"],
        )

    async def root(self):
        """Health check endpoint."""
        return {"status": "ok", "message": "Jambase service is running."}

    async def search(
        self,
        city: Optional[str] = Query(None, description="City to search concerts for"),
        start_date: Optional[str] = Query(None, description="Search start date (YYYY-MM-DD)"),
        end_date: Optional[str] = Query(None, description="Search end date (YYYY-MM-DD)"),
        keyword: Optional[str] = Query(None, description="Search keyword"),
        page: int = 0,
        size: int = 50,
    ):
        """Query JamBase and return results in shared EventSearchResponse format."""
        try:
            raw = await get_events(city, start_date, end_date, keyword)
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
                    PriceRange(currency=p.get("currency"), min=p.get("min"), max=p.get("max"))
                    for p in (ev.get("priceRanges") or [])
                ] or None

                item = EventItem(
                    id=str(ev.get("id") or ev.get("event_id") or ev.get("identifier") or ""),
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
    uvicorn.run(
        "main:create_app",
        host="0.0.0.0",
        port=8002,
        reload=True,
        factory=True,
    )


if __name__ == "__main__":
    main()
