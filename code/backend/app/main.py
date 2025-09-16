from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def root():
    return {"status": "ok", "message": "Backend is running. Main entry point for beatmap."}
