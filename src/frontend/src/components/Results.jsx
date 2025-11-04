import ResultCard from "./ResultCard";

function Results({ recommendations = [] }) {
  console.log("[Results] received:", recommendations);

  return (
    <div className="cards">
      {recommendations.map((rec, idx) => (
        <ResultCard
          key={idx}
          title={rec.event?.name}
          date={rec.event?.startDateTime}
          venue={rec.event?.venue?.name}
          city={rec.event?.venue?.city}
          url={rec.event?.url}
          reason={rec.reason}
        />
      ))}
    </div>
  );
}

export default Results;


