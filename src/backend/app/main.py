"""
main.py

Acts as the main entry point for BeatMap. Interacts with the API provider
based on what the user requested.
"""

import httpx
from fastapi import FastAPI, Query

app = FastAPI()


@app.get("/")
async def root():
    return {
        "status": "ok",
        "message": "Backend is running. Main entry point for beatmap.",
    }


@app.get("/search")
async def search(
    city: str = Query(..., description="City to search concerts in."),
    start_date: str = Query(..., description="Start date YYYY-MM-DD"),
    end_date: str = Query(..., description="End date YYYY-MM-DD"),
    provider: str = Query(..., description="Provider to search"),
):
    """
    Search endpoint for BeatMap, calls the associated provider based on what
    is provided in the query parameters.

    Args:
        city: The city to search concerts in, provided by URL
        query parameters.
        start_date: The start date to search concerts for provided by URL
        query parameters. Hopefully in YYYY-MM-DD format.
        end_date: The end date to search concerts for provided by URL
        query parameters. Hopefully in YYYY-MM-DD format.
        provider: The API provider to query the events from, provided by
        URL parameters.

    Returns:
        JSON with the response from the associated API, hopefully formatted
        using a standardized Concert object.
    """
    if provider.lower() == "jambase":
        # TODO: not sure how to send a request to jambase
        #  microservice from here
        url = "http://localhost:8002/jambase/search"
        async with httpx.AsyncClient() as client:
            response = await client.get(
                url,
                params={
                    "city": city,
                    "start_date": start_date,  # noqa: E501
                    "end_date": end_date,
                },
            )
        return response.json()
