import bannerImg from '../assets/beatmap-banner.png';

function Banner() {
  return (
    <header className="banner">
      <a href="https://beatmap.live">
        <img src={bannerImg} alt="Beatmap banner" className="banner-img" />
      </a>
    </header>
  );
}

export default Banner;

