import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [message, setMessage] = useState('');
  const [name, setName] = useState('');
  const [greeting, setGreeting] = useState('');
  const [loading, setLoading] = useState(false);

  // Fetch hello message on component mount
  useEffect(() => {
    fetchHelloMessage();
  }, []);

  const fetchHelloMessage = async () => {
    try {
      const response = await axios.get('http://localhost:8000/api/hello');
      setMessage(response.data.message);
    } catch (error) {
      console.error('Error fetching message:', error);
      setMessage('Error connecting to backend');
    }
  };

  const handleGreeting = async (e) => {
    e.preventDefault();
    if (!name.trim()) return;
    
    setLoading(true);
    try {
      const response = await axios.post('http://localhost:8000/api/greet', {
        name: name.trim()
      });
      setGreeting(response.data.message);
    } catch (error) {
      console.error('Error sending greeting:', error);
      setGreeting('Error sending greeting');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>🚀 Full-Stack Hello World</h1>
        <p className="subtitle">React + FastAPI + Docker</p>
        
        <div className="message-box">
          <h2>Backend Message:</h2>
          <p className="backend-message">{message}</p>
        </div>

        <div className="greeting-section">
          <h2>Personal Greeting</h2>
          <form onSubmit={handleGreeting} className="greeting-form">
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Enter your name"
              className="name-input"
            />
            <button type="submit" disabled={loading} className="submit-btn">
              {loading ? 'Sending...' : 'Get Greeting'}
            </button>
          </form>
          {greeting && (
            <div className="greeting-result">
              <p>{greeting}</p>
            </div>
          )}
        </div>

        <div className="info-section">
          <h3>Tech Stack</h3>
          <ul className="tech-list">
            <li>Frontend: React 18</li>
            <li>Backend: FastAPI</li>
            <li>Containerization: Docker</li>
            <li>HTTP Client: Axios</li>
          </ul>
        </div>
      </header>
    </div>
  );
}

export default App;