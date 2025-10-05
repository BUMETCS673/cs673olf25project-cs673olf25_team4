### Run a single test file
```bash
pytest src/backend/tests/test_api.py
```
### Running Tests with Docker Compose
You can run all backend tests inside a container using docker-compose:
```bash
docker compose up backend-test
```
This will build the backend-test service (using dockerfile.test) and execute all pytest cases automatically.
### What is Covered
1. Root endpoint (/)
2. Status code check
3. JSON response structure
4. Search endpoint (/search)
5. Success cases for both providers (mocked responses)
6. Invalid provider handling (returns 400)
7. Provider API failure (returns 502)
8. Provider API timeout (returns 502)