"""
main.py

Acts as the main entry point for JamBase provider.
Exposes FastAPI endpoints that call code from jambase_client
"""

from datetime import date
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


@app.get("/search", response_model=ConcertResponse)
async def search(
    city: Optional[str]  = Query(None, description="City to search concerts for"),
    start_date: Optional[str] = Query(None, description="Search start date (YYYY-MM-DD)"),  # noqa
    end_date: Optional[str] = Query(None, description="Search end date (YYYY-MM-DD)"),  # noqa
    keyword: Optional[str] = Query(None, description="Keyword"),  # noqa
):
    """
    Gets Concert obj from concerts.py result after querying the JamBase API.
    """
    
    print("Jambase search called with:", city, start_date, end_date, keyword)

    try:
        concerts = await get_concert_objs_from_jambase(
            city, start_date, end_date, keyword
        )  # noqa
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to fetch data from JamBase: {str(e)}",  # noqa
        )

    return ConcertResponse(
        source="jambase",
        parameters=[city, str(start_date), str(end_date)],
        results=[c.to_dict() for c in concerts],
    )