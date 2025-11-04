import { useNavigate } from "react-router-dom";
import { useState } from "react";

function NLForm() {
  const navigate = useNavigate();
  const [query, setQuery] = useState("");

  const handleSubmit = (e) => {
    e.preventDefault();

    if (!query.trim()) {
      alert("Please enter something!");
      return;
    }

    // ✅ 跳转时将自然语言输入放入 URL 参数中
    navigate(`/results?user_input=${encodeURIComponent(query)}`);
  };

  return (
    <form onSubmit={handleSubmit}>
      <label htmlFor="nlq"></label>
      <textarea
        id="nlq"
        name="nlq"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="e.g. I want to see Taylor Swift in Boston next May"
        style={{ fontSize: "18px", fontFamily: "inherit" }}
      />
      <button className="btn" type="submit">Let's go!</button>
    </form>
  );
}

export default NLForm;
