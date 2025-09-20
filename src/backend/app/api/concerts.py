"""
concerts.py

This file defines a common Concert object. It queries concert data from
JamBase and turns the data into a list of Concert objects so we have a
standardized way of working with the data.
"""

from ..clients.jambase_client import get_events as jambase_get_events


class Concert:
    def __init__(self, id, name, venue, date, artist, lineup):
        self.id = id
        self.name = name
        self.venue = venue
        self.date = date
        self.artist = artist
        self.lineup = lineup

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "venue": self.venue,
            "date": self.date,
            "artist": self.artist,
            "lineup": self.lineup,
        }


async def get_concert_objs_from_jambase(city, start_date, end_date):
    """
     Gets the data from JamBase for events in a city in a date range.

     Args:
         city(str): The city to get the event data for.
         start_date(str): A date in YYYY-MM-DD format to start the date
         range from.
         end_date(str): A date in YYYY-MM-DD format to end the date range to.

    Returns:
        concerts: A list of Concert objects.
    """
    event_data = await jambase_get_events(city, start_date, end_date)
    concerts = []

    for event in event_data.get("events"):
        performer_result = jambase_parse_performers(event.get("performer"))
        concerts.append(
            Concert(
                event.get("identifier"),
                event.get("name"),
                event.get("location").get("name"),
                event.get("startDate"),
                performer_result[0],
                performer_result[1],
            )
        )

    return concerts


def jambase_parse_performers(performer_list):
    """
    Gets the headlining artists and list of artists performing at an event
    from a list of performers provided from JamBase.

    Args:
        performer_list: A list of dictionaries containing the performer info
        for an event passed from JamBase.

    Returns:
        A list of 2 objects, a string containing the headlining artist
        and a list of artists that are performing at the event
    """
    artist = ""
    lineup = []
    for performer in performer_list:
        # if that performer is headlining, then this is the main artist
        # for that event
        if performer.get("x-isHeadliner"):
            artist = performer.get("name")
        lineup.append(performer.get("name"))

    return [artist, lineup]
