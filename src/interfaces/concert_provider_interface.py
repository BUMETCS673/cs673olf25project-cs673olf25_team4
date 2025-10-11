from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional


class ConcertProviderInterface(ABC):
    """Minimal interface that all concert providers must implement."""

    @abstractmethod
    def search(
        self,
        keyword: Optional[str] = None,
        city: Optional[str] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        page: int = 0,
        size: int = 20,
    ) -> List[Dict[str, Any]]:
        """
        Perform a concert search and return normalized results
        (list of dicts following BeatMap’s internal concert schema).
        """
        pass

    @abstractmethod
    def get_source_name(self) -> str:
        """Return a short name identifying this provider."""
        pass
