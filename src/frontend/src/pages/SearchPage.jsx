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
      </p>

      <section className="form-section">
        <h2>What concerts are you looking for?</h2>
        <NLForm />
      </section>
    </div>
  );
}

export default SearchPage;



