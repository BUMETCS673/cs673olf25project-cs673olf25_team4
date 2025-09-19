// ResultCard: displays a single concert result (title, date, venue, city)
// Used inside Results to format each item in the list
function ResultCard({ title, date, venue, city }) {
  return (
    <div className="card">
      <h3>{title || 'Untitled'}</h3>
      <p>
        {date || ''} {venue ? `• ${venue}` : ''} {city ? `— ${city}` : ''}
      </p>
    </div>
  );
}

export default ResultCard;
