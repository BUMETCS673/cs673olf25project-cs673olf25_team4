import ResultCard from './ResultCard';

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
