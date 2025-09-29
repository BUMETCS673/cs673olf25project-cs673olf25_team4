// ResultsPage.jsx
import { useLocation } from "react-router-dom";
import Banner from "../components/Banner";
import ResultsPanel from "../components/ResultsPanel"; 

export default function ResultsPage() {
  const { state } = useLocation();
  const results = state?.results || [];
  const summary = state?.summary || "";

  return (
    <>
      <Banner />

      {summary && (
        <section className="ai-summary">
          <h3>AI Summary</h3>
          <p>{summary}</p>
        </section>
      )}

      {results.length > 0 ? (
        <section className="ai-results">
          <h3>Results</h3>
          <ul>
            {results.map((r, i) => (
              <li key={i}>
                <strong>{r.artist || r.name}</strong> — {r.date} @ {r.venue}
                {r.city ? ` (${r.city})` : ""}
              </li>
            ))}
          </ul>
        </section>
      ) : (
        <ResultsPanel />
      )}
    </>
  );
}
