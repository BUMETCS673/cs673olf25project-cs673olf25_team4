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
        <p className="subtitle">What concerts are you looking for?</p>

      <form onSubmit={handleSubmit} className="search-form">
        <div className="search-wrapper">
          <input
            className="search-input"
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="e.g. Jazz concerts in Boston next month"
          />
          <button className="search-button" type="submit">
            Let’s go!
          </button>
        </div>
      </form>

      </div>
    </div>
  );
}
