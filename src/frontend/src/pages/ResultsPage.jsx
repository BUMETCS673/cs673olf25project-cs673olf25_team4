import Banner from '../components/Banner';
import ResultsPanel from '../components/ResultsPanel';
import { useSearchParams } from 'react-router-dom';

// ResultsPage: displays the banner and results panel
// This page shows the user's search results after submitting a form
function ResultsPage() {
  return (
    <main className="page">
      <Banner />
      <ResultsPanel />
    </main>
  );
}

export default ResultsPage;
