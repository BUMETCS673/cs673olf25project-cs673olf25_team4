"""
jambase_client.py

Directly interacts with Jambase API. Queries the events endpoint based
on a city and a date range, and the cities endpoint which is required
to search for events.
"""

import os
import httpx
from typing import Dict
from dotenv import load_dotenv
from .provider_client_interface import ProviderClientInterface

load_dotenv()

JAMBASE_PROVIDER_URL = os.getenv("JAMBASE_PROVIDER_URL", "http://jambase_provider:8000")


def get_api_key():
    """
    Returns the API key for JamBase stored in env file. If not found,
    return a dummy key.

    Returns:
        A string containing the JamBase API key in the env file, if not
        found a dummy key.
    """
    return os.getenv("JAMBASE_API_KEY", "dummy-test-key")


class JamBaseClient(ProviderClientInterface):
    async def search_events(self, params: Dict) -> Dict:
        # JamBase expects the keyword parameter as 'q'
        clean = {k: v for k, v in params.items() if v is not None}
        if "keyword" in clean:
            clean["q"] = clean.pop("keyword")
        # JamBase may expect dates in a certain format—assume they are preformatted
        print(f"{JAMBASE_PROVIDER_URL}/search")
        print(clean)
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(f"{JAMBASE_PROVIDER_URL}/search", params=clean)
            response.raise_for_status()
            return response.json()

    async def get_event(self, event_id: str) -> Dict:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(f"{JAMBASE_PROVIDER_URL}/events/{event_id}")
            response.raise_for_status()
            return response.json()


async def get_events(city_str, start_date, end_date):
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
    }
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
