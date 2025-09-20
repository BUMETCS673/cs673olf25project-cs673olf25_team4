import httpx
import os
from dotenv import load_dotenv

load_dotenv()
jambase_key = os.environ["JAMBASE_API_KEY"]


async def get_events(city_str, start_date, end_date):
    jambase_city_id = await get_city_id(city_str)

    url = "https://www.jambase.com/jb-api/v1/events"
    query_string = {
        "apikey": jambase_key,
        "eventDateFrom": start_date,
        "eventDateTo": end_date,
        "geoCityId": jambase_city_id,
    }
    async with httpx.AsyncClient() as client:
        response = await client.get(url, params=query_string)
        return response.json()


async def get_city_id(city_str):
    url = "https://www.jambase.com/jb-api/v1/geographies/cities"
    query_string = {"apikey": jambase_key, "geoCityName": city_str}

    async with httpx.AsyncClient() as client:
        response = await client.get(url, params=query_string)
        # TODO: how should this be implemented? what if multiple cities are returned? do we want every city that the
        #  API returns?
        return response.json().get("cities")[0].get("identifier")
