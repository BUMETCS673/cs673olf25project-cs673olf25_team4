"""
main.py

Acts as the main entry point for JamBase provider.
Exposes FastAPI endpoints that call code from jambase_client
"""

from datetime import date
from typing import List, Dict, Any

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel

from backend.app.api.concerts import get_concert_objs_from_jambase


app = FastAPI(title="JamBase Provider", version="1.0.0")

class ConcertResponse(BaseModel):
    source: str
    parameters: List[str]
    results: List[Dict[str, Any]]


@app.get("/")
async def root():
    """Health check endpoint."""
    return {"status": "ok", "message": "Jambase service is running."}


@app.get("/jambase/search", response_model=ConcertResponse)
async def search(
    city: str = Query(..., description="City to search concerts for"),
    start_date: date = Query(..., description="Search start date (YYYY-MM-DD)"),
    end_date: date = Query(..., description="Search end date (YYYY-MM-DD)"),
):
    """
    Gets Concert objects from concerts.py result after querying the JamBase API.
    """

    try:
        concerts = await get_concert_objs_from_jambase(city, start_date, end_date)
    except Exception as e:
        raise HTTPException(
            status_code=502, detail=f"Failed to fetch data from JamBase: {str(e)}"
        )

    return ConcertResponse(
        source="jambase",
        parameters=[city, str(start_date), str(end_date)],
        results=[c.to_dict() for c in concerts],
    )
