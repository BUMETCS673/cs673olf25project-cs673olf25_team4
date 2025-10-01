import pytest
import httpx
from app.core.groq_client import GroqClient


class FakeAsyncClient(httpx.AsyncClient):
    def __init__(self, response_json):
        self._response_json = response_json

    async def request(self, method: str, url: str, **kwargs):
        class FakeResponse:
            def __init__(self, data):
                self._data = data

            def raise_for_status(self):
                pass

            def json(self):
                return self._data

        return FakeResponse(self._response_json)


@pytest.mark.asyncio
async def test_extract_tokens_with_test_client():
    test_response = {
        "location": "Tampa",
        "start_date": "01012026",
        "end_date": "31122026",
        "artist": "Metallica",
    }
    groq = GroqClient(client=FakeAsyncClient(test_response))
    tokens = await groq.extract_tokens("Metallica in Tampa 2026")
    assert tokens == test_response


@pytest.mark.asyncio
async def test_get_user_preferences_with_test_client():
    test_response = {
        "genres": ["rap, rock"],
        "artists": ["Clipse, Radiohead"],
        "locations": ["Detroit"],
    }
    groq = GroqClient(client=FakeAsyncClient(test_response))
    user_preferences = await groq.get_user_preferences(
        "I listen to rap and rock. My favorite artists are Clipse and "
        "Radiohead. I am interested in shows in the Detroit area."
    )
    assert user_preferences == test_response


@pytest.mark.asyncio
async def test_create_recommendations_with_test_client():
    test_response = [
        {"rank": 1, "event_id": "123", "reason": "match"},
        {"rank": 2, "event_id": "456", "reason": "close"},
        {"rank": 3, "event_id": "789", "reason": "similar"},
    ]

    groq = GroqClient(client=FakeAsyncClient(test_response))
    recs = await groq.create_recommendations(
        {"genres": ["rap"], "artists": ["Clipse"], "locations": ["Detroit"]},
        [{"id": "123"}, {"id": "456"}, {"id": "789"}],
    )

    assert recs == test_response
