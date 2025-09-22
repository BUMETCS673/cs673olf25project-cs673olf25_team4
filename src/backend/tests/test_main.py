# src/backend/tests/test_main.py

from unittest.mock import patch, AsyncMock, Mock

import pytest
from fastapi.testclient import TestClient

# import from src.backend.app
from src.backend.app.main import app
from src.backend.app.clients import jambase_client
from src.backend.app.api import concerts

client = TestClient(app)

# -------------------- Root & Health --------------------


def test_root_status_code():
    resp = client.get("/")
    assert resp.status_code == 200


def test_root_content():
    resp = client.get("/")
    assert "beatmap" in resp.text


def test_healthz():
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json()["ok"] is True


# -------------------- JamBase helpers --------------------


@pytest.mark.asyncio
async def test_get_city_id():
    """Mock httpx"""
    mock_response = Mock()
    mock_response.json.return_value = {
        "cities": [{"@type": "City", "identifier": "jambase:123", "name": "Boston"}]
    }
    mock_response.raise_for_status = lambda: None

    with patch(
        "src.backend.app.clients.jambase_client.httpx.AsyncClient.get",
        new=AsyncMock(return_value=mock_response),
    ) as mock_get:
        city_id = await jambase_client.get_city_id("Boston")
        assert city_id == "jambase:123"
        mock_get.assert_awaited_once()


def test_jambase_parse_performers():
    performers = [
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
    headliner, lineup = concerts.jambase_parse_performers(performers)
    assert headliner == "Turnstile"
    assert lineup == ["Turnstile", "Speed", "Jane Remover"]


# -------------------- Ticketmaster endpoints --------------------

MOCK_EVENTS = {
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


@pytest.fixture
def client_fixture():
    return TestClient(app)


def test_list_concerts(monkeypatch, client_fixture):
    async def mock_search_events(params):
        return MOCK_EVENTS

    monkeypatch.setattr(
        "src.backend.app.clients.ticketmaster_client.search_events",
        mock_search_events,
    )

    resp = client_fixture.get("/api/v1/concerts?keyword=rock")
    assert resp.status_code == 200
    body = resp.json()
    assert body["totalElements"] == 1
    assert body["data"][0]["name"] == "Mock Concert"


def test_get_concert(monkeypatch, client_fixture):
    async def mock_get_event(event_id: str):
        return MOCK_EVENTS["data"][0]

    monkeypatch.setattr(
        "src.backend.app.clients.ticketmaster_client.get_event",
        mock_get_event,
    )

    resp = client_fixture.get("/api/v1/concerts/test123")
    assert resp.status_code == 200
    assert resp.json()["id"] == "test123"


# -------------------- Error handling --------------------


def test_list_concerts_upstream_error(monkeypatch, client_fixture):
    async def mock_search_events(params):
        raise Exception("Mock upstream failure")

    monkeypatch.setattr(
        "src.backend.app.clients.ticketmaster_client.search_events",
        mock_search_events,
    )

    resp = client_fixture.get("/api/v1/concerts?keyword=fail")
    assert resp.status_code == 502
    assert "Upstream error" in resp.json()["detail"]


def test_get_concert_upstream_error(monkeypatch, client_fixture):
    async def mock_get_event(event_id: str):
        raise Exception("Mock upstream failure")

    monkeypatch.setattr(
        "src.backend.app.clients.ticketmaster_client.get_event",
        mock_get_event,
    )

    resp = client_fixture.get("/api/v1/concerts/fail123")
    assert resp.status_code == 502
    assert "Upstream error" in resp.json()["detail"]
