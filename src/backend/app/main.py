"""
app/main.py

Entry point for BeatMap backend.
Wires up API routers and runs the FastAPI app.
"""

import uvicorn
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.concerts import ConcertsService


def create_app() -> FastAPI:
    app = FastAPI(title="beatmap-backend")

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

    # Register ConcertsService
    concerts_service = ConcertsService()
    app.include_router(concerts_service.router)

    return app


# Expose app instance for uvicorn CLI
app = create_app()


def main():
    """Run the backend with uvicorn directly."""
    host = os.getenv(
        "BEATMAP_HOST", "127.0.0.1"
    )  # default to localhost to avoid binding all interfaces
    port = int(os.getenv("BEATMAP_PORT", "8000"))

    uvicorn.run(
        "app.main:create_app",
        host=host,
        port=port,
        reload=True,
        factory=True,
    )


if __name__ == "__main__":
    main()
