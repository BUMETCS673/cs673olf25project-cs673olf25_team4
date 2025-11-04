"""Test configuration and fixtures."""

import sys
from pathlib import Path

# Add the backend directory to Python path
backend_dir = Path(__file__).parent
sys.path.insert(0, str(backend_dir))

# Add the src directory to Python path so 'interfaces' and 'providers' can be found
src_dir = backend_dir.parent
sys.path.insert(0, str(src_dir))
