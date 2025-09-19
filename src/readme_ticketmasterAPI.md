## Ticketmaster Provider API

The **ticketmaster-provider** service is a lightweight wrapper around the official Ticketmaster Discovery API.  
It exposes a simplified and consistent interface for the backend to consume, instead of calling Ticketmaster directly.

---

### Base URL

- **Local Development**
http://localhost:8001
- **EC2 Deployment (example)**
http://3.144.211.10:8001

---

### Endpoints

#### `GET /`

**Description:** Basic status check.  

**Response**
```json
{
"status": "ok",
"message": "Ticketmaster service is running."
}
GET /healthz
Description: Health check endpoint for container orchestration.
Response

{
  "ok": true
}
GET /events
Description: Search events with filters.
Query Parameters (optional)

keyword — search term
city — filter by city
countryCode — ISO country code (e.g., US)
startDateTime — filter start date (ISO 8601)
endDateTime — filter end date (ISO 8601)
latlong — e.g. "40.726,-74.002"
radius — radius around latlong
unit — units for radius (miles or km)
page — page number (default 0)
size — number of results per page (default 20)
sort — sorting criteria
Response Example
{
  "totalElements": 120,
  "page": 0,
  "size": 2,
  "data": [
    {
      "id": "G5vYZp1QZeN8p",
      "name": "Taylor Swift | The Eras Tour",
      "url": "https://www.ticketmaster.com/event/...",
      "startDateTime": "2025-09-20T19:00:00Z",
      "segment": "Music",
      "genre": "Pop",
      "venue": {
        "id": "123",
        "name": "Madison Square Garden",
        "city": "New York",
        "country": "US",
        "lat": 40.7505,
        "lon": -73.9934
      },
      "priceRanges": [
        { "currency": "USD", "min": 150.0, "max": 800.0 }
      ]
    }
  ],
  "next": "/events.json?page=1&size=2"
}
GET /events/{event_id}
Description: Get details for a single event.
Path Parameters

event_id — Ticketmaster event ID
Response Example
{
  "id": "G5vYZp1QZeN8p",
  "name": "Taylor Swift | The Eras Tour",
  "url": "https://www.ticketmaster.com/event/...",
  "startDateTime": "2025-09-20T19:00:00Z",
  "segment": "Music",
  "genre": "Pop",
  "venue": {
    "id": "123",
    "name": "Madison Square Garden",
    "city": "New York",
    "country": "US",
    "lat": 40.7505,
    "lon": -73.9934
  },
  "priceRanges": [
    { "currency": "USD", "min": 150.0, "max": 800.0 }
  ]
}
Environment Variables
The provider requires the following environment variables:
TM_API_KEY=<your-ticketmaster-key>
TM_BASE_URL=https://app.ticketmaster.com/discovery/v2
⚠️ The TM_API_KEY must be set before starting the container.
Integration Flow
The intended flow is:
Frontend (port 3000) → Backend (port 8000) → Provider (port 8001) → Ticketmaster API
Frontend should only call the backend (http://<server-ip>:8000).
Backend uses TM_PROVIDER_URL to call the provider.
Provider proxies requests to Ticketmaster using the API key.
Ticketmaster API responds with official event data.
```

## Quick Verification
Backend routes up
Open Swagger: http://3.144.211.10:8000/docs
Expect to see /api/v1/concerts and /api/v1/concerts/{event_id}
End-to-end
curl "http://3.144.211.10:8000/api/v1/concerts?keyword=taylor&countryCode=US&size=2"
If it returns data → plumbing OK.