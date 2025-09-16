from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def root():
    return {"status": "ok", "message": "Ticketmaster service is running."}

@app.get("/search")
async def search(q: str):
    return {"source": "ticketmaster", "query": q, "results": []}
