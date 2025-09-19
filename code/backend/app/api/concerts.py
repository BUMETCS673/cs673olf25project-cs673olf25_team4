from typing import Optional
from fastapi import APIRouter, HTTPException, Query
import httpx

from ..clients import ticketmaster_client

# Router for concerts-related endpoints
router = APIRouter(tags=["concerts"])


@router.get("/concerts", summary="List Concerts")
async def list_concerts(
    q: Optional[str] = Query(
        None,
        description=("Legacy alias for keyword "),
    ),
    keyword: Optional[str] = Query(
        None,
        description=(
            "Preferred: search keyword \n " 
            "(aligned with Ticketmaster)"
        ),
    ),
    city: Optional[str] = None,
    countryCode: Optional[str] = "US",
    startDateTime: Optional[str] = None,
    endDateTime: Optional[str] = None,
    latlong: Optional[str] = Query(
        None,
        description=("Latitude,Longitude " 
                     "(e.g. '40.726,-74.002')"),
    ),
    radius: Optional[str] = None,
    unit: Optional[str] = None,
    page: int = 0,
    size: int = 20,
    sort: Optional[str] = None,
):
    """
    Search concerts by keyword, location, date, or pagination options.
    This endpoint proxies the request to the Ticketmaster provider.
    """
    search_keyword = keyword or q
    params = {
        "keyword": search_keyword,
        "city": city,
        "countryCode": countryCode,
        "startDateTime": startDateTime,
        "endDateTime": endDateTime,
        "latlong": latlong,
        "radius": radius,
        "unit": unit,
        "page": page,
        "size": size,
        "sort": sort,
    }
    try:
        return await ticketmaster_client.search_events(params)
    except httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=e.response.status_code,
            detail=e.response.text,
        )
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Upstream error: {e}",
        )


@router.get("/concerts/{event_id}", summary="Get Concert Details")
async def get_concert(event_id: str):
    """
    Get detailed information for a single concert by its event ID.
    """
    try:
        return await ticketmaster_client.get_event(event_id)
    except httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=e.response.status_code,
            detail=e.response.text,
        )
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Upstream error: {e}",
        )
