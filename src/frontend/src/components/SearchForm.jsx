import { useNavigate } from 'react-router-dom';

// SearchForm: collects user input (keyword, city, date, radius, vendor)
// On submit, it builds a query string and navigates to /results
// These params are later read in ResultsPanel to filter concerts
function SearchForm() {
  const navigate = useNavigate();

const handleSubmit = (e) => {
  e.preventDefault();

  const formData = new FormData(e.target);
  const params = new URLSearchParams(formData);


  navigate(`/results?${params.toString()}`);
};

  return (
    <form onSubmit={handleSubmit}>
      <div className="form-row" style={{ flexDirection: 'column' }}>
        <label htmlFor="q">Keyword (artist, venue — optional)</label>
        <input id="q" name="q" type="text" placeholder="e.g. Radiohead" />
      </div>

      <div className="form-row">
        <div style={{ flex: 1 }}>
          <label htmlFor="city">City</label>
          <input id="city" name="city" type="text" placeholder="Boston" />
        </div>
        <div style={{ width: '140px' }}>
          <label htmlFor="date">Date</label>
          <input id="date" name="date" type="date" />
        </div>
      </div>

      <div className="form-row">
        <div style={{ flex: 1 }}>
          <label htmlFor="radius">Radius (km)</label>
          <select id="radius" name="radius" defaultValue="50">
            <option value="10">10 km</option>
            <option value="25">25 km</option>
            <option value="50">50 km</option>
            <option value="100">100 km</option>
          </select>
        </div>
        <div style={{ width: '140px' }}>
          <label htmlFor="vendor">Vendor</label>
          <select id="vendor" name="vendor" defaultValue="auto">
            <option value="auto">Auto</option>
            <option value="ticketmaster">Ticketmaster</option>
            <option value="pollstar">Pollstar</option>
          </select>
        </div>
      </div>

      <button className="btn" type="submit">Search concerts</button>
    </form>
  );
}

export default SearchForm;

