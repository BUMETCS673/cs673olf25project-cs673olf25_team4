# app/api/concerts.py
"""
concerts.py

- JamBase helpers (kept unchanged):
  Concert class, get_concert_objs_from_jambase, jambase_parse_performers
- Ticketmaster services (new): list_concerts_service, get_concert_service
  (no APIRouter here; routes are defined in app/main.py)
"""

from typing import Optional
import httpx
from fastapi import HTTPException

# ---------------- JamBase (UNTOUCHED) ----------------
from ..clients.jambase_client import get_events as jambase_get_events
from ..clients import ticketmaster_client


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


async def get_concert_objs_from_jambase(city, start_date, end_date):
    """
    Gets the data from JamBase for events in a city in a date range.
    """
    event_data = await jambase_get_events(city, start_date, end_date)
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


async def list_concerts_service(
    *,
    q: Optional[str] = None,
    keyword: Optional[str] = None,
    city: Optional[str] = None,
    countryCode: Optional[str] = "US",
    startDateTime: Optional[str] = None,
    endDateTime: Optional[str] = None,
    latlong: Optional[str] = None,
    radius: Optional[str] = None,
    unit: Optional[str] = None,
    page: int = 0,
    size: int = 20,
    sort: Optional[str] = None,
):
    """Build params and proxy to Ticketmaster client (no router here)."""
    search_keyword = keyword or q
    params = {
        "keyword": search_keyword,
        "city": city,
        "countryCode": countryCode,
        "startDateTime": startDateTime,
        "endDateTime": endDateTime,
        "latlong": latlong,
        "radius": radius,
        "unit": unit,
        "page": page,
        "size": size,
        "sort": sort,
    }
    try:
        return await ticketmaster_client.search_events(params)
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=e.response.text)


async def get_concert_service(event_id: str):
    """Proxy to Ticketmaster client get_event (no router here)."""
    try:
        return await ticketmaster_client.get_event(event_id)
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=e.response.text)
