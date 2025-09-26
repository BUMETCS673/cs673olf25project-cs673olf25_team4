import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_root_status_code():
    resp = client.get("/")
    assert resp.status_code == 200


def test_root_content():
    resp = client.get("/")
    data = resp.json()
    assert data["status"] == "ok"
    assert "beatmap" in data["message"].lower()


# --- Mocking setup ---


class MockResponse:
    def __init__(self, json_data, status_code=200):
        self._json = json_data
        self.status_code = status_code

    def json(self):
        return self._json

    def raise_for_status(self):
        if self.status_code >= 400:
            raise Exception("HTTP error")


# Full fake event
FULL_EVENT = {
    "results": [
        {
            "id": "EVT123",
            "name": "Rock Fest",
            "url": "http://example.com/rockfest",
            "startDateTime": "2025-09-22T20:00:00Z",
            "segment": "Music",
            "genre": "Rock",
            "venue": {
                "id": "VEN1",
                "name": "Big Stadium",
                "city": "Boston",
                "country": "US",
            },
            "priceRanges": [{"currency": "USD", "min": 50.0, "max": 150.0}],
        }
    ]
}


async def mock_get(self, url, params=None, **kwargs):
    return MockResponse(FULL_EVENT)


# --- Tests ---


@pytest.mark.parametrize("provider", ["jambase", "ticketmaster"])
def test_search_endpoint_success(monkeypatch, provider):
    monkeypatch.setattr("httpx.AsyncClient.get", mock_get)

    resp = client.get(
        "/search",
        params={
            "city": "Boston",
            "start_date": "2025-09-22",
            "end_date": "2025-09-23",
            "provider": provider,
        },
    )

    assert resp.status_code == 200
    data = resp.json()
    assert "results" in data
    event = data["results"][0]

    # Validate all fields
    assert event["id"] == "EVT123"
    assert event["name"] == "Rock Fest"
    assert event["url"] == "http://example.com/rockfest"
    assert event["startDateTime"].startswith("2025-09-22")
    assert event["segment"] == "Music"
    assert event["genre"] == "Rock"

    assert "venue" in event
    assert event["venue"]["city"] == "Boston"
    assert event["venue"]["country"] == "US"

    assert "priceRanges" in event
    assert event["priceRanges"][0]["min"] == 50.0
    assert event["priceRanges"][0]["max"] == 150.0


def test_search_endpoint_failure(monkeypatch):
    async def mock_get_fail(self, url, params=None, **kwargs):
        return MockResponse({"error": "fail"}, status_code=500)

    monkeypatch.setattr("httpx.AsyncClient.get", mock_get_fail)

    resp = client.get(
        "/search",
        params={"city": "Boston", "provider": "jambase"},
    )

    assert resp.status_code == 502
    assert "Error fetching concert data" in resp.json()["detail"]
