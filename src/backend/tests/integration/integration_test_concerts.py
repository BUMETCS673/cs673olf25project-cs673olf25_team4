def test_search():
    """
    Use the Ticketmaster provider, JamBase is expired.
    Mock external APIs, not flow of Beatmap API though
    Mock Groq?
    """
    user_input = "Rock concerts in Boston next month"
    mock_preferences = {
        "genres": ["rock"],
        "artists": [""],
        "locations": []
    }
    mock_event_data = {
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
    pass