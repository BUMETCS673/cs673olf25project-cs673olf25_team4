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
    provider: str = Query(..., description="Provider to search events from"),
):
    if provider.lower() == "jambase":
        # TODO: not sure how to send a request to jambase
        #  microservice from here
        url = "http://localhost:8002/jambase/search"
        async with httpx.AsyncClient() as client:
            response = await client.get(
                url,
                params={"city": city, "start_date": start_date,
                        "end_date": end_date},
            )
        return response.json()
