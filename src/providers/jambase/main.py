"""
main.py

Acts as the main entry point for JamBase provider.
Exposes FastAPI endpoints that call code from jambase_client
"""
from fastapi import FastAPI
from src.backend.app.api.concerts import get_concert_objs_from_jambase

app = FastAPI()


@app.get("/")
async def root():
    return {"status": "ok", "message": "Jambase service is running."}


@app.get("/jambase/search")
async def search(city: str, start_date: str, end_date: str):
    """
    Gets Concert objects from concerts.py result after querying the JamBase
    API. Supplies city, start_date, end_date provided by the URL.

    Args:
        city: The city to get the events for, supplied by
        the URL query parameters.
        start_date: The start date for the search, supplied by
        the URL query parameters. Hopefully in YYYY-MM-DD format.
        end_date: The end date for the search, supplied by the URL query
        parameters, hopefully in YYY-MM-DD format.

    Returns:
        JSON object with the source, query parameters received at first, and
        a list of dictionaries representing the Concert objects we got from
        concerts.py
    """
    concerts = await get_concert_objs_from_jambase(city, start_date, end_date)
    # return the data as JSON back to the frontend
    return {
        "source": "jambase",
        "parameters": [city, start_date, end_date],
        "results": [c.to_dict() for c in concerts],
    }
