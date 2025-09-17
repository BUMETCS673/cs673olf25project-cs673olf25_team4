import SearchForm from '../components/Searchform';
import NLForm from '../components/NLForm';
import Results from '../components/Results';

function SearchPage() {
  return (
    <main className="container">
      {/* Left: search */}
      <section className="panel">
        <div className="brand">
          <div className="logo">BM</div>
          <div>
            <h1>beatmap</h1>
            <p className="lead">
              Find concerts with structured search or natural language.
            </p>
          </div>
        </div>

        <SearchForm />
        <hr
          style={{
            margin: '20px 0',
            border: 0,
            borderTop: '1px solid rgba(255,255,255,0.06)',
          }}
        />
        <NLForm />
      </section>

      {/* Right: results */}
      <section className="results">
        <strong>Results</strong>
        <div className="status" id="results-status">No search yet</div>
        <Results items={[]} />
      </section>
    </main>
  );
}

export default SearchPage;

