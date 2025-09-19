# code/backend/tests/test_main.py
from fastapi.testclient import TestClient
from backend.app.main import app 

client = TestClient(app)


def test_root_status_code():
    """Test that the root endpoint returns 200 OK"""
    response = client.get("/")
    assert response.status_code == 200


def test_root_content():
    """Test that the root endpoint contains the correct text"""
    response = client.get("/")
    assert "beatmap" in response.text
