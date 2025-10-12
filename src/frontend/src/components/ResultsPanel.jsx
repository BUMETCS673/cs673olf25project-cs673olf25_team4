import Results from "./Results";
import "../styles/globals.css"; // optional, if not already global

function ResultsPanel({ recommendations, userInput }) {
    return (
        <div className="results-panel">
            <h2>Concert Recommendations {userInput && (
                <span className="results-query">
                    {" "}
                    for “{userInput}”
                </span>
            )}</h2>

            <Results recommendations={recommendations} />

            <div className="results-actions">
                <button
                    className="new-search-button"
                    onClick={() => (window.location.href = "https://beatmap.live")}
                >
                    New Search
                </button>
            </div>
        </div>
    );
}

export default ResultsPanel;
