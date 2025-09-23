from datetime import datetime, timedelta, timezone
import os
from typing import List, Optional
import httpx
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from dotenv import load_dotenv

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


app = FastAPI(title="ticketmaster-provider")


# ---------- Helpers ----------
async def _tm_get(path: str, params: dict) -> dict:
    if not TM_KEY:
        raise HTTPException(500, "TM_API_KEY not configured")

    clean = {k: v for k, v in params.items() if v is not None}
    clean["apikey"] = TM_KEY

    timeout = httpx.Timeout(10.0, read=20.0)
    print(f"Ticketmaster GET {path} with params: {clean}")
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


# ---------- Endpoints ----------
@app.get("/", tags=["meta"])
async def root():
    return {
        "status": "ok",
        "message": "Ticketmaster service is running.",
    }


@app.get(
    "/search",
    response_model=EventSearchResponse,
    tags=["events"],
)
async def search_events(
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
        "keyword": keyword,
        "city": city,
        "countryCode": country_code,
        "startDateTime": start_date,
        "endDateTime": end_date,
        "page": page,
        "size": size,
        "sort": sort,
        "classificationName": "Music",
    }

    if(params["startDateTime"] is not None):
        try:
            # Try parsing as full ISO format first
            dt = datetime.fromisoformat(params["startDateTime"])
        except ValueError:
            try:
                # Try parsing as YYYY-MM-DD
                dt = datetime.strptime(params["startDateTime"], "%Y-%m-%d")
            except ValueError:
                try:
                    # Try parsing as YYYY-MM-DDTHH:MM
                    dt = datetime.strptime(params["startDateTime"], "%Y-%m-%dT%H:%M")
                except ValueError:
                    raise HTTPException(400, "Invalid startDateTime format")
        params["startDateTime"] = dt.replace(tzinfo=timezone(timedelta(hours=-4))).isoformat()

    if(params["endDateTime"] is not None):
        try:
            # Try parsing as full ISO format first
            dt = datetime.fromisoformat(params["endDateTime"])
        except ValueError:
            try:
                # Try parsing as YYYY-MM-DD
                dt = datetime.strptime(params["endDateTime"], "%Y-%m-%d")
            except ValueError:
                try:
                    # Try parsing as YYYY-MM-DDTHH:MM
                    dt = datetime.strptime(params["endDateTime"], "%Y-%m-%dT%H:%M")
                except ValueError:
                    raise HTTPException(400, "Invalid endDateTime format")
        params["endDateTime"] = dt.replace(tzinfo=timezone(timedelta(hours=-4))).isoformat()

    clean_params = {k: v for k, v in params.items() if v is not None}

    print(f"Ticketmaster search with params: {clean_params}")

    raw = await _tm_get("/events.json", clean_params)
    page_info = raw.get("page", {})

    items = [
        _parse_event(e) for e in (raw.get("_embedded", {}).get("events") or [])
    ]  # noqa: E501

    next_link = (raw.get("_links", {}) or {}).get("next", {}).get("href")

    return EventSearchResponse(
        totalElements=page_info.get("totalElements", 0),
        page=page_info.get("number", page),
        size=page_info.get("size", size),
        data=items,
        next=next_link,
    )


@app.get(
    "/events/{event_id}",
    response_model=EventItem,
    tags=["events"],
)
async def get_event(event_id: str):
    raw = await _tm_get(
        f"/events/{event_id}.json",
        {},
    )
    return _parse_event(raw)
