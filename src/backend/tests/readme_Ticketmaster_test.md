# Unit Tests for Backend (Concerts API)

This project includes unit tests for the backend service, specifically focusing on the **Concerts API** and general system health.  

## 🔍 What the Tests Cover

1. **Happy Path (Mocked Success Cases)**
   - `test_list_concerts`: Ensures `/api/v1/concerts` returns a valid mocked list of concerts.
   - `test_get_concert`: Ensures `/api/v1/concerts/{event_id}` returns the correct mocked event details.

2. **Error Handling**
   - `test_list_concerts_upstream_error`: Verifies `/api/v1/concerts` returns `502` when the upstream Ticketmaster provider fails.
   - `test_get_concert_upstream_error`: Verifies `/api/v1/concerts/{event_id}` returns `502` when the upstream provider fails.

3. **Health Check & Meta Endpoints**
   - `test_healthz`: Confirms `/healthz` returns `{"ok": true}` and status `200`.
   - `test_root`: Confirms `/` returns a success message indicating the backend is running.

## 🛠️ Approach

- External API calls are mocked using `monkeypatch`.  
- Tests do **not** rely on real Ticketmaster API requests.  
- Focus is on backend routing, request handling, error propagation, and health endpoints.  

---

## ✅ Summary (Simple)

The unit tests check:  
- Concert search and event details return correct results (mocked).  
- Errors are handled properly and return `502`.  
- Health and root endpoints respond correctly.  
