import { useEffect, useState } from "react";
import { useLocation } from "react-router-dom";

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
        console.log("origin:", window.location.origin);
        const url = `/concerts/recommendations?user_input=${encodeURIComponent(
          userInput
        )}`;
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

  if (loading) return <p>Loading recommendations...</p>;
  if (error) return <p style={{ color: "red" }}>{error}</p>;
  if (!recommendations?.length) return <p>No recommendations found.</p>;

  return (
    <div style={{ padding: "20px" }}>
      <h2>Concert Recommendations</h2>
      <ul>
        {recommendations.map((rec, idx) => (
          <li key={idx} style={{ marginBottom: "20px" }}>
            <strong>{rec.event?.name || "Unknown Event"}</strong>
            <br />
            <em>{rec.event?.venue?.name}</em> — {rec.event?.venue?.city}
            <br />
            <a href={rec.event?.url} target="_blank" rel="noopener noreferrer">
              View Details
            </a>
            <p style={{ fontStyle: "italic" }}>{rec.reason}</p>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default ResultsPage;
