from fastapi import FastAPI

app = FastAPI()


@app.get("/")
async def root():
    return {"status": "ok", "message": "Pollstar service is running."}


@app.get("/search")
async def search(q: str):
    return {"source": "pollstar", "query": q, "results": []}
