import ResultCard from './ResultCard';

// Results: maps an array of event items into ResultCard components
// If no items exist, shows a "No results." placeholder
function Results({ items = [] }) {
  if (!items.length) {
    return <div className="empty">No results.</div>;
  }


  return (
    <div className="cards">
      {items.map((it, i) => (
        <ResultCard
          key={i}
          title={it.title}
          date={it.date}
          venue={it.venue}
          city={it.city}
        />
      ))}
    </div>
  );
}

export default Results;
