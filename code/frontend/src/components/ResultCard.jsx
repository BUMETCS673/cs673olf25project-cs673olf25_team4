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
