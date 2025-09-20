# src/backend/tests/test_main.py
import pytest
from fastapi.testclient import TestClient
from src.backend.app.main import app

client = TestClient(app)

# ---------------- Mock Data ----------------
mock_events = {
    "totalElements": 1,
    "page": 0,
    "size": 1,
    "data": [
        {
            "id": "test123",
            "name": "Mock Concert",
            "url": "http://example.com",
            "startDateTime": "2025-01-01T00:00:00Z",
            "segment": "Music",
            "genre": "Rock",
            "venue": {
                "id": "venue1",
                "name": "Mock Arena",
                "city": "Boston",
                "country": "US",
                "lat": 42.36,
                "lon": -71.05,
            },
            "priceRanges": [{"currency": "USD", "min": 50.0, "max": 100.0}],
        }
    ],
}

# ---------------- Fixtures ----------------
@pytest.fixture
def client_fixture():
    return TestClient(app)

# ---------------- Happy Path ----------------
def test_list_concerts(monkeypatch, client_fixture):
    """Test /concerts endpoint with mock response"""

    async def mock_search_events(params):
        return mock_events

    monkeypatch.setattr(
        "src.backend.app.clients.ticketmaster_client.search_events",
        mock_search_events,
    )

    response = client_fixture.get("/api/v1/concerts?keyword=rock")
    assert response.status_code == 200
    assert response.json()["totalElements"] == 1
    assert response.json()["data"][0]["name"] == "Mock Concert"


def test_get_concert(monkeypatch, client_fixture):
    """Test /concerts/{event_id} endpoint with mock response"""

    async def mock_get_event(event_id: str):
        return mock_events["data"][0]

    monkeypatch.setattr(
        "src.backend.app.clients.ticketmaster_client.get_event",
        mock_get_event,
    )

    response = client_fixture.get("/api/v1/concerts/test123")
    assert response.status_code == 200
    assert response.json()["id"] == "test123"

# ---------------- Error Handling ----------------
def test_list_concerts_upstream_error(monkeypatch, client_fixture):
    """Test /concerts returns 502 when provider fails"""

    async def mock_search_events(params):
        raise Exception("Mock upstream failure")

    monkeypatch.setattr(
        "src.backend.app.clients.ticketmaster_client.search_events",
        mock_search_events,
    )

    response = client_fixture.get("/api/v1/concerts?keyword=fail")
    assert response.status_code == 502
    assert "Upstream error" in response.json()["detail"]


def test_get_concert_upstream_error(monkeypatch, client_fixture):
    """Test /concerts/{id} returns 502 when provider fails"""

    async def mock_get_event(event_id: str):
        raise Exception("Mock upstream failure")

    monkeypatch.setattr(
        "src.backend.app.clients.ticketmaster_client.get_event",
        mock_get_event,
    )

    response = client_fixture.get("/api/v1/concerts/fail123")
    assert response.status_code == 502
    assert "Upstream error" in response.json()["detail"]

# ---------------- Health & Root ----------------
def test_healthz(client_fixture):
    """Test /healthz endpoint"""
    response = client_fixture.get("/healthz")
    assert response.status_code == 200
    assert response.json()["ok"] is True


def test_root(client_fixture):
    """Test / root endpoint"""
    response = client_fixture.get("/")
    assert response.status_code == 200
    assert "Backend is running" in response.text
