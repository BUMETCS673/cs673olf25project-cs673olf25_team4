from fastapi import FastAPI

app = FastAPI()


@app.get("/")
async def root():
    return {"status": "ok", "message": "Jambase service is running."}


@app.get("/search")
async def search(q: str):
    return {"source": "jambase", "query": q, "results": []}
