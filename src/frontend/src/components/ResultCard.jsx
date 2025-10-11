// ResultCard: displays a single concert result (title, date, venue, city, url, reason)

function ResultCard({ title, date, venue, city, url, reason }) {
  // Format ISO date string into readable text
  const formattedDate = date
    ? new Date(date).toLocaleDateString("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit",
    })
    : "Date not available";
  return (
    <div className="card">
      <h3 className="card-title">
        <span>{title || "Untitled Event"}</span>
      </h3>
      <p className="card-details">
        {[formattedDate, venue, city].filter(Boolean).join(" | ")}
      </p>

      {reason && <p className="card-reason">{reason}</p>}

      {url && (
        <a
          href={url}
          target="_blank"
          rel="noopener noreferrer"
          className="card-link"
        >
          View Details
        </a>
      )}
    </div>
  );
}

export default ResultCard;

