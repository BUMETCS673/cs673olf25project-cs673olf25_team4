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
