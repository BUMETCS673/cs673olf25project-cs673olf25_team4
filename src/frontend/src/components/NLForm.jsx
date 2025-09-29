import { useNavigate } from "react-router-dom";
import { useState } from "react";

function NLForm() {
  const navigate = useNavigate();
  const [query, setQuery] = useState("");

  const handleSubmit = (e) => {
    e.preventDefault();

    const mock = {
      results: [
        { artist: "Taylor Swift", date: "2025-10-05", venue: "TD Garden", city: "Boston" },
        { artist: "Coldplay", date: "2025-10-06", venue: "Fenway Park", city: "Boston" }
      ],
      summary: "Top pick: Taylor Swift at TD Garden on Oct 5."
    };

    navigate('/results', { state: { query, results: mock.results, summary: mock.summary } });
  };

  return (
    <form onSubmit={handleSubmit}>
      <label htmlFor="nlq">Natural language query</label>
      <textarea
        id="nlq"
        name="nlq"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="e.g. Show me jazz concerts in NYC this weekend"
      />
      <button className="btn" type="submit">Ask AI Agent</button>
    </form>
  );
}

export default NLForm;
