import { useSearchParams } from 'react-router-dom';
import Results from './Results';

// ResultsPanel: shows search context ("within X km of City on Date")
// Reads params from the URL and renders the Results component underneath
function ResultsPanel() {
    const [searchParams] = useSearchParams();

    const city = searchParams.get('city');
    const radius = searchParams.get('radius');
    const date = searchParams.get('date');

    // Format date as Month Day, Year
    let formattedDate = '';
  if (date) {
    const [year, month, day] = date.split('-');
    const parsed = new Date(year, month - 1, day); // Month is 0-based
    formattedDate = parsed.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  }

    return (
        <section className="results">
            <strong style={{fontSize: 25, paddingTop: 5}}>Results</strong>

            {/* Context line */}
            <div className="status" id="results-status" style={{fontSize: 14}}>
                {city || radius || date ? (
                    <>
                        Showing events
                        {radius ? ` within ${radius} km` : ''}
                        {city ? ` of ${city}` : ''}
                        {formattedDate ? ` on ${formattedDate}` : ''}
                    </>
                ) : (
                    'No search yet'
                )}
            </div>
            <Results items={[]} />
        </section>
    );
}

export default ResultsPanel;
