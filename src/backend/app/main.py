# app/main.py
from typing import Optional
import os
from datetime import datetime

from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .api.concerts import (
    list_concerts_service,
    get_concert_service,
)

from app.clients.jambase_client import JamBaseClient
from app.clients.ticketmaster_client import TicketmasterClient

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

@app.get("/healthz")
async def healthz():
    return {"ok": True}

@app.get("/")
async def root():
    return {"status": "ok", "message": "Backend is running. Main entry point for beatmap."}

# -------- v1 routes (Ticketmaster) --------
@app.get("/api/v1/concerts", summary="List Concerts", include_in_schema=False)
async def list_concerts(
    q: Optional[str] = Query(None, description="Legacy alias for keyword"),
    keyword: Optional[str] = Query(None, description="Preferred search keyword"),
    city: Optional[str] = None,
    countryCode: Optional[str] = "US",
    startDateTime: Optional[str] = None,
    endDateTime: Optional[str] = None,
    latlong: Optional[str] = Query(None, description="e.g. '40.726,-74.002'"),
    radius: Optional[str] = None,
    unit: Optional[str] = None,
    page: int = 0,
    size: int = 20,
    sort: Optional[str] = None,
):
    try:
        return await list_concerts_service(
            q=q,
            keyword=keyword,
            city=city,
            countryCode=countryCode,
            startDateTime=startDateTime,
            endDateTime=endDateTime,
            latlong=latlong,
            radius=radius,
            unit=unit,
            page=page,
            size=size,
            sort=sort,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Upstream error: {e}")

@app.get("/api/v1/concerts/{event_id}", summary="Get Concert Details",include_in_schema=False)
async def get_concert(event_id: str):
    try:
        return await get_concert_service(event_id)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Upstream error: {e}")

# -------- Provider-backed Search Endpoint --------

# Instantiate our client classes.
jambase_client = JamBaseClient()
ticketmaster_client = TicketmasterClient()

@app.get("/search")
async def search(
    city: str = Query(..., description="City to search concerts in."),
    start_date: str = Query(..., description="Start date YYYY-MM-DD"),
    end_date: str = Query(..., description="End date YYYY-MM-DD"),
    provider: str = Query(..., description="Provider to search (jambase, ticketmaster, auto)"),
    keyword: Optional[str] = None,
    radius: Optional[int] = None,
):
    # Build a parameters dictionary that the client interface expects.
    params = {
        "city": city,
        "start_date": start_date,
        "end_date": end_date,
        "keyword": keyword,
        "radius": radius,
    }
    prov = provider.lower()
    if prov == "jambase":
        try:
            return await jambase_client.search_events(params)
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"JamBase error: {e}")
    elif prov == "ticketmaster":
        try:
            return await ticketmaster_client.search_events(params)
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"Ticketmaster error: {e}")
    elif prov == "auto":
        try:
            # Try Ticketmaster first, then JamBase as a fallback.
            return await ticketmaster_client.search_events(params)
        except Exception:
            try:
                return await jambase_client.search_events(params)
            except Exception as e:
                raise HTTPException(status_code=502, detail=f"Auto provider error: {e}")
    else:
        raise HTTPException(status_code=400, detail="Unsupported provider")
