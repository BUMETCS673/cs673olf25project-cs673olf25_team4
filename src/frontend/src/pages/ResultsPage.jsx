import { useEffect, useState } from "react";
import { useLocation } from "react-router-dom";
import Banner from "../components/Banner";
import "../styles/globals.css";
import ResultCard from "../components/ResultCard"

function ResultsPage() {
  const [recommendations, setRecommendations] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const location = useLocation();
  const queryParams = new URLSearchParams(location.search);
  const userInput = queryParams.get("user_input");

  useEffect(() => {
    if (!userInput) {
      setError("No user input provided.");
      setLoading(false);
      return;
    }

    async function fetchRecommendations() {
      try {
        console.log("Fetching recommendations for:", userInput);
        const url = `/concerts?user_input=${encodeURIComponent(userInput)}`;
        const response = await fetch(url);
        const contentType = response.headers.get("content-type") || "";
        if (!response.ok) {
          const text = await response.text();
          console.error("Non-OK response", response.status, text);
          throw new Error(`HTTP error! Status: ${response.status}`);
        }
        if (!contentType.includes("application/json")) {
          const text = await response.text();
          console.error("Expected JSON but got:", contentType, text);
          throw new Error("Expected JSON response from /concerts/recommendations");
        }
        const data = await response.json();
        console.log("Recommendations received:", data);
        setRecommendations(data.recommendations || []);
      } catch (err) {
        console.error("Error fetching recommendations:", err);
        setError("Failed to fetch recommendations.");
      } finally {
        setLoading(false);
      }
    }

    fetchRecommendations();
  }, [userInput]);

  return (
    <div className="results-page">
      <Banner />

      <div className="results-content">
        {loading && (
          <p className="loading-animation">
            Loading recommendations...
          </p>
        )}

        {!loading && error && <p style={{ color: "red" }}>{error}</p>}

        {!loading && !error && !recommendations?.length && (
          <p>No recommendations found.</p>
        )}

        {!loading && !error && recommendations?.length > 0 && (
          <>
            <h2>Concert Recommendations</h2>

            <div className="cards">
              {recommendations.map((rec, idx) => (
                <ResultCard
                  key={idx}
                  title={rec.event?.name}
                  date={rec.event?.startDateTime}
                  venue={rec.event?.venue?.name}
                  city={rec.event?.venue?.city}
                  url={rec.event?.url}
                  reason={rec.reason}
                />
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

export default ResultsPage;
