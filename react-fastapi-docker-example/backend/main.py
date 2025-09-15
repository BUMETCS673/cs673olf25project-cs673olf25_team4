from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict
import time

app = FastAPI(title="Hello World API", description="A simple FastAPI backend", version="1.0.0")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class MessageResponse(BaseModel):
    message: str
    timestamp: float
    status: str

class GreetingRequest(BaseModel):
    name: str

@app.get("/")
async def root() -> Dict[str, str]:
    """Root endpoint"""
    return {"message": "Hello from FastAPI backend!"}

@app.get("/api/hello", response_model=MessageResponse)
async def hello() -> MessageResponse:
    """Simple hello endpoint"""
    return MessageResponse(
        message="Hello, World from FastAPI!",
        timestamp=time.time(),
        status="success"
    )

@app.post("/api/greet", response_model=MessageResponse)
async def greet(request: GreetingRequest) -> MessageResponse:
    """Personalized greeting endpoint"""
    return MessageResponse(
        message=f"Hello, {request.name}! Welcome to our full-stack app!",
        timestamp=time.time(),
        status="success"
    )

@app.get("/api/health")
async def health_check() -> Dict[str, str]:
    """Health check endpoint"""
    return {"status": "healthy", "service": "fastapi-backend"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)