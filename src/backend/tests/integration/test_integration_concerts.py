from unittest.mock import patch
from fastapi.testclient import TestClient
from app.main import app
import requests
import httpx

client = TestClient(app)

user_input = "Rock concerts in Boston next month"
mock_tokens = {
    "locations": ["Boston"],
    "start_date": "11-01-2025",
    "end_date": "11-30-2025",
    "artists": []
}
mock_preferences = {
    "genres": ["rock"],
    "artists": [""],
    "locations": ["Boston"]
}
mock_event_data = {
    "data": [
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

mock_recommendations = {
    "recommendations": [
        {"rank": 1, "event_id": "EVT123", "reason": "match"}
    ]
}


def test_search():
    with (
        patch("app.core.groq_client.GroqClient.extract_tokens", return_value=mock_tokens),
        patch("app.core.groq_client.GroqClient.get_user_preferences", return_value=mock_preferences),
        patch("app.api.concerts.ConcertsService.search", return_value=mock_event_data),
        patch("app.core.groq_client.GroqClient.create_recommendations", return_value=mock_recommendations),
    ):
        response = client.get("/concerts", params={"user_input": user_input})
        data = response.json()

    assert response.status_code == 200
    assert data["recommendations"][0]["event"]["id"] == mock_recommendations["recommendations"][0]["event_id"]
    assert data["recommendations"][0]["reason"] == mock_recommendations["recommendations"][0]["reason"]
    assert data["recommendations"][0]["rank"] == mock_recommendations["recommendations"][0]["rank"]


def test_groq_timeout(monkeypatch):
    def mock_timeout(*args, **kwargs):
        raise httpx.TimeoutException("Timeout exception")

    with (
        patch("app.core.groq_client.GroqClient.extract_tokens", return_value=mock_tokens),
        patch("app.core.groq_client.GroqClient.get_user_preferences", return_value=mock_preferences),
        patch("app.api.concerts.ConcertsService.search", return_value=mock_event_data),
    ):
        monkeypatch.setattr(httpx, "post", mock_timeout)
        response = client.get("/concerts", params={"user_input": user_input})
        assert response.status_code == 200
        data = response.json()
        assert data["recommendations"] == []
        assert data["summary"] == "AI service error. Showing fallback."


def test_vague_user_input():
    user_input_vague = "I don't like music."
    response = client.get("concerts", params={"user_input": user_input_vague})
    assert response.status_code == 200
    data = response.json()
    assert data["recommendations"] == []
    assert data["summary"] == "AI service error. Showing fallback."
