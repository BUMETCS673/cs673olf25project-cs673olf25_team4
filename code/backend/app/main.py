# code/backend/app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .api.concerts import router as concerts_router


app = FastAPI(title="beatmap-backend")

# router version
app.include_router(concerts_router, prefix="/api/v1")

@app.get("/healthz")
async def healthz():
    return {"ok": True}

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

app.include_router(concerts_router, prefix="/api/v1")

@app.get("/healthz")
async def healthz():
    return {"ok": True}