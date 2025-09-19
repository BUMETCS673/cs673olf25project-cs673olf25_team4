# TODO: not really sure if this import is correct, I don't think it's finding "clients"
from clients.jambase_client import get_events as jambase_get_events
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
            "id" : self.id,
            "name" : self.name,
            "venue" : self.venue,
            "date" : self.date,
            "artist" : self.artist,
            "lineup" : self.lineup
        }

def get_concert_objs(city, start_date, end_date):
    event_data = jambase_get_events(city, start_date, end_date)
    concerts = []

    for event in event_data.get("events"):
        performer_result = jambase_parse_performers(event.get("performer"))
        concerts.append(Concert(event.get("identifier"), event.get("name"), event.get("location").get("name"), event.get("startDate"), performer_result[0], performer_result[1]))

    return concerts

def jambase_parse_performers(performer_list):
    artist = ""
    lineup = []
    for performer in performer_list:
        # if that performer is headlining, then this is the main artist for that event
        if performer.get("x-isHeadliner"):
            artist = performer.get("name")
        lineup.append(performer.get("name"))
    
    return [artist, lineup]