"""
main.py

Acts as the main entry point for JamBase provider.
Exposes FastAPI endpoints that call code from jambase_client.

Most of this code was written by humans.
We asked Copilot to help us refactor the /search endpoint
to match the same response model as the Ticketmaster provider,
so that the backend can treat them
the same way.
"""

from datetime import datetime
import os
from typing import List, Dict, Any, Optional

from fastapi import FastAPI, HTTPException, Query
import httpx
from pydantic import BaseModel

app = FastAPI(title="JamBase Provider", version="1.0.0")


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


async def get_events(city_str, start_date, end_date, keyword=None):
    """
    Queries the events JamBase endpoint based on a city, start date, end date.

    Args:
        city_str: The city name to query.
        start_date: The start date to query in YYYY-MM-DD format.
        end_date: The end date to query in YYYY-MM-DD format.

    Returns:
        JSON containing the JamBase API response.
    """
    # the events endpoint requires a JamBase city id, get this from the
    # cities endpoint in JamBase
    # wait for the result from the API but don't block
    jambase_city_id = await get_city_id(city_str)
    print("jambase_city_id:", jambase_city_id)

    url = "https://www.jambase.com/jb-api/v1/events"

    # each query to the API requires an API key.
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
    """
    Queries the cities JamBase endpoint based on a city string to get
    the city id in JamBase. This is required to query the events endpoint

    Args:
        city_str: The city name to get the JamBase id for.

    Returns:
        A string of the JamBase city id found from the endpoint.
    """
    if city_str is None:
        return None

    url = "https://www.jambase.com/jb-api/v1/geographies/cities"
    query_string = {"apikey": get_api_key(), "geoCityName": city_str}

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.get(url, params=query_string)
        # TODO: how should this be implemented? what if multiple cities
        #  are returned? do we want every city that the API returns?
        # a list of cities is returned from the cities endpoint. as of now
        # get the identifier for the first city returned, they are sorted
        # by the amount of events in the city, highest to lowest
        return response.json().get("cities")[0].get("identifier")


def get_api_key():
    """
    Returns the API key for JamBase stored in env file. If not found,
    return a dummy key.

    Returns:
        A string containing the JamBase API key in the env file, if not
        found a dummy key.
    """
    return os.getenv("JAMBASE_API_KEY", "dummy-test-key")


async def get_concert_objs_from_jambase(city, start_date, end_date, keyword):
    """
    Gets the data from JamBase for events in a city in a date range.
    """
    event_data = await get_events(city, start_date, end_date, keyword)
    concerts = []

    for event in event_data.get("events"):
        performer_result = jambase_parse_performers(event.get("performer"))
        concerts.append(
            Concert(
                event.get("identifier"),
                event.get("name"),
                event.get("location").get("name"),
                event.get("startDate"),
                performer_result[0],
                performer_result[1],
            )
        )

    return concerts


class Concert:
    def __init__(self, id, name, venue, date, artist, lineup):
        self.id = id
        self.name = name
        self.venue = venue
        self.date = date
        self.artist = artist
        self.lineup = lineup

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "venue": self.venue,
            "date": self.date,
            "artist": self.artist,
            "lineup": self.lineup,
        }


def jambase_parse_performers(performer_list):
    """
    Extract headliner and lineup from JamBase performer list.
    """
    artist = ""
    lineup = []
    for performer in performer_list:
        if performer.get("x-isHeadliner"):
            artist = performer.get("name")
        lineup.append(performer.get("name"))
    return [artist, lineup]


@app.get("/")
async def root():
    """Health check endpoint."""
    return {"status": "ok", "message": "Jambase service is running."}


@app.get("/search", response_model=EventSearchResponse)
async def search(
    city: Optional[str] = Query(None, description="City to search concerts for"),
    start_date: Optional[str] = Query(
        None, description="Search start date (YYYY-MM-DD)"
    ),
    end_date: Optional[str] = Query(None, description="Search end date (YYYY-MM-DD)"),
    keyword: Optional[str] = Query(None, description="Search keyword"),
    page: int = 0,
    size: int = 50,
):
    """
    Query JamBase and return results using the shared EventSearchResponse format
    (same shape as Ticketmaster provider).
    """
    try:
        # call existing helper that queries JamBase API and returns raw JSON
        raw = await get_events(city, start_date, end_date, keyword)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"JamBase upstream error: {e}")

    events = raw.get("events", []) if isinstance(raw, dict) else []
    items: List[EventItem] = []
    for ev in events:
        try:
            # location in JamBase is under "location" (sample) — fallback to "venue"
            loc = ev.get("location") or ev.get("venue") or {}
            addr = loc.get("address", {}) if isinstance(loc, dict) else {}
            # Build venue with best-effort fields
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

            # startDate / startDateTime / datetime mapping
            start_dt = (
                ev.get("startDate")
                or ev.get("startDateTime")
                or ev.get("datetime")
                or ev.get("datePublished")
            )
            if isinstance(start_dt, datetime):
                start_dt = start_dt.isoformat()

            # segment: prefer explicit field, otherwise use @type or eventType
            segment = ev.get("segment") or ev.get("eventType") or ev.get("@type")

            # genre: aggregate genres from performers (de-duplicate)
            genres = []
            for p in ev.get("performer", []) or []:
                g = p.get("genre")
                if isinstance(g, list):
                    for gg in g:
                        if gg and gg not in genres:
                            genres.append(gg)
                elif g:
                    if g not in genres:
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
            # skip malformed event
            continue

    # Build paged response; JamBase doesn't necessarily return paging in same shape,
    # so approximate using provided page/size and totalElements as length.
    total = len(items)
    start = page * size
    paged = items[start : start + size]  # noqa: E203

    return EventSearchResponse(
        totalElements=total,
        page=page,
        size=len(paged),
        data=paged,
        next=None,
    )
