import os

from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Prefer a mounted directory inside the container at /app/frontend_public
# Fallback to the repository relative path when running outside a container.
_container_static = "/app/frontend_public"
_repo_static = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "frontend", "public")
)

STATIC_DIR = (
    _container_static
    if os.path.isdir(_container_static)
    else _repo_static
)

if os.path.isdir(STATIC_DIR):
    # Mount static files under /static (assets can be served from here)
    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


@app.get("/")
async def root():
    """Serve the SPA index.html when available.

    If the frontend build is mounted (via docker-compose) the index.html
    file is returned. Otherwise a small JSON status response is
    returned so the API is still discoverable when running without
    the frontend files.
    """
    index_path = os.path.join(STATIC_DIR, "index.html")
    if os.path.isfile(index_path):
        # Return the prebuilt index.html (the page's inline
        # script calls backend endpoints).
        return FileResponse(index_path)

    return JSONResponse(
        {
            "status": "ok",
            "message": "Backend is running. Main entry point for beatmap.",
        }
    )
