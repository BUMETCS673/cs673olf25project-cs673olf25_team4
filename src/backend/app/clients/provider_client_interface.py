from abc import ABC, abstractmethod
from typing import Dict


class ProviderClientInterface(ABC):
    @abstractmethod
    async def search_events(self, params: Dict) -> Dict:
        """
        Searches for events given a dictionary of parameters.
        :param params: Query parameters as dictionary.
        :return: A dictionary with the search results.
        """
        pass

    @abstractmethod
    async def get_event(self, event_id: str) -> Dict:
        """
        Gets event details for a given event id.
        :param event_id: The event identifier.
        :return: A dictionary with event details.
        """
        pass
