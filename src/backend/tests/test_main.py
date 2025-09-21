import sys
from pathlib import Path
import pytest
from unittest.mock import patch, AsyncMock, Mock
from fastapi.testclient import TestClient
from src.backend.app.main import app

# Add the backend directory to the Python path
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))

from app.main import app  # noqa
from app.clients import jambase_client  # noqa
from app.api import concerts  # noqa

client = TestClient(app)


def test_root_status_code():
    """Test that the root endpoint returns 200 OK"""
    response = client.get("/")
    assert response.status_code == 200


def test_root_content():
    """Test that the root endpoint contains the correct text"""
    response = client.get("/")
    assert "beatmap" in response.text


@pytest.mark.asyncio
async def test_get_city_id():
    """Test with mock data to avoid calling the real API, that we get
    a result back from get_city_id and we awaited the response."""
    mock_response = Mock()
    mock_response.json.return_value = {
        "cities": [
            {
                "@type": "City",
                "identifier": "jambase:123",
                "name": "Boston",
            }
        ]
    }
    mock_response.raise_for_status = lambda: None

    with patch(
        "app.clients.jambase_client.httpx.AsyncClient.get",
        new=AsyncMock(return_value=mock_response),
    ) as mock_get:
        city_id = await jambase_client.get_city_id("Boston")
        assert city_id == "jambase:123"
        mock_get.assert_awaited_once()


def test_jambase_parse_performers():
    """Test that parse_performers returns the correct headlining artist
    and the list of artists that are performing at the event"""
    test_performer_list = [
        {
            "@type": "MusicGroup",
            "name": "Turnstile",
            "identifier": "jambase:52143",
            "x-isHeadliner": True,
        },
        {
            "@type": "MusicGroup",
            "name": "Speed",
            "identifier": "jambase:6380443",
            "x-isHeadliner": False,
        },
        {
            "@type": "MusicGroup",
            "name": "Jane Remover",
            "identifier": "jambase:9087125",
            "x-isHeadliner": False,
        },
    ]
    result = concerts.jambase_parse_performers(test_performer_list)
    assert result[0] == "Turnstile"
    assert result[1] == ["Turnstile", "Speed", "Jane Remover"]

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
