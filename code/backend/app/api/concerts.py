# code/backend/app/api/concerts.py
from typing import Optional
from fastapi import APIRouter, HTTPException, Query
import httpx

from ..clients import ticketmaster_client

router = APIRouter(tags=["concerts"])

@router.get("/concerts", summary="List Concerts")
async def list_concerts(
    q: Optional[str] = Query(None, description="兼容旧写法：搜索词"),
    keyword: Optional[str] = Query(None, description="推荐：搜索词（与 Ticketmaster 对齐）"),
    city: Optional[str] = None,
    countryCode: Optional[str] = "US",
    startDateTime: Optional[str] = None,
    endDateTime: Optional[str] = None,
    latlong: Optional[str] = Query(None, description="例如 '40.726,-74.002'"),
    radius: Optional[str] = None,
    unit: Optional[str] = None,
    page: int = 0,
    size: int = 20,
    sort: Optional[str] = None,
):
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
        raise HTTPException(status_code=e.response.status_code, detail=e.response.text)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Upstream error: {e}")

@router.get("/concerts/{event_id}", summary="Get Concert")
async def get_concert(event_id: str):
    try:
        return await ticketmaster_client.get_event(event_id)
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=e.response.text)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Upstream error: {e}")
