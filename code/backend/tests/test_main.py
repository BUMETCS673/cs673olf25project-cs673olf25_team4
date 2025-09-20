from fastapi.testclient import TestClient
from ..app.main import app
from ..app.clients import jambase_client

from unittest.mock import patch, AsyncMock, Mock
import pytest

from ..app.api import concerts

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
    mock_response = Mock()
    mock_response.json.return_value =  {
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
        "backend.app.clients.jambase_client.httpx.AsyncClient.get",
        new=AsyncMock(return_value=mock_response)
    ) as mock_get:
        city_id = await jambase_client.get_city_id("Boston")
        assert city_id == "jambase:123"
        mock_get.assert_awaited_once()

def test_jambase_parse_performers():
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
                }
            ]
    result = concerts.jambase_parse_performers(test_performer_list)
    assert result[0] == "Turnstile"
    assert result[1] == ["Turnstile", "Speed", "Jane Remover"]


    
