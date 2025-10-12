# src/backend/tests/test_recommendation_ai.py
import httpx
from fastapi.testclient import TestClient
from app.main import app
from app.api.concerts import ConcertsService

client = TestClient(app)

# Mock helpers
class MockResponse:
    """Lightweight mock for httpx responses"""
    def __init__(self, json_data=None, status_code=200):
        self._json = json_data or {}
        self.status_code = status_code

    def json(self):
        return self._json

    def raise_for_status(self):
        if self.status_code >= 400:
            raise httpx.HTTPStatusError("error", request=None, response=None)


# AI recommendation payload expected by enrich_recommendations
RECO_OK = {
    "recommendations": [
        {
            "event_id": "evt1",
            "rank": 1,
            "event": {
                "name": "Taylor Swift",
                "venue": {"name": "TD Garden", "city": "Boston"},
                "url": "https://tickets.example.com",
                "date": "2025-10-10",
            },
            "reason": "Top pick in Boston",
        }
    ],
    "summary": "Top pick: Taylor Swift at TD Garden.",
}

# Mocks for GroqClient
async def mock_request_success(self, method, url, **kwargs):
    """Simulate Groq provider normal responses for all AI sub-endpoints"""
    if url.endswith("/tokens"):
        return MockResponse({"locations": ["Boston"], "start_date": None, "end_date": None, "artists": []})
    if url.endswith("/preferences"):
        return MockResponse({"genres": ["pop"], "locations": ["Boston"]})
    if url.endswith("/recommendations"):
        return MockResponse(RECO_OK)
    return MockResponse({}, status_code=200)


async def mock_request_fail(self, method, url, **kwargs):
    """Simulate Groq provider returning 5xx"""
    return MockResponse({}, status_code=500)


async def mock_request_timeout(self, method, url, **kwargs):
    """Simulate Groq provider timeout"""
    raise httpx.TimeoutException("groq timeout")

# Mock for ConcertsService.search used by enrich_recommendations
async def mock_search(self, **kwargs):
    """Return a list with an event that matches RECO_OK.event_id"""
    return {
        "data": [
            {
                "id": "evt1",
                "name": "Taylor Swift",
                "venue": {"name": "TD Garden", "city": "Boston"},
                "url": "https://tickets.example.com",
                "date": "2025-10-10",
            }
        ]
    }

# Tests
def test_recommendations_success(monkeypatch):
    """Endpoint returns recommendations+summary when Groq succeeds"""
    monkeypatch.setattr("app.core.groq_client.httpx.AsyncClient.request", mock_request_success)
    monkeypatch.setattr(ConcertsService, "search", mock_search, raising=True)

    resp = client.get("/concerts/recommendations", params={"user_input": "rock in Boston"})
    assert resp.status_code == 200

    data = resp.json()
    assert isinstance(data.get("recommendations"), list)
    assert isinstance(data.get("summary"), str)
    assert data["recommendations"]
    assert data["recommendations"][0]["event"]["venue"]["city"] == "Boston"
    assert "Taylor" in data["recommendations"][0]["event"]["name"]


def test_recommendations_provider_fail(monkeypatch):
    """Provider error returns fallback JSON (status 200, stable structure)"""
    monkeypatch.setattr("app.core.groq_client.httpx.AsyncClient.request", mock_request_fail)

    resp = client.get("/concerts/recommendations", params={"user_input": "any"})
    assert resp.status_code == 200

    data = resp.json()
    assert "recommendations" in data and isinstance(data["recommendations"], list)
    assert "summary" in data and isinstance(data["summary"], str)


def test_recommendations_timeout(monkeypatch):
    """Timeout returns fallback JSON (status 200, stable structure)"""
    monkeypatch.setattr("app.core.groq_client.httpx.AsyncClient.request", mock_request_timeout)

    resp = client.get("/concerts/recommendations", params={"user_input": "any"})
    assert resp.status_code == 200

    data = resp.json()
    assert "recommendations" in data and isinstance(data["recommendations"], list)
    assert "summary" in data and isinstance(data["summary"], str)
