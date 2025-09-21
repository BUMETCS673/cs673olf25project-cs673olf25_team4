# app/clients/ticketmaster_client.py
import os
import httpx
from typing import Dict
from .provider_client_interface import ProviderClientInterface

TM_PROVIDER_URL = os.getenv("TM_PROVIDER_URL", "http://ticketmaster_provider:8000")

class TicketmasterClient(ProviderClientInterface):
    async def search_events(self, params: Dict) -> Dict:
        # Remove any parameters that are None.
        clean = {k: v for k, v in params.items() if v is not None}
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(f"{TM_PROVIDER_URL}/events", params=clean)
            response.raise_for_status()
            return response.json()

    async def get_event(self, event_id: str) -> Dict:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(f"{TM_PROVIDER_URL}/events/{event_id}")
            response.raise_for_status()
            return response.json()
