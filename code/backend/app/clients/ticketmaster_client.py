# code/backend/app/clients/ticketmaster_client.py
import os
import httpx

# Read both new and legacy env vars; default to service name in Docker network.
TM_PROVIDER_URL = (
    os.getenv("TM_PROVIDER_URL")
    or os.getenv("TICKETMASTER_API_URL")
    or "http://ticketmaster_provider:8000"
)


async def search_events(params: dict) -> dict:
    clean = {k: v for k, v in params.items() if v is not None}
    async with httpx.AsyncClient(timeout=20.0) as c:
        r = await c.get(f"{TM_PROVIDER_URL}/events", params=clean)
        r.raise_for_status()
        return r.json()


async def get_event(event_id: str) -> dict:
    async with httpx.AsyncClient(timeout=20.0) as c:
        r = await c.get(f"{TM_PROVIDER_URL}/events/{event_id}")
        r.raise_for_status()
        return r.json()
