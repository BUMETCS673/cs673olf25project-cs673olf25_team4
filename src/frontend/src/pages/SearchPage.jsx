{/*/ This file was generated with the help of AI. 80% of the code was written by AI, 
while the remaining 20% was added/modified by humans. */}

import { useState } from "react";
import { useNavigate } from "react-router-dom";
import Banner from "../components/Banner"; 
import "../styles/globals.css"; 

export default function SearchPage() {
  const [input, setInput] = useState("");
  const navigate = useNavigate();

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!input.trim()) return;
    navigate(`/results?user_input=${encodeURIComponent(input)}`);
  };

  return (
    <div className="search-page">
      <Banner />

      <div className="search-content">
        <h1 className="title">BeatMap</h1>
        <p className="subtitle">Discover live music that matches your vibe.</p>

        <form onSubmit={handleSubmit} className="search-form">
          <input
            className="search-input"
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="e.g. Jazz concerts in Boston next month"
          />
          <button className="search-btn" type="submit">
            Let's go!
          </button>
        </form>
      </div>
    </div>
  );
}
