import Banner from '../components/Banner';
import SearchForm from '../components/SearchForm';
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

      {/* Forms stacked vertically */}
      <section className="form-section">
        <h2>Search by Details</h2>
        <SearchForm />
      </section>

      <section className="form-section">
        <h2>Ask AI</h2>
        <NLForm />
      </section>
    </div>
  );
}

export default SearchPage;



