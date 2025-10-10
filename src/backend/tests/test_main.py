"""Test suite for main application endpoints."""

import pytest
from fastapi.testclient import TestClient
from app.main import app
import httpx
from ...interfaces.concert_provider_interface import ConcertProviderInterface

import sys
import os
from pathlib import Path

# Add the project root (where "interfaces" lives) to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

# Add the backend directory to Python path
backend_dir = Path(__file__).parent
sys.path.insert(0, str(backend_dir))

# Add the src directory to Python path so 'interfaces' can be found
src_dir = backend_dir.parent
sys.path.insert(0, str(src_dir))


client = TestClient(app)

"""
BeatMap Project - Unit Tests for Backend API

This file contains unit tests for the BeatMap FastAPI backend.
The tests cover the following:

1. Root endpoint ("/")
   - Verifies status code and response content.

2. Search endpoint ("/search")
   - Success cases for both providers using mocked API responses.
   - Invalid provider handling (should return 400).
   - Provider API failure (simulated 500 response, should return 502).
   - Provider API timeout (simulated timeout, should return 502).

Notes:
- External API calls are mocked with `monkeypatch` to avoid real network requests.
"""


# --- Mock setup ---


class MockResponse:
    def __init__(self, json_data=None, status_code=200):
        self._json = json_data or {}
        self.status_code = status_code

    def json(self):
        return self._json

    def raise_for_status(self):
        if self.status_code >= 400:
            raise httpx.HTTPStatusError("error", request=None, response=None)


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


async def mock_get_success(self, url, params=None, **kwargs):
    return MockResponse(FULL_EVENT)


async def mock_get_fail(self, url, params=None, **kwargs):
    return MockResponse({"error": "fail"}, status_code=500)


async def mock_get_timeout(self, url, params=None, **kwargs):
    raise httpx.TimeoutException("Request timed out")


# --- Tests ---


def test_root_status_code():
    """Root endpoint should return 200"""
    resp = client.get("/")
    assert resp.status_code == 200


def test_root_content():
    """Root endpoint should contain status and message"""
    resp = client.get("/")
    data = resp.json()
    assert data["status"] == "ok"
    assert "beatmap" in data["message"].lower()


@pytest.mark.parametrize("provider", ["jambase", "ticketmaster"])
def test_search_success(monkeypatch, provider):
    """Search endpoint should return full event data"""
    monkeypatch.setattr("httpx.AsyncClient.get", mock_get_success)

    resp = client.get("/search", params={"city": "Boston", "provider": provider})
    assert resp.status_code == 200
    data = resp.json()
    assert "results" in data
    event = data["results"][0]

    # Validate key fields
    assert event["id"] == "EVT123"
    assert event["name"] == "Rock Fest"
    assert event["venue"]["city"] == "Boston"
    assert event["priceRanges"][0]["min"] == 50.0


def test_search_invalid_provider():
    """Search should fail with invalid provider"""
    resp = client.get("/search", params={"city": "Boston", "provider": "invalid"})
    assert resp.status_code == 400


def test_search_api_fail(monkeypatch):
    """Search should return 502 if provider API fails"""
    monkeypatch.setattr("httpx.AsyncClient.get", mock_get_fail)
    resp = client.get("/search", params={"city": "Boston", "provider": "ticketmaster"})
    assert resp.status_code == 502
    assert "Error fetching concert data" in resp.json()["detail"]


def test_search_api_timeout(monkeypatch):
    """Search should return 502 if provider API times out"""
    monkeypatch.setattr("httpx.AsyncClient.get", mock_get_timeout)
    resp = client.get("/search", params={"city": "Boston", "provider": "ticketmaster"})
    assert resp.status_code == 502
    assert "Error fetching concert data" in resp.json()["detail"]
