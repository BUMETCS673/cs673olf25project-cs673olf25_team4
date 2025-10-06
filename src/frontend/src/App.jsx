{/*/ This file was generated with the help of AI. 90% of the code was written by AI, 
while the remaining 10% was added/modified by humans. */}

import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import SearchPage from './pages/SearchPage';
import ResultsPage from './pages/ResultsPage';

function App() {
  return (
    <Router>
      <Routes>
        {/* Default route → redirect to /search */}
        <Route path="/" element={<Navigate to="/search" />} />

        {/* Main pages */}
        <Route path="/search" element={<SearchPage />} />
        <Route path="/results" element={<ResultsPage />} />
      </Routes>
    </Router>
  );
}

export default App;
