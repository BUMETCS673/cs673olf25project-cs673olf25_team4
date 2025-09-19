import { useNavigate } from "react-router-dom";

// NLForm: collects a natural language query and navigates to /results
// Later, this will include the query in the URL for backend processing
function NLForm() {
  const navigate = useNavigate();

  const handleSubmit = (e) => {
    e.preventDefault();
    // Pass search params here
    navigate('/results');
  };

  return (
    <form onSubmit={handleSubmit}>
      <label htmlFor="nlq">Natural language query</label>
      <textarea
        id="nlq"
        name="nlq"
        placeholder="e.g. Show me jazz concerts in NYC this weekend"
      />
      <button className="btn" type="submit">Ask AI Agent</button>
    </form>
  );
}

export default NLForm;
