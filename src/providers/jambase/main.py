from fastapi import FastAPI
from backend.app.api.concerts import get_concert_objs_from_jambase

app = FastAPI()


@app.get("/")
async def root():
    return {"status": "ok", "message": "Jambase service is running."}


@app.get("/jambase/search")
async def search(city: str, start_date: str, end_date: str):
    concerts = await get_concert_objs_from_jambase(city, start_date, end_date)
    # return the data as JSON back to the frontend
    return {"source": "jambase", "parameters": [city, start_date, end_date], "results": [c.to_dict() for c in concerts]}
