# app/main.py
import random
import os
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import httpx

load_dotenv()
JAMBASE_PROVIDER_URL = os.getenv("JAMBASE_PROVIDER_URL", "http://jambase_provider:8000")
TM_PROVIDER_URL = os.getenv("TM_PROVIDER_URL", "http://ticketmaster_provider:8000")

concert_data_providers = {
    "jambase": JAMBASE_PROVIDER_URL,
    "ticketmaster": TM_PROVIDER_URL,
}


app = FastAPI(title="beatmap-backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://3.144.211.10:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    return {
        "status": "ok",
        "message": "Backend is running. Main entry point for beatmap.",
    }


@app.get("/search")
async def search(
    city: str = Query(None, description="City to search concerts in."),
    start_date: str = Query(None, description="Start date YYYY-MM-DD"),
    end_date: str = Query(None, description="End date YYYY-MM-DD"),
    provider: str = Query(
        None, description="Provider to search (jambase, ticketmaster)"
    ),
    keyword: Optional[str] = None,
):
    # Build a parameters dictionary that the client interface expects.
    params = {
        "city": city,
        "start_date": start_date,
        "end_date": end_date,
        "keyword": keyword,
    }
    print(params)

    if provider is None:
        provider = random.choice(["jambase", "ticketmaster"])
    else:
        provider = provider.lower()

    try:
        # Remove any parameters that are None.
        print(params)
        clean = {k: v for k, v in params.items() if v is not None}
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(
                f"{concert_data_providers[provider]}/search", params=clean
            )
            response.raise_for_status()
            return response.json()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Error fetching concert data: {e}")
