# app/clients/ticketmaster_client.py
import os
import httpx

TM_PROVIDER_URL = os.getenv("TM_PROVIDER_URL", "http://ticketmaster_provider:8000")


async def search_events(params: dict) -> dict:
    """Call Ticketmaster provider /events with query params."""
    clean = {k: v for k, v in params.items() if v is not None}
    async with httpx.AsyncClient(timeout=20.0) as c:
        r = await c.get(f"{TM_PROVIDER_URL}/events", params=clean)
        r.raise_for_status()
        return r.json()


async def get_event(event_id: str) -> dict:
    """Call Ticketmaster provider /events/{id}."""
    async with httpx.AsyncClient(timeout=20.0) as c:
        r = await c.get(f"{TM_PROVIDER_URL}/events/{event_id}")
        r.raise_for_status()
        return r.json()


async def search_by_city_dates(
    city: str,
    start_date: str,  # YYYY-MM-DD
    end_date: str,    # YYYY-MM-DD
    *,
    size: int = 20,
    page: int = 0,
    country_code: str | None = None,
) -> dict:
    """Convenience wrapper: search by city + date range."""
    params = {
        "city": city,
        "startDateTime": f"{start_date}T00:00:00Z",
        "endDateTime": f"{end_date}T23:59:59Z",
        "size": size,
        "page": page,
        "countryCode": country_code,
    }
    return await search_events(params)
