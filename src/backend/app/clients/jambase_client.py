"""
jambase_client.py

Directly interacts with Jambase API. Queries the events endpoint based
on a city and a date range, and the cities endpoint which is required
to search for events.
"""
import httpx
import os
from dotenv import load_dotenv

load_dotenv()


def get_api_key():
    """
    Returns the API key for JamBase stored in env file. If not found,
    return a dummy key.

    Returns:
        A string containing the JamBase API key in the env file, if not
        found a dummy key.
    """
    return os.getenv("JAMBASE_API_KEY", "dummy-test-key")


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

    url = "https://www.jambase.com/jb-api/v1/events"

    # each query to the API requires an API key.
    query_string = {
        "apikey": get_api_key(),
        "eventDateFrom": start_date,
        "eventDateTo": end_date,
        "geoCityId": jambase_city_id,
    }
    async with httpx.AsyncClient() as client:
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

    async with httpx.AsyncClient() as client:
        response = await client.get(url, params=query_string)
        # TODO: how should this be implemented? what if multiple cities
        #  are returned? do we want every city that the API returns?
        # a list of cities is returned from the cities endpoint. as of now
        # get the identifier for the first city returned, they are sorted
        # by the amount of events in the city, highest to lowest
        return response.json().get("cities")[0].get("identifier")
