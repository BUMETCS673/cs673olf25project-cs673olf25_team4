function NLForm() {
  return (
    <form id="nl-form">
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
