import Banner from '../components/Banner';
import SearchForm from '../components/SearchForm.jsx';
import NLForm from '../components/NLForm';

// SearchPage: main landing page
// Renders banner, tagline, and both search forms (structured + natural language)
function SearchPage() {
  return (
    <div className="page">
      {/* Banner at top */}
      <Banner />

      {/* Tagline under banner */}
      <p className="tagline">
        Find concerts with structured search or ask our AI agent
      </p>
      
      <section className="form-section">
        <h2>Ask AI</h2>
        <NLForm />
      </section>
    </div>
  );
}

export default SearchPage;



