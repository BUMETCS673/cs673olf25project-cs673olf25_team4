# providers/ticketmaster/main.py
import os
from typing import List, Optional
import httpx
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from dotenv import load_dotenv

# Load .env file from the project root directory
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", "..", ".env"))

TM_BASE = os.getenv("TM_BASE_URL", "https://app.ticketmaster.com/discovery/v2")
TM_KEY  = os.getenv("TM_API_KEY")

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
    lat: Optional[float] = None
    lon: Optional[float] = None

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
        lat=float(v0["location"]["latitude"]) if v0.get("location", {}).get("latitude") else None,
        lon=float(v0["location"]["longitude"]) if v0.get("location", {}).get("longitude") else None,
    )

    prices = [
        PriceRange(currency=p.get("currency"), min=p.get("min"), max=p.get("max"))
        for p in (e.get("priceRanges") or [])
    ] or None

    return EventItem(
        id=e["id"], name=e.get("name"), url=e.get("url"),
        startDateTime=start, segment=seg, genre=gen,
        venue=venue, priceRanges=prices
    )

# ---------- Endpoints ----------
@app.get("/", tags=["meta"])
async def root():
    return {"status": "ok", "message": "Ticketmaster service is running."}

@app.get("/healthz", tags=["meta"])
async def healthz():
    return {"ok": True}

@app.get("/events", response_model=EventSearchResponse, tags=["events"])
async def search_events(
    keyword: Optional[str] = None,
    city: Optional[str] = None,
    countryCode: Optional[str] = None,
    startDateTime: Optional[str] = None,
    endDateTime: Optional[str] = None,
    latlong: Optional[str] = Query(None, description="e.g. '40.726,-74.002'"),
    radius: Optional[str] = None,
    unit: Optional[str] = None,
    page: int = 0,
    size: int = 20,
    sort: Optional[str] = None,
):
    raw = await _tm_get("/events.json", locals())
    page_info = raw.get("page", {})
    items = [_parse_event(e) for e in (raw.get("_embedded", {}).get("events") or [])]
    next_link = (raw.get("_links", {}) or {}).get("next", {}).get("href")
    return EventSearchResponse(
        totalElements=page_info.get("totalElements", 0),
        page=page_info.get("number", page),
        size=page_info.get("size", size),
        data=items,
        next=next_link,
    )

@app.get("/events/{event_id}", response_model=EventItem, tags=["events"])
async def get_event(event_id: str):
    raw = await _tm_get(f"/events/{event_id}.json", {})
    return _parse_event(raw)
